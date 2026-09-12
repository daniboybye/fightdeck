import Foundation
import UIKit

/// Host-visible deposit boundary — no React Native types cross this line.
public struct DepositParams: Sendable {
    public let themeJSON: String
    public let currentBalance: Decimal
    public let safeAreaTop: CGFloat
    public let safeAreaBottom: CGFloat
    public let keyboardBottomInset: CGFloat
    public let chromeBackground: String
    public let textInputActive: Bool
    public let layoutStamp: Double

    public init(
        themeJSON: String,
        currentBalance: Decimal,
        safeAreaTop: CGFloat = 0,
        safeAreaBottom: CGFloat = 0,
        keyboardBottomInset: CGFloat = 0,
        chromeBackground: String = "#0B0E14",
        textInputActive: Bool = false,
        layoutStamp: Double = 0
    ) {
        self.themeJSON = themeJSON
        self.currentBalance = currentBalance
        self.safeAreaTop = safeAreaTop
        self.safeAreaBottom = safeAreaBottom
        self.keyboardBottomInset = keyboardBottomInset
        self.chromeBackground = chromeBackground
        self.textInputActive = textInputActive
        self.layoutStamp = layoutStamp
    }
}

public enum DepositResult: Sendable {
    case confirmed
    case completed(amount: Decimal)
    case cancelled
    case failed(reason: String)
}

@MainActor
public protocol DepositHosting: AnyObject {
    func configure()
    func makeViewController(
        params: DepositParams,
        onResult: @escaping @Sendable (DepositResult) -> Void
    ) -> UIViewController
    func update(params: DepositParams)
}

public struct BetslipParams: Sendable {
    public let themeJSON: String
    public let balance: Decimal
    public let slipJSON: String
    public let eventsJSON: String
    /// Set by the host, not the surface: a property update restarts the React tree, so state
    /// the SDK kept locally would not survive the very update that announces it.
    public let betPlacedMessage: String
    public let safeAreaTop: CGFloat
    public let safeAreaBottom: CGFloat
    public let keyboardBottomInset: CGFloat
    public let chromeBackground: String
    public let textInputActive: Bool
    public let layoutStamp: Double

    public init(
        themeJSON: String,
        balance: Decimal,
        slipJSON: String,
        eventsJSON: String,
        betPlacedMessage: String = "",
        safeAreaTop: CGFloat = 0,
        safeAreaBottom: CGFloat = 0,
        keyboardBottomInset: CGFloat = 0,
        chromeBackground: String = "#0B0E14",
        textInputActive: Bool = false,
        layoutStamp: Double = 0
    ) {
        self.themeJSON = themeJSON
        self.balance = balance
        self.slipJSON = slipJSON
        self.eventsJSON = eventsJSON
        self.betPlacedMessage = betPlacedMessage
        self.safeAreaTop = safeAreaTop
        self.safeAreaBottom = safeAreaBottom
        self.keyboardBottomInset = keyboardBottomInset
        self.chromeBackground = chromeBackground
        self.textInputActive = textInputActive
        self.layoutStamp = layoutStamp
    }
}

public enum BetslipResult: Sendable {
    case updated(slipJSON: String)
    case browseEvents
    case deposit
    case placed(message: String, slipJSON: String, balance: String)
    case cancelled
}

@MainActor
public protocol BetslipHosting: AnyObject {
    func configure()
    func makeViewController(
        params: BetslipParams,
        onResult: @escaping @Sendable (BetslipResult) -> Void
    ) -> UIViewController
    func update(params: BetslipParams)
}
