# Eye Care

A minimalist, native macOS menu bar app for the 20–20–20 rule and eye-drop logging. SwiftUI + AppKit, no dependencies, no account, no network requests. Requires macOS 14 or later.

## Run

```sh
bash scripts/build.sh
open "build/Eye Care.app"
```

Click the **eye icon** in the menu bar. Right-click it for pause, log, and quit. The app has no Dock icon. You can drag the built app into Applications for everyday use, then enable **Launch at login** in its settings. Keep a single installed copy for predictable login and notification behavior.

## Use

- **Eye breaks:** A 20-minute countdown offers a 20-second rest. Click **Take a 20s break**, then look at something 20 feet (about 6 metres) away. Only a finished countdown adds a completed break. Closing the popover keeps the countdown running.
- **Pause:** Use the pause icon. Sleep and screen lock pause automatically; returning resumes the remaining time. A manual pause stays paused. Each app launch starts a new 20-minute session.
- **Snooze:** When a break is due, defer it for five minutes.
- **Eye drops:** Click **Log eye drops** after applying them. Undo an accidental log immediately, or remove it in History. Rapid duplicate logs are blocked for 30 seconds.
- **Fixed daily reminders:** Open the sliders icon, edit the example times, then turn on **Daily reminders**. Up to six times per day. Logging satisfies the earliest unlogged reminder already due, or one within the next 30 minutes. Unscheduled logs are recorded too. Reminder times do not specify dosage.
- **Notifications:** Opt in with **Enable**. Notifications offer **Start rest**, **In 5 minutes**, or **Log eye drops**. macOS notification and Focus settings control banner visibility. The timer and manual logging work without permission.
- **History:** Review seven days in the app. Settings and up to 90 days of activity are retained locally in `~/Library/Application Support/EyeCare/data.json`.

Drop notifications are scheduled up to seven days ahead, including while the app is closed. Opening the app refreshes them. A normal quit removes the pending work-break reminder. Run the app each day to keep the reminder queue current. There is no background server or automatic restart after quitting.

## Development

Apple's command-line tools are sufficient; Xcode is optional.

```sh
bash scripts/test.sh
bash scripts/build.sh
open "build/Eye Care.app" --args --preview
```

`--preview` opens the production popover view in a regular window for layout inspection. Launch from the `.app` bundle, rather than `swift run`, so macOS notifications have a bundle identity.

The build script creates a local ad hoc signature. Sharing with other Macs requires your own Developer ID signing and notarization. Launch at login uses Apple's ServiceManagement API; macOS may require approval in Login Items.

See [PLAN.md](PLAN.md) for the product scope. Core timer, schedule, and persistence code lives in `Sources/EyeCareCore`; native UI and integrations live in `Sources/EyeCare`.
