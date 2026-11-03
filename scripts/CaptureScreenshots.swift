import AppKit
import EyeCareCore
import SwiftUI

// Renders the production view with fictional data. No screen recording is used.
@main
struct CaptureScreenshots {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        NSTimeZone.default = TimeZone(secondsFromGMT: 0)!
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 11, minute: 47))!
        var data = CareData()
        data.settings.dropsEnabled = true
        data.events = [60, 90, 120].map {
            CareEvent(date: date.addingTimeInterval(-Double($0) * 60), kind: .eyeBreak)
        }
        let morning = DropTime(hour: 9, minute: 0)
        data.events.append(CareEvent(date: morning.date(on: date), kind: .drops, scheduledTime: morning, scheduledDay: date))
        let focus = BreakClock(now: date.addingTimeInterval(-446))
        for dark in [false, true] {
            let model = AppModel(previewData: data, previewDate: date, previewClock: focus)
            try render(model, dark: dark, to: output.appendingPathComponent(dark ? "today-dark.png" : "today-light.png"))
        }
        for seconds in [20, 15, 10, 5, 1] {
            var rest = BreakClock(now: date)
            rest.startRest(at: date.addingTimeInterval(Double(seconds - 20)))
            let model = AppModel(previewData: data, previewDate: date, previewClock: rest)
            try render(model, dark: true, to: output.appendingPathComponent("rest-\(seconds).png"))
        }
        data.events.append(CareEvent(date: date, kind: .eyeBreak))
        let completed = AppModel(previewData: data, previewDate: date)
        try render(completed, dark: true, to: output.appendingPathComponent("rest-complete.png"))
    }

    @MainActor static func render(_ model: AppModel, dark: Bool, to url: URL) throws {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        NSApp.appearance = appearance
        let view = NSHostingView(rootView: PopoverView(model: model)
            .environment(\.colorScheme, dark ? .dark : .light)
            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            .environment(\.locale, Locale(identifier: "en_US_POSIX")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 348, height: 590),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = appearance
        window.contentView = view
        view.frame = NSRect(x: 0, y: 0, width: 348, height: 590)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: url)
    }
}
