# Eye Care

A quiet, native macOS menu bar companion for screen breaks and eye-drop tracking.

## First version

- An eye icon in the menu bar. No Dock icon or permanent window.
- A compact popover with Today and Settings views. Follow the Mac's appearance.
- After 20 minutes, offer a 20-second rest looking at something 20 feet (about 6 metres) away. Start explicitly; count a break only after its countdown finishes.
- Take an early break, snooze for 5 minutes, or pause. Automatically pause on sleep and screen lock; resume on return without counting time away as a completed rest.
- Eye-drop reminders at editable daily times, enabled by the user after setting a schedule. No dosage recommendations.
- One-click drop logging, undo, today's progress, and a seven-day history. Store data locally.
- Optional macOS notifications and launch at login. Usable without notification permission.

## Implementation

SwiftUI for the popover, AppKit for the status item, UserNotifications for local reminders, ServiceManagement for login. A Swift package builds with Apple's command-line tools, without Xcode or external dependencies. A script bundles and signs a local `.app`.

Keep scheduling and timer logic separate from UI. Test transitions, pause/resume, local-calendar recurrence, completed slots, undo, and persistence. Build and inspect the real app.

## Scope decisions

- Defaults: 20-minute work interval and 20-second rest. Drop reminder times are examples until the user enables them.
- Start a fresh work timer when the app launches. Keep completed breaks, drops, and settings across launches.
- Notifications respect macOS Focus settings. Drop reminders are scheduled ahead so macOS can deliver them while the app is closed. Work-break reminders are removed on a normal quit.
- No account, cloud service, analytics, medical advice, or external dependencies.

## Later

Optional keyboard shortcuts, CSV export, and multiple named eye-drop products can follow actual usage.
