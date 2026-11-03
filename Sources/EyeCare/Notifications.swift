import EyeCareCore
import Foundation
import UserNotifications

@MainActor
final class Notifications: NSObject, UNUserNotificationCenterDelegate {
    let center = UNUserNotificationCenter.current()
    var onAction: ((String, [AnyHashable: Any]) -> Void)?
    var onError: ((String) -> Void)?
    private var scheduleTask: Task<Void, Never>?

    override init() {
        super.init()
        center.delegate = self
        let start = UNNotificationAction(
            identifier: "START_REST", title: "Start 20-second rest", options: [.foreground])
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "In 5 minutes", options: [])
        let log = UNNotificationAction(identifier: "LOG_DROPS", title: "Log eye drops", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: "BREAK", actions: [start, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: "DROPS", actions: [log], intentIdentifiers: []),
        ])
    }

    func schedule(data: CareData, clock: BreakClock, now: Date) {
        scheduleTask?.cancel()
        let batch = UUID().uuidString
        scheduleTask = Task {
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            let pending = await center.pendingNotificationRequests()
            guard !Task.isCancelled else { return }
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier))
            let authorization = await center.notificationSettings()
            guard !Task.isCancelled,
                authorization.authorizationStatus == .authorized
                    || authorization.authorizationStatus == .provisional
            else { return }

            var requests: [UNNotificationRequest] = []
            if !clock.isPaused, clock.phase == .focus, clock.deadline > now {
                let content = UNMutableNotificationContent()
                content.title = "A little distance, a little rest."
                content.body = "Look at something 20 feet (about 6 metres) away for 20 seconds."
                content.categoryIdentifier = "BREAK"
                if data.settings.soundEnabled { content.sound = .default }
                requests.append(
                    UNNotificationRequest(
                        identifier: "break-\(batch)", content: content,
                        trigger: UNTimeIntervalNotificationTrigger(
                            timeInterval: max(1, clock.deadline.timeIntervalSinceNow),
                            repeats: false)))
            }
            for occurrence in DropSchedule.upcoming(data: data, after: now).prefix(49) {
                let content = UNMutableNotificationContent()
                content.title = "Time for your eye drops"
                content.body = "Your scheduled reminder. Log them when you've applied them."
                content.categoryIdentifier = "DROPS"
                content.userInfo = [
                    "hour": occurrence.time.hour, "minute": occurrence.time.minute,
                    "scheduledDate": occurrence.date.timeIntervalSince1970,
                ]
                if data.settings.soundEnabled { content.sound = .default }
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: occurrence.date)
                requests.append(
                    UNNotificationRequest(
                        identifier: "\(occurrence.id)-\(batch)", content: content,
                        trigger: UNCalendarNotificationTrigger(
                            dateMatching: components, repeats: false)))
            }
            for request in requests {
                guard !Task.isCancelled else { return }
                do {
                    try await center.add(request)
                    if Task.isCancelled {
                        center.removePendingNotificationRequests(withIdentifiers: [
                            request.identifier
                        ])
                        return
                    }
                } catch { onError?("Couldn't schedule reminders: \(error.localizedDescription)") }
            }
        }
    }

    func clearDeliveredBreaks() {
        Task {
            let delivered = await center.deliveredNotifications()
            center.removeDeliveredNotifications(
                withIdentifiers: delivered.filter {
                    $0.request.content.categoryIdentifier == "BREAK"
                }.map { $0.request.identifier })
        }
    }

    func stopBreakReminder() async {
        scheduleTask?.cancel()
        await scheduleTask?.value
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.filter {
                $0.content.categoryIdentifier == "BREAK"
            }.map(\.identifier))
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            self.onAction?(
                response.actionIdentifier, response.notification.request.content.userInfo)
            completionHandler()
        }
    }
}
