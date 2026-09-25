import FightDeckRNRuntime
import Foundation
import UIKit

public final class BetslipAdapter: FeatureAdapter<BetslipParams>, BetslipHosting {
    public init() {
        super.init(moduleName: "BetslipFeature") { params in
            [
                "balance": NSDecimalNumber(decimal: params.balance).stringValue,
                "slipJSON": slipJSON(params),
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

/// Money travels as a plain two-place decimal, the form the screen's parser and its stake
/// field both expect.
private func amount(_ value: Decimal) -> String {
    var input = value
    var rounded = Decimal()
    NSDecimalRound(&rounded, &input, 2, .plain)
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    formatter.usesGroupingSeparator = false
    return formatter.string(from: rounded as NSDecimalNumber) ?? "0.00"
}

private func slipJSON(_ params: BetslipParams) -> String {
    let slip: [String: Any] = [
        "stake": amount(params.stake),
        "selections": params.selections.map { leg in
            [
                "boutId": leg.boutID,
                "fighterId": leg.fighterID,
                "opponentId": leg.opponentID,
                "odds": amount(leg.odds),
                "fighterName": leg.fighterName,
                "opponentName": leg.opponentName,
                "eventName": leg.eventName,
            ]
        },
    ]
    let data = (try? JSONSerialization.data(withJSONObject: slip)) ?? Data("{}".utf8)
    return String(decoding: data, as: UTF8.self)
}
