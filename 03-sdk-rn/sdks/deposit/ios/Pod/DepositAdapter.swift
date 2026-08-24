import Foundation
import UIKit
import FightDeckRNRuntime

@MainActor
public final class DepositAdapter: DepositHosting {
    private var configured = false

    public init() {}

    public func configure() {
        guard !configured else { return }
        FightDeckRNRuntime.shared.configure()
        FightDeckRNRuntime.shared.registerFeature("deposit", moduleName: "DepositFeature")
        configured = true
    }

    public func makeViewController(
        params: DepositParams,
        onResult: @escaping @Sendable (DepositResult) -> Void
    ) -> UIViewController {
        configure()
        let properties: [String: Any] = Self.properties(from: params)
        return FightDeckRNRuntime.shared.makeViewController(feature: "deposit", properties: properties) { payload in
            let result = DepositAdapter.mapResult(payload)
            Task { @MainActor in
                onResult(result)
            }
        }
    }

    public func update(params: DepositParams) {
        configure()
        FightDeckRNRuntime.shared.updateProperties(
            feature: "deposit",
            properties: Self.properties(from: params)
        )
    }

    nonisolated private static func properties(from params: DepositParams) -> [String: Any] {
        [
            "accessToken": params.accessToken,
            "environment": params.environment,
            "locale": params.locale,
            "themeJSON": params.themeJSON,
            "currentBalance": NSDecimalNumber(decimal: params.currentBalance).stringValue,
            "safeAreaTop": Double(params.safeAreaTop),
            "safeAreaBottom": Double(params.safeAreaBottom),
            "keyboardBottomInset": Double(params.keyboardBottomInset),
            "chromeBackground": params.chromeBackground,
            "textInputActive": params.textInputActive,
            "layoutStamp": params.layoutStamp,
        ]
    }

    nonisolated private static func mapResult(_ payload: [String: Any]) -> DepositResult {
        switch payload["type"] as? String {
        case "confirmed":
            return .confirmed
        case "completed":
            let amountString = (payload["amount"] as? String)?.replacingOccurrences(of: "€", with: "") ?? "0"
            let amount = Decimal(string: amountString) ?? 0
            return .completed(amount: amount)
        case "failed":
            return .failed(reason: payload["reason"] as? String ?? "unknown")
        default:
            return .cancelled
        }
    }
}
