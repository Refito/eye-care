import EyeCareCore
import ServiceManagement
import SwiftUI

private enum Palette {
    private static func gray(light: CGFloat, dark: CGFloat) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                NSColor(
                    white: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                        ? dark : light, alpha: 1)
            })
    }

    static let background = gray(light: 0.96, dark: 0.065)
    static let card = gray(light: 1, dark: 0.14)
    static let ink = gray(light: 0.08, dark: 0.96)
    static let accent = gray(light: 0.16, dark: 0.88)
    static let buttonText = gray(light: 1, dark: 0.06)
    static let backgroundGradient = LinearGradient(
        colors: [card, background, gray(light: 0.89, dark: 0.035)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let cardGradient = LinearGradient(
        colors: [card, gray(light: 0.94, dark: 0.095)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let timerGradient = LinearGradient(
        colors: [gray(light: 0.91, dark: 0.19), gray(light: 0.99, dark: 0.10)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let accentGradient = LinearGradient(
        colors: [gray(light: 0.30, dark: 1), accent],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct PopoverView: View {
    @ObservedObject var model: AppModel
    private typealias Page = AppPage
    private var page: Page {
        get { model.page }
        nonmutating set { model.page = newValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch page {
                case .today: today
                case .history: history
                case .settings: settings
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            footer
        }
        .frame(width: 348, height: 590)
        .background(Palette.backgroundGradient)
        .foregroundStyle(Palette.ink)
        .tint(Palette.accent)
        .toggleStyle(MonochromeToggle())
        .alert(
            "Eye Care",
            isPresented: Binding(
                get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
        ) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "eye")
                .font(.system(size: 19, weight: .medium)).foregroundStyle(Palette.accent)
            Text("Eye Care").font(.system(size: 15, weight: .semibold))
            Spacer()
            HStack(spacing: 3) {
                navButton("Today", page: .today)
                navButton("History", page: .history)
            }
            Button {
                page = page == .settings ? .today : .settings
            } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 14))
                    .frame(width: 28, height: 28)
                    .background(
                        page == .settings ? Palette.accent.opacity(0.12) : .clear,
                        in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain).foregroundStyle(page == .settings ? Palette.accent : .secondary)
            .help("Settings").accessibilityLabel("Settings").accessibilityIdentifier("settings")
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 18)
    }

    private func navButton(_ title: String, page target: Page) -> some View {
        Button {
            page = target
        } label: {
            Text(title).font(.system(size: 11, weight: page == target ? .semibold : .regular))
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(
                    page == target ? Palette.card : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain).foregroundStyle(page == target ? .primary : .secondary)
    }

    private var today: some View {
        ScrollView {
            VStack(spacing: 16) {
                timerCard
                dropsCard
                HStack(spacing: 0) {
                    stat(value: model.todayBreaks, title: "breaks taken", symbol: "eye")
                    Rectangle().fill(.primary.opacity(0.08)).frame(width: 1, height: 24)
                    stat(value: model.todayDrops, title: "drops logged", symbol: "drop")
                }
                if model.notificationStatus == .notDetermined {
                    HStack(spacing: 7) {
                        Image(systemName: "bell").foregroundStyle(.secondary)
                        Text("A gentle nudge when it's time.").foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Button("Enable") { model.requestNotifications() }.buttonStyle(.plain)
                            .foregroundStyle(Palette.accent)
                    }.font(.system(size: 10))
                } else if model.notificationStatus == .denied {
                    Button {
                        model.openNotificationSettings()
                    } label: {
                        Label("Notifications are off · Open settings", systemImage: "bell.slash")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }.scrollIndicators(.hidden)
    }

    private var timerCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text(timerLabel).font(.system(size: 9, weight: .semibold)).tracking(1.6)
                Spacer()
                if model.clock.phase != .resting {
                    Button {
                        model.togglePause()
                    } label: {
                        Image(systemName: model.clock.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 10)).frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain).disabled(model.isSuspended)
                    .help(model.clock.isPaused ? "Resume break timer" : "Pause break timer")
                    .accessibilityLabel(
                        model.clock.isPaused ? "Resume break timer" : "Pause break timer")
                }
            }
            .foregroundStyle(Palette.accent)
            Text(
                model.clock.phase == .due && !model.clock.isPaused ? "Time to rest" : model.timeText
            )
            .font(
                .system(size: model.clock.phase == .due ? 35 : 54, weight: .light, design: .rounded)
            )
            .monospacedDigit().tracking(-1.5)
            .foregroundStyle(Palette.accent)
            .frame(height: 72).padding(.top, 9)
            .accessibilityLabel("\(timerLabel), \(model.timeText)")
            Text(timerSubtitle)
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(height: 32)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.accent.opacity(0.10))
                    Capsule().fill(Palette.accentGradient)
                        .frame(width: max(0, geometry.size.width * progress))
                }
            }.frame(height: 3).padding(.top, 14).padding(.bottom, 18)

            if model.clock.phase == .resting {
                Button("End rest early") { model.cancelRest() }
                    .buttonStyle(SecondaryButton()).help("An unfinished rest won't be counted")
            } else {
                Button {
                    model.startRest()
                } label: {
                    Label(
                        model.clock.phase == .due ? "Start 20-second rest" : "Take a 20s break",
                        systemImage: "eye"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButton()).disabled(model.isSuspended)
                .accessibilityIdentifier("start-rest")
            }
            if model.clock.phase == .due {
                Button("Remind me in 5 minutes") { model.snooze() }
                    .font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(.secondary)
                    .padding(.top, 10)
            }
        }
        .padding(18)
        .background(Palette.timerGradient, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.ink.opacity(0.06)))
    }

    private var timerLabel: String {
        if model.clock.isPaused { return "TIMER PAUSED" }
        switch model.clock.phase {
        case .focus: return "NEXT EYE BREAK"
        case .due: return "A MOMENT FOR YOUR EYES"
        case .resting: return "LOOK INTO THE DISTANCE"
        }
    }

    private var timerSubtitle: String {
        if model.clock.isPaused { return "A little pause. Resume when you're ready." }
        if model.clock.phase == .resting {
            return "Find something 20 feet (6 metres) away.\nLet your eyes settle there."
        }
        return "20 minutes of focus. 20 seconds of rest."
    }

    private var progress: Double {
        let duration =
            model.clock.phase == .resting ? BreakClock.restDuration : BreakClock.workDuration
        return min(1, max(0, 1 - model.clock.remaining(at: model.now) / duration))
    }

    private var dropsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "drop").foregroundStyle(Palette.accent).font(.system(size: 14))
                Text("Eye drops").font(.system(size: 13, weight: .semibold))
                Spacer()
                if model.settings.dropsEnabled {
                    Text("\(model.completedSlots)/\(model.settings.dropTimes.count) today")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            if model.settings.dropsEnabled {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 5),
                        count: min(3, max(1, model.settings.dropTimes.count))), spacing: 5
                ) {
                    ForEach(model.settings.dropTimes.sorted()) { slot in
                        let done = model.data.isCompleted(slot, on: model.now)
                        HStack(spacing: 4) {
                            if done {
                                Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                            }
                            Text(slot.date(on: model.now), style: .time).font(.system(size: 10))
                                .monospacedDigit()
                        }
                        .foregroundStyle(done ? Palette.accent : .secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .background(
                            done ? Palette.accent.opacity(0.09) : .primary.opacity(0.035),
                            in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            } else {
                HStack {
                    Text("Your routine, at your own pace.").font(.system(size: 11)).foregroundStyle(
                        .secondary)
                    Spacer(minLength: 0)
                    Button("Set times") { page = .settings }.buttonStyle(.plain).font(
                        .system(size: 10, weight: .medium)
                    ).foregroundStyle(Palette.accent)
                }
            }
            Button {
                model.logDrops()
            } label: {
                Label(
                    model.isRecentDrop ? "Drops logged" : "Log eye drops",
                    systemImage: model.isRecentDrop ? "checkmark" : "plus"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButton()).disabled(model.isRecentDrop).accessibilityIdentifier(
                "log-drops")

            HStack(spacing: 4) {
                if model.undoEventID != nil {
                    Text(model.isRecentDrop ? "Logged just now" : "Last drop logged")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Undo") { model.undo() }.buttonStyle(.plain).foregroundStyle(
                        Palette.accent
                    ).accessibilityIdentifier("undo-drop")
                } else if model.settings.dropsEnabled {
                    Circle().fill(Palette.accent.opacity(model.overdue ? 1 : 0.5)).frame(
                        width: 4, height: 4)
                    Text(dropStatus).foregroundStyle(.secondary)
                } else if let last = model.latestDrop {
                    Text("Last logged \(last.date.formatted(.relative(presentation: .named)))")
                        .foregroundStyle(.secondary)
                } else {
                    Text("One click after you've applied them.").foregroundStyle(.tertiary)
                }
            }.font(.system(size: 10)).frame(minHeight: 12)
        }
        .padding(16)
        .background(Palette.cardGradient, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.05)))
    }

    private var dropStatus: String {
        if let slot = model.nextSlot {
            let text = slot.date(on: model.now).formatted(date: .omitted, time: .shortened)
            return model.overdue
                ? "\(text) reminder · log when applied" : "Next reminder at \(text)"
        }
        if let next = model.nextOccurrence {
            return
                "All logged · next \(next.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))"
        }
        return "All scheduled drops logged"
    }

    private func stat(value: Int, title: String, symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(.tertiary)
            Text("\(value)").font(.system(size: 14, weight: .medium)).monospacedDigit()
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Make it your routine.").font(.system(size: 20, weight: .medium))
                    Text("Small reminders, on your terms.").font(.system(size: 11)).foregroundStyle(
                        .secondary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("EYE DROPS")
                    Toggle("Daily reminders", isOn: setting(\.dropsEnabled)).font(.system(size: 12))
                    Text(
                        "Set the times you already use for your drops.\nYou can always log them manually."
                    )
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(
                        horizontal: false, vertical: true)
                    ForEach(model.settings.dropTimes.sorted()) { slot in
                        HStack {
                            Image(systemName: "drop").foregroundStyle(Palette.accent).font(
                                .system(size: 12))
                            DatePicker(
                                "Reminder time",
                                selection: Binding(
                                    get: { slot.date(on: model.now) },
                                    set: { model.updateSlot(slot, date: $0) }),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden().datePickerStyle(.field).accessibilityLabel(
                                "Reminder at \(slot.id)")
                            Spacer()
                            Button {
                                model.updateSettings { $0.dropTimes.removeAll { $0 == slot } }
                            } label: {
                                Image(systemName: "minus.circle").foregroundStyle(.secondary)
                            }.buttonStyle(.plain).disabled(model.settings.dropTimes.count <= 1)
                                .help("Remove reminder").accessibilityLabel(
                                    "Remove \(slot.id) reminder")
                        }
                    }
                    Button {
                        model.addSlot()
                    } label: {
                        Label("Add a time", systemImage: "plus")
                    }
                    .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(Palette.accent)
                    .disabled(model.settings.dropTimes.count >= 6)
                }.padding(16).background(
                    Palette.cardGradient, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 13) {
                    sectionTitle("PREFERENCES")
                    Toggle("Show timer in menu bar", isOn: setting(\.showCountdown))
                    Toggle("Reminder sound", isOn: setting(\.soundEnabled))
                    Toggle("Sound when rest ends", isOn: setting(\.restSoundEnabled))
                    Toggle(
                        "Launch at login",
                        isOn: Binding(
                            get: { model.loginEnabled || model.loginNeedsApproval },
                            set: { model.setLogin($0) }))
                    if model.loginNeedsApproval {
                        Button("Approve in Login Items…") {
                            SMAppService.openSystemSettingsLoginItems()
                        }.buttonStyle(.plain).foregroundStyle(Palette.accent)
                    }
                    Divider()
                    HStack {
                        Label("Notifications", systemImage: "bell").font(.system(size: 12))
                        Spacer()
                        Button(
                            model.notificationStatus == .notDetermined
                                ? "Enable…"
                                : model.notificationStatus == .authorized
                                    ? "Allowed ↗" : "Open settings ↗"
                        ) {
                            if model.notificationStatus == .notDetermined {
                                model.requestNotifications()
                            } else {
                                model.openNotificationSettings()
                            }
                        }.buttonStyle(.plain).foregroundStyle(Palette.accent).font(
                            .system(size: 11))
                    }
                }.font(.system(size: 12)).toggleStyle(MonochromeToggle()).controlSize(.small)

                Text(
                    "Breaks pause when your Mac sleeps or locks.\nYour history stays on this Mac. No account needed."
                )
                .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(3)
            }.padding(.horizontal, 20).padding(.bottom, 20)
        }.scrollIndicators(.hidden)
    }

    private var history: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("A little care adds up.").font(.system(size: 20, weight: .medium))
                    Text("Your last seven days.").font(.system(size: 11)).foregroundStyle(
                        .secondary)
                }
                ForEach(0..<7, id: \.self) { offset in
                    if let day = Calendar.current.date(
                        byAdding: .day, value: -offset, to: model.now)
                    {
                        let events = model.data.events(on: day).sorted { $0.date > $1.date }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(
                                    offset == 0
                                        ? "Today"
                                        : offset == 1
                                            ? "Yesterday" : day.formatted(.dateTime.weekday(.wide))
                                )
                                .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text(day.formatted(.dateTime.month(.abbreviated).day())).font(
                                    .system(size: 10)
                                ).foregroundStyle(.tertiary)
                            }
                            if events.isEmpty {
                                Text("No activity logged").font(.system(size: 11)).foregroundStyle(
                                    .tertiary)
                            } else {
                                HStack(spacing: 14) {
                                    Label(
                                        "\(events.filter { $0.kind == .eyeBreak }.count) breaks",
                                        systemImage: "eye")
                                    Label(
                                        "\(events.filter { $0.kind == .drops }.count) drops",
                                        systemImage: "drop")
                                }.font(.system(size: 11)).foregroundStyle(.secondary)
                                ForEach(events.filter { $0.kind == .drops }) { event in
                                    HStack {
                                        Text("Eye drops").foregroundStyle(Palette.accent)
                                        Spacer()
                                        Text(event.date, style: .time).foregroundStyle(.secondary)
                                        Button {
                                            model.removeEvent(event)
                                        } label: {
                                            Image(systemName: "xmark").font(.system(size: 8))
                                        }
                                        .buttonStyle(.plain).foregroundStyle(.tertiary).help(
                                            "Remove this log"
                                        ).accessibilityLabel(
                                            "Remove drop log at \(event.date.formatted(date: .omitted, time: .shortened))"
                                        )
                                    }.font(.system(size: 10))
                                }
                            }
                        }.padding(14).background(
                            Palette.cardGradient, in: RoundedRectangle(cornerRadius: 11))
                    }
                }
            }.padding(.horizontal, 20).padding(.bottom, 20)
        }.scrollIndicators(.hidden)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(
            .secondary)
    }

    private func setting(_ key: WritableKeyPath<EyeCareCore.Settings, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.settings[keyPath: key] },
            set: { value in model.updateSettings { $0[keyPath: key] = value } })
    }

    private var footer: some View {
        HStack {
            Text("20 · 20 · 20").font(.system(size: 10, weight: .medium)).tracking(1.5)
                .foregroundStyle(.tertiary)
            Spacer()
            Menu {
                Button("About Eye Care") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Eye Care", .applicationVersion: "1.0",
                        .credits: NSAttributedString(
                            string: "Small reminders. A little more care.\nBuilt for your menu bar."
                        ),
                    ])
                }
                Divider()
                Button("Quit Eye Care", role: .destructive) { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 13)).foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("About and quit")
                .accessibilityLabel("More options")
        }.padding(.horizontal, 22).padding(.vertical, 12)
    }
}

private struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .foregroundStyle(Palette.buttonText).padding(.vertical, 11).frame(maxWidth: .infinity)
            .background(
                Palette.accentGradient.opacity(configuration.isPressed ? 0.8 : 1),
                in: RoundedRectangle(cornerRadius: 9)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct SecondaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary.opacity(configuration.isPressed ? 0.5 : 0.8))
            .padding(.vertical, 9).frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Palette.ink.opacity(configuration.isPressed ? 0.10 : 0.025),
                        Palette.ink.opacity(configuration.isPressed ? 0.05 : 0.065),
                    ], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.10)))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct MonochromeToggle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer()
                Capsule()
                    .fill(configuration.isOn ? Palette.accent : Palette.ink.opacity(0.15))
                    .frame(width: 28, height: 17)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(configuration.isOn ? Palette.buttonText : Palette.card)
                            .frame(width: 13, height: 13).padding(2)
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .opacity(isEnabled ? 1 : 0.45)
    }
}
