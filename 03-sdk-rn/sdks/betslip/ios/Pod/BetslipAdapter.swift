import Foundation
import UIKit
import FightDeckRNRuntime

@MainActor
public final class BetslipAdapter: BetslipHosting {
    private static let moduleName = "BetslipFeature"
    private var lastPushed: BetslipParams?

    public init() {}

    public func makeViewController(
        params: BetslipParams,
        onResult: @escaping @Sendable (BetslipResult) -> Void
    ) -> UIViewController {
        FeatureResults.betslip = onResult
        lastPushed = params
        return FightDeckRuntime.shared.makeViewController(
            moduleName: Self.moduleName,
            properties: Self.properties(from: params)
        )
    }

    /// Only a change reaches React: new properties re-render the surface from its root.
    public func update(params: BetslipParams) {
        guard params != lastPushed else { return }
        lastPushed = params
        FightDeckRuntime.shared.updateProperties(
            moduleName: Self.moduleName,
            properties: Self.properties(from: params)
        )
    }

    private static func properties(from params: BetslipParams) -> [String: Any] {
        [
            "themeJSON": params.themeJSON,
            "balance": NSDecimalNumber(decimal: params.balance).stringValue,
            "slipJSON": params.slipJSON,
            "eventsJSON": params.eventsJSON,
            "betPlacedMessage": params.betPlacedMessage,
        ]
    }
}
