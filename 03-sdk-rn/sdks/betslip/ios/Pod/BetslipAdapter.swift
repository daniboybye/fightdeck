import FightDeckRNRuntime
import UIKit

public final class BetslipAdapter: FeatureAdapter<BetslipParams>, BetslipHosting {
    public init() {
        super.init(moduleName: "BetslipFeature") { params in
            [
                "themeJSON": params.themeJSON,
                "balance": NSDecimalNumber(decimal: params.balance).stringValue,
                "slipJSON": params.slipJSON,
                "eventsJSON": params.eventsJSON,
                "betPlacedMessage": params.betPlacedMessage,
            ]
        }
    }

    public func makeViewController(
        params: BetslipParams,
        onResult: @escaping @Sendable (BetslipResult) -> Void
    ) -> UIViewController {
        FeatureResults.betslip = onResult
        return makeViewController(params: params)
    }
}
