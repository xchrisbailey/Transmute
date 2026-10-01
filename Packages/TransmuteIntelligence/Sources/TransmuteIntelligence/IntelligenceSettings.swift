import Foundation

/// Where generation may run. On-device is the default; Private Cloud Compute (free, no keys)
/// is opt-in from Settings (#18) for longer plans.
public enum ModelRoute: String, CaseIterable, Sendable {
    case onDeviceOnly
    case allowPrivateCloudCompute
}

/// The user's AI preferences, kept in user defaults so every screen reads the same value.
public struct IntelligenceSettings: Sendable {
    public static let routeKey = "intelligence.route"

    public var route: ModelRoute

    public init(route: ModelRoute = .onDeviceOnly) {
        self.route = route
    }

    public static func load(from defaults: UserDefaults = .standard) -> IntelligenceSettings {
        let route = defaults.string(forKey: routeKey).flatMap(ModelRoute.init(rawValue:)) ?? .onDeviceOnly
        return IntelligenceSettings(route: route)
    }

    public func save(to defaults: UserDefaults = .standard) {
        defaults.set(route.rawValue, forKey: Self.routeKey)
    }
}
