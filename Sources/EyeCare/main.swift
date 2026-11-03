import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var model: AppModel!
    private var observers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var previewWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Reopening the .app should reveal the existing instance, not create another timer.
        let others = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.eyecare.app"
        )
        .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let existing = others.first {
            existing.activate()
            NSApp.terminate(nil)
            return
        }

        model = AppModel()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            button.setAccessibilityLabel("Eye Care")
        }
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: PopoverView(model: model))
        popover.contentSize = NSSize(width: 348, height: 590)
        model.onShow = { [weak self] in self?.showPopover() }
        model.onStatusChange = { [weak self] in self?.updateStatus() }
        updateStatus()
        observeWorkspace()

        if ProcessInfo.processInfo.arguments.contains("--preview") {
            // A regular window for layout inspection, sharing the production view and state.
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 348, height: 590),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Eye Care — Preview"
            window.contentView = NSHostingView(rootView: PopoverView(model: model))
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            previewWindow = window
        } else if !UserDefaults.standard.bool(forKey: "hasOpened") {
            UserDefaults.standard.set(true, forKey: "hasOpened")
            showPopover()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool)
        -> Bool
    {
        showPopover()
        return true
    }

    @objc private func togglePopover() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(
                withTitle: model.clock.isPaused ? "Resume breaks" : "Pause breaks",
                action: #selector(pauseTimer), keyEquivalent: "")
            menu.addItem(withTitle: "Log eye drops", action: #selector(logDrops), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit Eye Care", action: #selector(quit), keyEquivalent: "q")
            menu.items.forEach { $0.target = self }
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        model.tick()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        Task { await model.refreshPermissions() }
    }

    private func updateStatus() {
        let symbol =
            model.clock.isPaused
            ? "eye.slash" : model.clock.phase == .resting ? "eye.circle" : "eye"
        statusItem.button?.image = statusImage(symbol: symbol)
        statusItem.button?.title =
            model.settings.showCountdown
            ? " \(model.clock.phase == .due ? "Rest" : model.timeText)" : ""

        var attention: [String] = []
        if model.isBreakOverdue { attention.append("Eye break overdue") }
        if model.overdue { attention.append("Eye drops overdue") }
        let detail =
            model.clock.isPaused
            ? "Break timer paused"
            : model.clock.phase == .due
                ? "Time for a 20-second rest"
                : "\(model.timeText) until \(model.clock.phase == .resting ? "rest ends" : "your next break")"
        let description = (["Eye Care"] + attention + [detail]).joined(separator: " · ")
        statusItem.button?.toolTip = description
        statusItem.button?.setAccessibilityLabel(description)
    }

    private func statusImage(symbol: String) -> NSImage? {
        guard let eye = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else {
            return nil
        }
        var markers: [NSImage] = []
        if model.isBreakOverdue,
            let badge = NSImage(
                systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil)
        {
            markers.append(badge)
        }
        if model.overdue,
            let drop = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: nil)
        {
            markers.append(drop)
        }
        guard !markers.isEmpty else {
            eye.isTemplate = true
            return eye
        }

        // Template drawing keeps all indicators readable in light and dark menu bars.
        let image = NSImage(
            size: NSSize(width: 18 + markers.count * 12, height: 18), flipped: false
        ) { _ in
            eye.draw(in: NSRect(x: 0, y: 1, width: 18, height: 16))
            for (index, marker) in markers.enumerated() {
                marker.draw(in: NSRect(x: 21 + index * 12, y: 4, width: 9, height: 10))
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private func observeWorkspace() {
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(
            workspace.addObserver(
                forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.model.suspend("sleep") }
            })
        observers.append(
            workspace.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.model.resume("sleep") }
            })
        observers.append(
            workspace.addObserver(
                forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.model.suspend("session") }
            })
        observers.append(
            workspace.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.model.resume("session") }
            })
        for (name, locked) in [
            ("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false),
        ] {
            distributedObservers.append(
                DistributedNotificationCenter.default().addObserver(
                    forName: NSNotification.Name(name), object: nil, queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        if locked {
                            self?.model.suspend("lock")
                        } else {
                            self?.model.resume("lock")
                        }
                    }
                })
        }
        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in await self?.model.refreshPermissions() }
            })
        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name.NSSystemTimeZoneDidChange, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in await self?.model.refreshPermissions() }
            })
    }

    @objc private func pauseTimer() { model.togglePause() }
    @objc private func logDrops() { model.logDrops() }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        Task {
            await model.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
    withExtendedLifetime(delegate) {}
}
