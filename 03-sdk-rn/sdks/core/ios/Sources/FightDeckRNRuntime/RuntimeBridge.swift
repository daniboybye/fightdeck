import Foundation
import UIKit

@MainActor
final class RuntimeBridge: NSObject {
    static let shared = RuntimeBridge()

    private var resultHandlers: [String: ([String: Any]) -> Void] = [:]
    private var featureModules: [String: String] = [:]
    private var surfaces: [String: RNFeatureSurface] = [:]

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

    func setResultHandler(for feature: String, handler: @escaping ([String: Any]) -> Void) {
        resultHandlers[feature] = handler
    }

    func startHostIfNeeded() {
        RNHostHolder.shared.start()
    }

    func makeSurfaceController(
        feature: String,
        properties: [String: Any],
        onResult: @escaping ([String: Any]) -> Void
    ) -> UIViewController {
        setResultHandler(for: feature, handler: onResult)
        startHostIfNeeded()
        if let existing = surfaces[feature] {
            updateProperties(feature: feature, properties: properties)
            return existing.viewController
        }
        let surface = RNFeatureSurface(
            feature: feature,
            moduleName: moduleName(for: feature),
            properties: properties
        )
        surfaces[feature] = surface
        return surface.viewController
    }

    func updateProperties(feature: String, properties: [String: Any]) {
        RNHostEngine.updateProperties(moduleName: moduleName(for: feature), properties: properties)
    }

    func destroyFeature(name: String) {
        surfaces.removeValue(forKey: name)
        RNHostHolder.shared.unmountFeature(moduleName(for: name))
        resultHandlers.removeValue(forKey: name)
        featureModules.removeValue(forKey: name)
    }

    private func moduleName(for feature: String) -> String {
        featureModules[feature] ?? feature
    }
}

extension Notification.Name {
    static let fightdeckFeatureResult = Notification.Name("FightDeckFeatureResult")
    static let fightdeckSurfaceLayout = Notification.Name("FightDeckSurfaceLayout")
}
