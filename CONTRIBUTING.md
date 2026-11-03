# Contributing to Eye Care

Bug reports, documentation improvements, accessibility fixes, and focused pull requests are welcome.

## Getting started

Fork and clone the repository, then open Terminal in your checkout. You need macOS 14 or later and a Swift 6.0 or newer toolchain.

```sh
bash scripts/test.sh
bash scripts/build.sh
open "build/Eye Care.app" --args --preview
```

Quit an existing Eye Care instance before launching the preview. The interactive preview shares the normal app's local settings and history; use a separate macOS account if you need an isolated manual test environment.

- `Sources/EyeCareCore`: timer, schedule, data models, and persistence.
- `Sources/EyeCare`: SwiftUI views and macOS integrations.
- `Tests/EyeCareCoreTests`: automated core behavior tests.
- `scripts`: local builds, tests, icon generation, and documentation rendering.

## Reporting a bug or proposing a feature

Search existing issues first. Use the bug report or feature request form in GitHub's Issues tab. For bugs, include the app version or commit, macOS version, processor type, reproduction steps, and expected versus actual behavior.

Use fictional examples in public reports. Remove personal activity, file paths, and other private information from logs and screenshots. You do not need to upload your saved history file.

For a substantial feature, open an issue to discuss the intended behavior before implementing it. Keep changes consistent with the app's simple menu bar experience and local storage model.

## Pull requests

Keep each pull request focused. Explain the problem, resulting behavior, and how you checked it. Update documentation when behavior changes, and add meaningful tests when changing timer, schedule, or persistence logic.

Before submitting:

```sh
bash scripts/test.sh
bash scripts/build.sh
codesign --verify --strict "build/Eye Care.app"
git diff --check
```

For UI changes, inspect Today, History, and Settings in light and dark appearances. Include screenshots using sample data when useful. For notification, sound, sleep/lock, or launch-at-login changes, describe the manual checks performed and any behavior you could not verify. GitHub Actions builds and tests on both processor architectures; Intel device testing is still welcome.

The documentation renderer uses sample data without loading personal history. Instructions for regenerating its images are in the README.

## License

Contributions are provided under the project's [MIT License](LICENSE).
