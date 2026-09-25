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

    private init() {}

    public func prewarm() {
        guard !prewarmed else { return }
        FightDeckRNHost.initializeHost()
        FightDeckRNHost.prewarm()
        prewarmed = true
    }

    public func makeViewController(moduleName: String, properties: [String: Any]) -> UIViewController {
        FightDeckRNHost.initializeHost()
        return FightDeckRNHost.makeViewController(withModuleName: moduleName, properties: properties)
    }

    public func updateProperties(moduleName: String, properties: [String: Any]) {
        FightDeckRNHost.updateProperties(properties, forModuleName: moduleName)
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
