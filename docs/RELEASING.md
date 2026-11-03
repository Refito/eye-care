# Releasing Eye Care

The release script builds a universal app for Apple Silicon and Intel, signs it with Developer ID and hardened runtime, notarizes it, staples Apple's ticket, verifies Gatekeeper acceptance, and creates a ZIP with a SHA-256 checksum. The ZIP contains `Eye Care.app`, installation instructions, and the MIT license.

## One-time Apple setup

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/) if needed.
2. Create and install a **Developer ID Application** certificate with its private key on the release Mac. Check availability with `security find-identity -v -p codesigning`.
3. Store notarization credentials in Keychain. Run the following in your own Terminal and follow the prompts; do not put passwords in the repository or chat:

   ```sh
   xcrun notarytool store-credentials "eye-care-notary"
   ```

   Use your Apple account, team ID, and an app-specific password, or a supported App Store Connect API key. See [Apple's notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow) for the available credential methods.

Keep the bundle identifier stable between releases. The current identifier is `local.eyecare.app`; changing it affects notification authorization, login-item registration, and macOS user defaults. The app's history file is stored separately in Application Support.

## Prepare a version

- Update `CFBundleShortVersionString` and increment `CFBundleVersion` in `Resources/Info.plist`.
- Write notes in `docs/releases/<version>.md`.
- Run the automated tests and manually check notifications, completion sound, sleep/lock, and launch at login. Check the app on an Intel Mac when available.
- Commit and push the version's changes. Wait for macOS CI to pass.

## Build the signed release

In Terminal, use your actual certificate name and Keychain profile:

```sh
export SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export NOTARY_PROFILE='eye-care-notary'
bash scripts/test.sh
bash scripts/release.sh
```

Artifacts are written to `build/releases/v<version>/`:

- `Eye-Care-<version>-universal.zip`
- `Eye-Care-<version>-universal.zip.sha256`
- `notarization.json`, containing Apple's submission result.

The script stops if credentials, notarization, stapling, signature verification, or Gatekeeper assessment fail. If Apple's submission command times out, inspect `notarization.json` and query the submission with `xcrun notarytool info <submission-id> --keychain-profile eye-care-notary` before submitting again. These build files are ignored by Git.

Extract the final ZIP into a temporary directory and verify the extracted app's signature and stapled ticket. Download the draft asset onto a separate Mac and check first launch before publishing.

## Verify packaging without Apple credentials

```sh
bash scripts/release.sh --unsigned
```

This creates an explicitly named `-unsigned.zip` development preview. It is ad hoc signed and is **not notarized**. It is intended for packaging verification and must not be used as the public release download. This command leaves the normal `build/Eye Care.app` alone.

## Upload and publish

For the first release, prepare a draft targeted at the tested commit:

```sh
gh release create v1.0.0 --draft --target main \
  --title 'Eye Care 1.0.0' --notes-file docs/releases/1.0.0.md
```

Once the signed archive is ready, attach the archive and checksum:

```sh
gh release upload v1.0.0 \
  build/releases/v1.0.0/Eye-Care-1.0.0-universal.zip \
  build/releases/v1.0.0/Eye-Care-1.0.0-universal.zip.sha256
```

Remove the preparation notice from the release notes, verify that the draft targets the tested commit, and publish it only after the downloaded asset passes verification. Then add a prominent download link to the README pointing to `https://github.com/Refito/eye-care/releases/latest` and replace the source-only installation notice. Keep source-build instructions for contributors.

Do not upload signing certificates, private keys, app-specific passwords, or Keychain exports to GitHub releases. The scripts use local Keychain credentials and do not require repository secrets.
