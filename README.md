# ntfy for iOS and watchOS

A native iOS and watchOS client for self-hosted [ntfy](https://ntfy.sh) servers that deliver through Apple Push
Notification service directly. It requires a server built from the [`apns` branch](https://github.com/linusr/ntfy/tree/apns)
of the ntfy fork; servers without APNs still work, but messages only arrive when the app refreshes.

## Requirements

- Xcode 27, iOS 26+, watchOS 26+
- An Apple Developer Program membership (push notifications, app groups and time-sensitive notifications need a paid team)
- [mise](https://mise.jdx.dev), which installs the pinned XcodeGen

## Setup

1. Set your team ID and identifiers in `project.yml`:
   - `DEVELOPMENT_TEAM`: your 10-character team ID (currently `2NDDPG5773`)
   - `APP_BUNDLE_ID` and `APP_GROUP`: identifiers registered to your team
2. In the Apple Developer portal, create an APNs auth key (*Keys → +*, enable Apple Push Notifications service).
3. Configure the server with that key and the app's bundle ID:
   ```yaml
   base-url: "https://ntfy.example.com"
   apns-key-file: "/etc/ntfy/AuthKey_ABC123DEFG.p8"
   apns-key-id: "ABC123DEFG"
   apns-team-id: "DEF123GHIJ"
   apns-bundle-id: "me.4vr.ntfy"
   apns-file: "/var/cache/ntfy/apns.db"
   ```
4. Generate the Xcode project and open it:
   ```sh
   mise exec -- xcodegen generate
   open Ntfy.xcodeproj
   ```

Debug builds register with the APNs sandbox and Release builds (TestFlight, App Store) with production, matching the
`aps-environment` entitlement of each configuration.

## Layout

| Path | Contents |
|---|---|
| `Packages/NtfyKit` | Shared models, API client, keychain credentials, push payload parsing, notification formatting |
| `App` | iOS app: SwiftData storage, sync, APNs registration, SwiftUI views |
| `NotificationService` | Formats each push, resolves `poll_request` payloads, adds action buttons and images |
| `Watch` | watchOS app showing recent messages synced from the iPhone |

The notification service extension never writes the app's database. It drops each message into an app-group inbox,
which the app imports on launch, so the two processes never share a store.

## Development

```sh
swift test --package-path Packages/NtfyKit
xcodebuild -project Ntfy.xcodeproj -scheme Ntfy -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Debug builds accept launch arguments that add a server and topics without going through onboarding:
`-seedServer http://localhost:8080 -seedTopics backups,alerts -openTopic alerts`.

`xcrun simctl push` delivers to Notification Center without running the notification service extension, so
extension behavior needs a device.

## Credits

Tag-to-emoji mapping from GitHub's [gemoji](https://github.com/github/gemoji) (MIT).
