import Foundation
import UIKit

public struct RuntimeStartupMetrics: Sendable {
    public let coldMilliseconds: Double
    public let prewarmedMilliseconds: Double
}

@MainActor
public final class FightDeckRuntime {
    public static let shared = FightDeckRuntime()

    private var prewarmed = false
    /// Which module each surface controller renders, so a host can publish layout for the
    /// controller it holds without knowing the React module name behind it.
    private var modules: [ObjectIdentifier: String] = [:]

    private init() {}

    public func prewarm() {
        guard !prewarmed else { return }
        FightDeckRNHost.initializeHost()
        FightDeckRNHost.prewarm()
        prewarmed = true
    }

    public func makeViewController(moduleName: String, properties: [String: Any]) -> UIViewController {
        FightDeckRNHost.initializeHost()
        let controller = FightDeckRNHost.makeViewController(withModuleName: moduleName, properties: properties)
        modules[ObjectIdentifier(controller)] = moduleName
        return controller
    }

    public func updateProperties(moduleName: String, properties: [String: Any]) {
        FightDeckRNHost.updateProperties(properties, forModuleName: moduleName)
    }

    /// Hands the surface the chrome it has to clear. Unchanged layouts stop at the bridge.
    public func publishLayout(_ layout: SurfaceLayout, for controller: UIViewController) {
        guard let moduleName = modules[ObjectIdentifier(controller)] else { return }
        FightDeckPublishSurfaceLayout(
            moduleName,
            layout.safeAreaTop,
            layout.safeAreaBottom,
            layout.keyboardBottomInset,
            layout.chromeBackground,
            layout.textInputActive
        )
    }

    public func startupMetrics() -> RuntimeStartupMetrics {
        RuntimeStartupMetrics(
            coldMilliseconds: FightDeckRNHost.coldStartMilliseconds(),
            prewarmedMilliseconds: FightDeckRNHost.prewarmedStartMilliseconds()
        )
    }

    public func onHostResume() {
        FightDeckRNHost.onHostResume()
    }

    public func onHostPause() {
        FightDeckRNHost.onHostPause()
    }
}
