import Foundation
import UIKit

public struct RuntimeStartupMetrics: Sendable {
    public let coldMilliseconds: Double
    public let prewarmedMilliseconds: Double
}

@MainActor
public final class FightDeckRuntime {
    public static let shared = FightDeckRuntime()

    private var configured = false
    private var prewarmed = false
    private var registeredFeatures = Set<String>()
    private var coldStartMs: Double = 0
    private var prewarmedStartMs: Double = 0

    private init() {}

    /// Call once at app launch — not per feature presentation.
    public func configure() {
        guard !configured else { return }
        configured = true
        RuntimeBridge.shared.install()
    }

    public func prewarm() {
        guard configured, !prewarmed else { return }
        let start = CFAbsoluteTimeGetCurrent()
        RuntimeBridge.shared.startHostIfNeeded()
        prewarmedStartMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
        prewarmed = true
    }

    public func registerFeature(_ name: String, moduleName: String) {
        registeredFeatures.insert(name)
        RuntimeBridge.shared.registerFeature(name: name, moduleName: moduleName)
    }

    public func makeViewController(
        feature: String,
        properties: [String: Any],
        onResult: @escaping @Sendable ([String: Any]) -> Void
    ) -> UIViewController {
        let start = CFAbsoluteTimeGetCurrent()
        RuntimeBridge.shared.startHostIfNeeded()
        if !prewarmed {
            coldStartMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
        }
        return RuntimeBridge.shared.makeSurfaceController(
            feature: feature,
            properties: properties,
            onResult: onResult
        )
    }

    public func updateProperties(feature: String, properties: [String: Any]) {
        RuntimeBridge.shared.updateProperties(feature: feature, properties: properties)
    }

    public func destroyFeature(_ name: String) {
        registeredFeatures.remove(name)
        RuntimeBridge.shared.destroyFeature(name: name)
    }

    public func startupMetrics() -> RuntimeStartupMetrics {
        RuntimeStartupMetrics(coldMilliseconds: coldStartMs, prewarmedMilliseconds: prewarmedStartMs)
    }
}
