import Foundation

/// Locations shared between the app and its notification service extension through the app group.
public enum SharedContainer {
    /// Read from the NtfyAppGroup Info.plist key, which the build sets from the APP_GROUP setting.
    public static var appGroup: String {
        Bundle.main.object(forInfoDictionaryKey: "NtfyAppGroup") as? String ?? "group.ntfy"
    }

    public static var url: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? URL.applicationSupportDirectory
    }

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }
}
