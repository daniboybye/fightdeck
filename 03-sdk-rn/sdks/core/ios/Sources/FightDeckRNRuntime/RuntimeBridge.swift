import Foundation
import UIKit

@MainActor
final class RuntimeBridge: NSObject {
    static let shared = RuntimeBridge()

    private var hostStarted = false
    private var surfaces: [String: RNFeatureSurface] = [:]
    private var resultHandlers: [String: ([String: Any]) -> Void] = [:]
    private var featureModules: [String: String] = [:]

    override private init() {
        super.init()
    }

    func install() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFeatureResult(_:)),
            name: .fightdeckFeatureResult,
            object: nil
        )
    }

    @objc private func handleFeatureResult(_ note: Notification) {
        guard
            let feature = note.userInfo?["feature"] as? String,
            let payload = note.userInfo?["payload"] as? [String: Any]
        else { return }
        resultHandlers[feature]?(payload)
    }

    func registerFeature(name: String, moduleName: String) {
        featureModules[name] = moduleName
    }

    func startHostIfNeeded() {
        guard !hostStarted else { return }
        RNHostHolder.shared.start()
        hostStarted = true
    }

    func makeSurfaceController(
        feature: String,
        properties: [String: Any],
        onResult: @escaping ([String: Any]) -> Void
    ) -> UIViewController {
        let module = featureModules[feature] ?? feature
        resultHandlers[feature] = onResult
        let surface = RNFeatureSurface(feature: feature, moduleName: module, properties: properties)
        surfaces[feature] = surface
        return surface.viewController
    }

    func destroyFeature(name: String) {
        surfaces.removeValue(forKey: name)
        resultHandlers.removeValue(forKey: name)
        RNHostHolder.shared.unmountFeature(name)
    }
}

extension Notification.Name {
    static let fightdeckFeatureResult = Notification.Name("FightDeckFeatureResult")
}