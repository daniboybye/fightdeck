import Foundation

/// TurboModule port for platform preferences — mirrors PreferencesStore.ts.
/// Registered inside the SDK runtime, never in the host app.
@MainActor
@objcMembers
public final class PreferencesStoreModule: NSObject {
    private static var store: [String: String] = [:]

    public static func read(key: String) async -> String? {
        store[key]
    }

    public static func write(key: String, value: String) async {
        store[key] = value
    }
}
