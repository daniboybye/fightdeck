import Foundation
import UIKit

/// Host-visible deposit boundary — no React Native types cross this line. Parameters carry
/// data only: the host sizes the surface to the space its bars and the keyboard leave.
public struct DepositParams: Equatable, Sendable {
    public let currentBalance: Decimal

    public init(currentBalance: Decimal) {
        self.currentBalance = currentBalance
    }
}

public enum DepositResult: Sendable {
    case confirmed
    case completed(amount: Decimal)
}

@MainActor
public protocol DepositHosting: AnyObject {
    func makeViewController(
        params: DepositParams,
        onResult: @escaping @Sendable (DepositResult) -> Void
    ) -> UIViewController
    func update(params: DepositParams)
}

/// One leg of the slip, with enough of its bout for the screen to name it and check it.
public struct BetslipSelection: Equatable, Sendable {
    public let boutID: String
    public let fighterID: String
    public let opponentID: String
    public let odds: Decimal
    public let fighterName: String
    public let opponentName: String
    public let eventName: String

    public init(
        boutID: String,
        fighterID: String,
        opponentID: String,
        odds: Decimal,
        fighterName: String,
        opponentName: String,
        eventName: String
    ) {
        self.boutID = boutID
        self.fighterID = fighterID
        self.opponentID = opponentID
        self.odds = odds
        self.fighterName = fighterName
        self.opponentName = opponentName
        self.eventName = eventName
    }
}

/// Values, not JSON: the adapter compares them structurally and encodes only what it pushes,
/// so a host no longer has to spell the same slip identically every time to avoid a re-render.
public struct BetslipParams: Equatable, Sendable {
    public let balance: Decimal
    public let stake: Decimal
    public let selections: [BetslipSelection]
    /// Set by the host, not the surface: a new presentation starts the React tree afresh, so
    /// a confirmation the SDK kept locally would not outlive it.
    public let betPlacedMessage: String

    public init(
        balance: Decimal,
        stake: Decimal,
        selections: [BetslipSelection],
        betPlacedMessage: String = ""
    ) {
        self.balance = balance
        self.stake = stake
        self.selections = selections
        self.betPlacedMessage = betPlacedMessage
    }
}

public enum BetslipResult: Sendable {
    case updated(slipJSON: String)
    case browseEvents
    case deposit
    case placed(message: String, slipJSON: String, balance: String)
}

@MainActor
public protocol BetslipHosting: AnyObject {
    func makeViewController(
        params: BetslipParams,
        onResult: @escaping @Sendable (BetslipResult) -> Void
    ) -> UIViewController
    func update(params: BetslipParams)
}

public struct FighterParams: Equatable, Sendable {
    public let fighterJSON: String
    public let portraitURL: String

    public init(fighterJSON: String, portraitURL: String) {
        self.fighterJSON = fighterJSON
        self.portraitURL = portraitURL
    }
}

/// The fighter profile reports nothing back: the spec declares no fighter methods, so there is
/// no result type to hand the host.
@MainActor
public protocol FighterHosting: AnyObject {
    func makeViewController(params: FighterParams) -> UIViewController
    func update(params: FighterParams)
}
