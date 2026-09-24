import FightDeckRNRuntime
import UIKit

public final class DepositAdapter: FeatureAdapter<DepositParams>, DepositHosting {
    public init() {
        super.init(moduleName: "DepositFeature") { params in
            [
                "themeJSON": params.themeJSON,
                "currentBalance": NSDecimalNumber(decimal: params.currentBalance).stringValue,
            ]
        }
    }

    public func makeViewController(
        params: DepositParams,
        onResult: @escaping @Sendable (DepositResult) -> Void
    ) -> UIViewController {
        FeatureResults.deposit = onResult
        return makeViewController(params: params)
    }
}
