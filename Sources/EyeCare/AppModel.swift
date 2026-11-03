import AppKit
import Combine
import EyeCareCore
import ServiceManagement
import UserNotifications

enum AppPage { case today, history, settings }

@MainActor
final class AppModel: ObservableObject {
    @Published var page: AppPage = .today
    @Published private(set) var data = CareData()
    @Published private(set) var clock = BreakClock(now: Date())
    @Published private(set) var now = Date()
    @Published var errorMessage: String?
    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var loginEnabled = false
    @Published private(set) var loginNeedsApproval = false
    @Published private(set) var undoEventID: UUID?
    var onShow: (() -> Void)?
    var onStatusChange: (() -> Void)?

    private let store: DataStore
    private lazy var notifications = Notifications()
    private let restCompletionSound = NSSound(named: NSSound.Name("Glass"))
    private var timer: Timer?
    private var suspensions: Set<String> = []
    private var autoResume = false
    private var lastDay = Calendar.current.startOfDay(for: Date())
    private var canSave = true

    // Offscreen documentation renders use sample data without loading personal history,
    // starting timers, or scheduling system notifications.
    init(previewData: CareData? = nil, previewDate: Date = Date(), previewClock: BreakClock? = nil) {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        store = DataStore(url: support.appendingPathComponent("EyeCare/data.json"))
        if let previewData {
            data = previewData
            now = previewDate
            clock = previewClock ?? BreakClock(now: previewDate)
            notificationStatus = .authorized
            canSave = false
            return
        }
        do { data = try store.load() } catch {
            canSave = false
            errorMessage =
                "Your saved data couldn't be read. It has been kept intact. Quit and check ~/Library/Application Support/EyeCare/data.json."
        }
        notifications.onError = { [weak self] in self?.errorMessage = $0 }
        notifications.onAction = { [weak self] action, info in
            guard let self else { return }
            switch action {
            case "START_REST":
                self.startRest()
                self.onShow?()
            case "SNOOZE": self.snooze()
            case "LOG_DROPS":
                let slot: DropTime? = (info["hour"] as? Int).flatMap { hour in
                    (info["minute"] as? Int).map { DropTime(hour: hour, minute: $0) }
                }
                let day = (info["scheduledDate"] as? Double).map(Date.init(timeIntervalSince1970:))
                self.logDrops(slot: slot, scheduledDay: day)
            default: self.onShow?()
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        Task { await refreshPermissions() }
    }

    var settings: Settings { data.settings }
    var todayBreaks: Int { data.events(on: now, kind: .eyeBreak).count }
    var todayDrops: Int { data.events(on: now, kind: .drops).count }
    var completedSlots: Int { settings.dropTimes.filter { data.isCompleted($0, on: now) }.count }
    var remaining: Int { Int(ceil(clock.remaining(at: now))) }
    var isSuspended: Bool { !suspensions.isEmpty }
    var timeText: String { String(format: "%02d:%02d", remaining / 60, remaining % 60) }
    var latestDrop: CareEvent? {
        data.events.filter { $0.kind == .drops }.max { $0.date < $1.date }
    }
    var isRecentDrop: Bool { latestDrop.map { now.timeIntervalSince($0.date) < 30 } ?? false }
    var nextSlot: DropTime? { settings.dropTimes.sorted().first { !data.isCompleted($0, on: now) } }
    var nextOccurrence: DropOccurrence? { DropSchedule.upcoming(data: data, after: now).first }
    var isBreakOverdue: Bool { clock.phase == .due && !clock.isPaused }
    var overdue: Bool { settings.dropsEnabled && nextSlot.map { $0.date(on: now) <= now } ?? false }

    func tick() {
        now = Date()
        let oldPhase = clock.phase
        if clock.advance(to: now) {
            if settings.restSoundEnabled { restCompletionSound?.play() }
            data.events.append(CareEvent(date: now, kind: .eyeBreak))
            save()
        }
        if oldPhase != clock.phase, clock.phase == .focus {
            schedule()
            notifications.clearDeliveredBreaks()
        }
        let day = Calendar.current.startOfDay(for: now)
        if day != lastDay {
            lastDay = day
            data.prune(before: Calendar.current.date(byAdding: .day, value: -90, to: day) ?? day)
            save()
            schedule()
        }
        onStatusChange?()
    }

    func startRest() {
        guard !isSuspended else { return }
        now = Date()
        clock.startRest(at: now)
        changedClock()
    }

    func snooze() {
        guard !isSuspended else { return }
        now = Date()
        clock.reset(at: now, duration: 5 * 60)
        changedClock()
    }

    func cancelRest() {
        now = Date()
        clock.reset(at: now)
        changedClock()
    }

    func togglePause() {
        guard !isSuspended else { return }
        now = Date()
        if clock.isPaused { clock.resume(at: now) } else { clock.pause(at: now) }
        changedClock()
    }

    func suspend(_ reason: String) {
        guard !suspensions.contains(reason) else { return }
        if suspensions.isEmpty {
            autoResume = !clock.isPaused
            now = Date()
            clock.pause(at: now)
        }
        suspensions.insert(reason)
        changedClock()
    }

    func resume(_ reason: String) {
        guard suspensions.remove(reason) != nil else { return }
        now = Date()
        if suspensions.isEmpty, autoResume { clock.resume(at: now) }
        changedClock()
        Task { await refreshPermissions() }
    }

    func logDrops(slot: DropTime? = nil, scheduledDay: Date? = nil) {
        now = Date()
        let matchedSlot = slot ?? data.slotToLog(at: now)
        let day = scheduledDay ?? now
        if let matchedSlot, data.isCompleted(matchedSlot, on: day) { return }
        guard !isRecentDrop else { return }
        let event = CareEvent(
            date: now, kind: .drops, scheduledTime: matchedSlot,
            scheduledDay: matchedSlot == nil ? nil : day)
        data.events.append(event)
        undoEventID = event.id
        save()
        schedule()
        notifications.center.removeAllDeliveredNotifications()
        onStatusChange?()
    }

    func undo() {
        guard let undoEventID else { return }
        data.removeEvent(id: undoEventID)
        self.undoEventID = nil
        save()
        schedule()
        onStatusChange?()
    }

    func removeEvent(_ event: CareEvent) {
        data.removeEvent(id: event.id)
        if undoEventID == event.id { undoEventID = nil }
        save()
        schedule()
        onStatusChange?()
    }

    func updateSettings(_ transform: (inout Settings) -> Void) {
        transform(&data.settings)
        data.settings.dropTimes = Array(Set(data.settings.dropTimes)).sorted()
        save()
        schedule()
        onStatusChange?()
    }

    func updateSlot(_ old: DropTime, date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let replacement = DropTime(hour: components.hour ?? 9, minute: components.minute ?? 0)
        guard replacement == old || !settings.dropTimes.contains(replacement) else {
            errorMessage = "There's already a reminder at that time."
            return
        }
        updateSettings { $0.dropTimes = $0.dropTimes.map { $0 == old ? replacement : $0 } }
    }

    func addSlot() {
        guard settings.dropTimes.count < 6 else { return }
        let new = (0..<24).map { DropTime(hour: (9 + $0) % 24, minute: 0) }.first {
            !settings.dropTimes.contains($0)
        }!
        updateSettings { $0.dropTimes.append(new) }
    }

    func requestNotifications() {
        Task {
            do {
                _ = try await notifications.center.requestAuthorization(options: [.alert, .sound])
            } catch { errorMessage = error.localizedDescription }
            await refreshPermissions()
        }
    }

    func refreshPermissions() async {
        notificationStatus = await notifications.center.notificationSettings().authorizationStatus
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
        schedule()
    }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch { errorMessage = "Couldn't change launch at login: \(error.localizedDescription)" }
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func openNotificationSettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
        {
            NSWorkspace.shared.open(url)
        }
    }

    func stop() async {
        await notifications.stopBreakReminder()
        save()
    }

    private func changedClock() {
        notifications.clearDeliveredBreaks()
        schedule()
        onStatusChange?()
    }
    private func schedule() { notifications.schedule(data: data, clock: clock, now: Date()) }
    private func save() {
        guard canSave else { return }
        do { try store.save(data) } catch {
            errorMessage = "Couldn't save your changes: \(error.localizedDescription)"
        }
    }
}
