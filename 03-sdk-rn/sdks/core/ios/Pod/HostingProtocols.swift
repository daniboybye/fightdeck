import Foundation
import UIKit

/// Host-visible deposit boundary — no React Native types cross this line.
///
/// Parameters carry data only. The chrome a surface has to clear travels separately, through
/// `FightDeckRuntime.publishLayout(_:for:)`, so a keyboard frame never re-renders the form.
public struct DepositParams: Equatable, Sendable {
    public let themeJSON: String
    public let currentBalance: Decimal

    public init(themeJSON: String, currentBalance: Decimal) {
        self.themeJSON = themeJSON
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

public struct BetslipParams: Equatable, Sendable {
    public let themeJSON: String
    public let balance: Decimal
    public let slipJSON: String
    public let eventsJSON: String
    /// Set by the host, not the surface: a property update restarts the React tree, so state
    /// the SDK kept locally would not survive the very update that announces it.
    public let betPlacedMessage: String

    public init(
        themeJSON: String,
        balance: Decimal,
        slipJSON: String,
        eventsJSON: String,
        betPlacedMessage: String = ""
    ) {
        self.themeJSON = themeJSON
        self.balance = balance
        self.slipJSON = slipJSON
        self.eventsJSON = eventsJSON
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
    public let themeJSON: String
    public let fighterJSON: String
    public let portraitURL: String

    public init(themeJSON: String, fighterJSON: String, portraitURL: String) {
        self.themeJSON = themeJSON
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

/// The host chrome a surface has to clear, in points — `SurfaceLayout` in the TypeScript spec.
public struct SurfaceLayout: Equatable, Sendable {
    public var safeAreaTop: CGFloat
    public var safeAreaBottom: CGFloat
    public var keyboardBottomInset: CGFloat
    public var chromeBackground: String
    public var textInputActive: Bool

    public init(
        safeAreaTop: CGFloat = 0,
        safeAreaBottom: CGFloat = 0,
        keyboardBottomInset: CGFloat = 0,
        chromeBackground: String,
        textInputActive: Bool = false
    ) {
        self.safeAreaTop = safeAreaTop
        self.safeAreaBottom = safeAreaBottom
        self.keyboardBottomInset = keyboardBottomInset
        self.chromeBackground = chromeBackground
        self.textInputActive = textInputActive
    }
}
