import Foundation
import UIKit

public struct RuntimeStartupMetrics: Sendable {
    public let coldMilliseconds: Double
    public let prewarmedMilliseconds: Double
}

@MainActor
public final class FightDeckRNRuntime {
    public static let shared = FightDeckRNRuntime()

    private var configured = false
    private var prewarmed = false
    private var registeredFeatures = Set<String>()
    private var featureModules: [String: String] = [:]

    private init() {}

    /// Call once at app launch — not per feature presentation.
    public func configure() {
        guard !configured else { return }
        configured = true
        RuntimeBridge.shared.install()
    }

    public func prewarm() {
        guard configured, !prewarmed else { return }
        FightDeckRNHost.initializeHost()
        FightDeckRNHost.prewarm()
        prewarmed = true
    }

    public func registerFeature(_ name: String, moduleName: String) {
        registeredFeatures.insert(name)
        featureModules[name] = moduleName
        RuntimeBridge.shared.registerFeature(name: name, moduleName: moduleName)
    }

    public func makeViewController(
        feature: String,
        properties: [String: Any],
        onResult: @escaping @Sendable ([String: Any]) -> Void
    ) -> UIViewController {
        FightDeckRNHost.initializeHost()
        if !prewarmed {
            _ = FightDeckRNHost.coldStartMilliseconds()
        }
        let module = featureModules[feature] ?? feature
        RuntimeBridge.shared.setResultHandler(for: feature, handler: onResult)
        return FightDeckRNHost.makeViewController(withModuleName: module, properties: properties)
    }

    public func destroyFeature(_ name: String) {
        registeredFeatures.remove(name)
        RuntimeBridge.shared.destroyFeature(name: name)
        if let module = featureModules[name] {
            FightDeckRNHost.destroySurface(module)
        }
    }

    public func startupMetrics() -> RuntimeStartupMetrics {
        RuntimeStartupMetrics(
            coldMilliseconds: FightDeckRNHost.coldStartMilliseconds(),
            prewarmedMilliseconds: FightDeckRNHost.prewarmedStartMilliseconds()
        )
    }
}
