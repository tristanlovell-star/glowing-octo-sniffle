import Foundation

/// The App Group shared by the iPhone app and its Screen Time extensions.
enum AppGroup {
    /// Comes from the `AppGroupIdentifier` Info.plist key, which is set to
    /// `group.$(BASE_BUNDLE_ID)` in every iOS target.
    static let identifier: String =
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
        ?? "group.com.example.schooltimemimic"

    static let defaults: UserDefaults = {
        #if os(watchOS)
        // The watch has no extensions to share with, so it keeps its own defaults.
        return .standard
        #else
        return UserDefaults(suiteName: identifier) ?? .standard
        #endif
    }()
}

/// Small Codable persistence helpers on top of the App Group defaults.
enum SharedStore {
    private static let contextKey = "schoolModeContext.v1"

    static func loadContext() -> SchoolModeContext {
        load(SchoolModeContext.self, key: contextKey) ?? .default
    }

    static func saveContext(_ context: SchoolModeContext) {
        save(context, key: contextKey)
    }

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }
}
