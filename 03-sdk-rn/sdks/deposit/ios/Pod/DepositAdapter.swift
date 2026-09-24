import Foundation
import UIKit
import FightDeckRNRuntime

@MainActor
public final class DepositAdapter: DepositHosting {
    private static let moduleName = "DepositFeature"
    private var lastPushed: DepositParams?

    public init() {}

    public func makeViewController(
        params: DepositParams,
        onResult: @escaping @Sendable (DepositResult) -> Void
    ) -> UIViewController {
        FeatureResults.deposit = onResult
        lastPushed = params
        return FightDeckRuntime.shared.makeViewController(
            moduleName: Self.moduleName,
            properties: Self.properties(from: params)
        )
    }

    /// Only a change reaches React: new properties re-render the surface from its root.
    public func update(params: DepositParams) {
        guard params != lastPushed else { return }
        lastPushed = params
        FightDeckRuntime.shared.updateProperties(
            moduleName: Self.moduleName,
            properties: Self.properties(from: params)
        )
    }

    private static func properties(from params: DepositParams) -> [String: Any] {
        [
            "themeJSON": params.themeJSON,
            "currentBalance": NSDecimalNumber(decimal: params.currentBalance).stringValue,
        ]
    }
}
