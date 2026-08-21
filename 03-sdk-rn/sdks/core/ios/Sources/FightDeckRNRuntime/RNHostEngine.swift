import Foundation
import UIKit

@MainActor
enum RNHostEngine {
    private static var controllers: [String: UIViewController] = [:]

    static func initialize() {
        RNHostEngineObjC.initializeHost()
    }

    static func makeViewController(moduleName: String, initialProperties: [String: Any]) -> UIViewController {
        if let existing = controllers[moduleName] {
            return existing
        }
        let controller = RNHostEngineObjC.makeSurface(
            moduleName: moduleName,
            initialProperties: initialProperties
        )
        controllers[moduleName] = controller
        return controller
    }

    static func destroyFeature(_ name: String) {
        controllers.removeValue(forKey: name)
        RNHostEngineObjC.destroySurface(name: name)
    }
}
