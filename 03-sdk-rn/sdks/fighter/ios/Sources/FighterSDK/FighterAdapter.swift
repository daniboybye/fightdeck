import Foundation
import UIKit
import FightDeckRNRuntime

@MainActor
public final class FighterAdapter: FighterHosting {
    private var configured = false

    public init() {}

    public func configure() {
        guard !configured else { return }
        FightDeckRNRuntime.shared.configure()
        FightDeckRNRuntime.shared.registerFeature("fighter", moduleName: "FighterFeature")
        configured = true
    }

    public func makeViewController(
        params: FighterParams,
        onResult: @escaping @Sendable (FighterResult) -> Void
    ) -> UIViewController {
        configure()
        let properties: [String: Any] = Self.properties(from: params)
        return FightDeckRNRuntime.shared.makeViewController(feature: "fighter", properties: properties) { payload in
            let result = FighterAdapter.mapResult(payload)
            Task { @MainActor in
                onResult(result)
            }
        }
    }

    public func update(params: FighterParams) {
        configure()
        FightDeckRNRuntime.shared.updateProperties(
            feature: "fighter",
            properties: Self.properties(from: params)
        )
    }

    public func destroy() {
        FightDeckRNRuntime.shared.destroyFeature("fighter")
    }

    nonisolated private static func properties(from params: FighterParams) -> [String: Any] {
        [
            "themeJSON": params.themeJSON,
            "fighterJSON": params.fighterJSON,
            "portraitURL": params.portraitURL,
            "safeAreaTop": Double(params.safeAreaTop),
            "safeAreaBottom": Double(params.safeAreaBottom),
            "chromeBackground": params.chromeBackground,
            "layoutStamp": params.layoutStamp,
        ]
    }

    nonisolated private static func mapResult(_ payload: [String: Any]) -> FighterResult {
        switch payload["type"] as? String {
        default:
            return .cancelled
        }
    }
}
