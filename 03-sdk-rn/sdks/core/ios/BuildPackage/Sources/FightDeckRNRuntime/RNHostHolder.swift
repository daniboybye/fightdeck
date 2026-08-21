import Foundation
import UIKit

/// Owns the single RCTHost for all SDK features.
@MainActor
final class RNHostHolder {
    static let shared = RNHostHolder()

    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        RNHostEngine.initialize()
        started = true
    }

    func unmountFeature(_ name: String) {
        RNHostEngine.destroyFeature(name)
    }
}

@MainActor
final class RNFeatureSurface {
    let feature: String
    let viewController: UIViewController

    init(feature: String, moduleName: String, properties: [String: Any]) {
        self.feature = feature
        self.viewController = RNHostEngine.makeViewController(
            moduleName: moduleName,
            initialProperties: properties
        )
    }
}
