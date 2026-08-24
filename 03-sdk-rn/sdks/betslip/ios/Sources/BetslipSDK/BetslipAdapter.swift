import Foundation
import UIKit
import FightDeckRNRuntime

@MainActor
public final class BetslipAdapter: BetslipHosting {
    private var configured = false

    public init() {}

    public func configure() {
        guard !configured else { return }
        FightDeckRNRuntime.shared.configure()
        FightDeckRNRuntime.shared.registerFeature("betslip", moduleName: "BetslipFeature")
        configured = true
    }

    public func makeViewController(
        params: BetslipParams,
        onResult: @escaping @Sendable (BetslipResult) -> Void
    ) -> UIViewController {
        configure()
        let properties: [String: Any] = Self.properties(from: params)
        return FightDeckRNRuntime.shared.makeViewController(feature: "betslip", properties: properties) { payload in
            let result = BetslipAdapter.mapResult(payload)
            Task { @MainActor in
                onResult(result)
            }
        }
    }

    public func update(params: BetslipParams) {
        configure()
        FightDeckRNRuntime.shared.updateProperties(
            feature: "betslip",
            properties: Self.properties(from: params)
        )
    }

    public func destroy() {
        FightDeckRNRuntime.shared.destroyFeature("betslip")
    }

    nonisolated private static func properties(from params: BetslipParams) -> [String: Any] {
        [
            "accessToken": params.accessToken,
            "environment": params.environment,
            "locale": params.locale,
            "themeJSON": params.themeJSON,
            "balance": NSDecimalNumber(decimal: params.balance).stringValue,
            "slipJSON": params.slipJSON,
            "eventsJSON": params.eventsJSON,
            "betPlacedMessage": params.betPlacedMessage,
            "safeAreaTop": Double(params.safeAreaTop),
            "safeAreaBottom": Double(params.safeAreaBottom),
            "keyboardBottomInset": Double(params.keyboardBottomInset),
            "chromeBackground": params.chromeBackground,
            "textInputActive": params.textInputActive,
            "layoutStamp": params.layoutStamp,
        ]
    }

    nonisolated private static func mapResult(_ payload: [String: Any]) -> BetslipResult {
        switch payload["type"] as? String {
        case "updated":
            return .updated(slipJSON: payload["slipJSON"] as? String ?? "{}")
        case "browse":
            return .browseEvents
        case "deposit":
            return .deposit
        case "placed":
            return .placed(
                message: payload["message"] as? String ?? "",
                slipJSON: payload["slipJSON"] as? String ?? "{}",
                balance: payload["balance"] as? String ?? "0"
            )
        default:
            return .cancelled
        }
    }
}
