import Foundation

/// The Swift half of the codegen'd `FightDeckRuntimeBridge` module.
///
/// Codegen writes the protocol and the JSI glue from `NativeFightDeckRuntimeBridge.ts`, and
/// `FightDeckRuntimeBridge.mm` forwards each generated method here unchanged; this half only
/// turns them into the host-facing result types. One handler per feature, installed by its
/// adapter when the surface is made.
@objc(FightDeckFeatureResults)
@MainActor
public final class FeatureResults: NSObject {
    public static var deposit: (@Sendable (DepositResult) -> Void)?
    public static var betslip: (@Sendable (BetslipResult) -> Void)?

    @objc public static func depositConfirmed() {
        deposit?(.confirmed)
    }

    @objc public static func depositCompleted(_ amount: String) {
        deposit?(.completed(amount: Decimal(string: amount) ?? 0))
    }

    @objc public static func betslipUpdated(_ slipJSON: String) {
        betslip?(.updated(slipJSON: slipJSON))
    }

    @objc public static func betslipBrowseEvents() {
        betslip?(.browseEvents)
    }

    @objc public static func betslipDeposit() {
        betslip?(.deposit)
    }

    @objc public static func betslipPlaced(_ message: String, slipJSON: String, balance: String) {
        betslip?(.placed(message: message, slipJSON: slipJSON, balance: balance))
    }
}
