# First-version verification

Verified on the local Apple Silicon Mac, November 2, 2026.

- Release `.app` builds using `bash scripts/build.sh`.
- Local ad hoc code signature passes `codesign --verify --strict`.
- Executable dependencies are macOS system libraries and frameworks.
- All 10 Swift Testing tests pass using `bash scripts/test.sh`.
- Live native UI inspected in dark appearance: Today, guided rest, Settings, and History.
- One-click drop logging increases today's count; Undo restores it and re-enables logging.
- Pause and resume update the work timer correctly.
- Adding, editing with the native time picker, and removing a daily reminder work.
- Daily reminders can be enabled and disabled. Test changes were restored to the initial schedule.
- A guided rest counts down; ending it early leaves History empty.
- Quit and reopen work; saved settings and empty history survive restart. A new work countdown begins.

Notification authorization/delivery, Focus interactions, launch-at-login registration, and physical sleep/lock events require a separate device-level check. These were left for the user to opt into. Core pause/resume and local-calendar scheduling behavior are covered by automated tests.

The app is a local development build. Developer ID signing and notarization for distribution are outside this first version.
