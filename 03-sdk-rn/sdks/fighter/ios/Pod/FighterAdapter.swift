import Foundation
import UIKit
import FightDeckRNRuntime

@MainActor
public final class FighterAdapter: FighterHosting {
    private static let moduleName = "FighterFeature"
    private var lastPushed: FighterParams?

    public init() {}

    public func makeViewController(params: FighterParams) -> UIViewController {
        lastPushed = params
        return FightDeckRuntime.shared.makeViewController(
            moduleName: Self.moduleName,
            properties: Self.properties(from: params)
        )
    }

    /// Only a change reaches React: new properties re-render the surface from its root.
    public func update(params: FighterParams) {
        guard params != lastPushed else { return }
        lastPushed = params
        FightDeckRuntime.shared.updateProperties(
            moduleName: Self.moduleName,
            properties: Self.properties(from: params)
        )
    }

    private static func properties(from params: FighterParams) -> [String: Any] {
        [
            "themeJSON": params.themeJSON,
            "fighterJSON": params.fighterJSON,
            "portraitURL": params.portraitURL,
        ]
    }
}
