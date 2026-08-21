import Foundation
import UIKit

@MainActor
final class RuntimeBridge: NSObject {
    static let shared = RuntimeBridge()

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

    func setResultHandler(for feature: String, handler: @escaping ([String: Any]) -> Void) {
        resultHandlers[feature] = handler
    }

    func destroyFeature(name: String) {
        resultHandlers.removeValue(forKey: name)
        featureModules.removeValue(forKey: name)
    }
}

extension Notification.Name {
    static let fightdeckFeatureResult = Notification.Name("FightDeckFeatureResult")
}
