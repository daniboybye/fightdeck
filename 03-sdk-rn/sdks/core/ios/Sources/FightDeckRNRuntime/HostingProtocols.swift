import Foundation
import UIKit

/// Host-visible deposit boundary — no React Native types cross this line.
public struct DepositParams: Sendable {
    public let accessToken: String
    public let environment: String
    public let locale: String
    public let themeJSON: String
    public let currentBalance: Decimal

    public init(
        accessToken: String,
        environment: String,
        locale: String,
        themeJSON: String,
        currentBalance: Decimal
    ) {
        self.accessToken = accessToken
        self.environment = environment
        self.locale = locale
        self.themeJSON = themeJSON
        self.currentBalance = currentBalance
    }
}

public enum DepositResult: Sendable {
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
}

public struct BetslipParams: Sendable {
    public let accessToken: String
    public let environment: String
    public let locale: String
    public let themeJSON: String
    public let balance: Decimal
    public let slipJSON: String
    public let eventsJSON: String

    public init(
        accessToken: String,
        environment: String,
        locale: String,
        themeJSON: String,
        balance: Decimal,
        slipJSON: String,
        eventsJSON: String
    ) {
        self.accessToken = accessToken
        self.environment = environment
        self.locale = locale
        self.themeJSON = themeJSON
        self.balance = balance
        self.slipJSON = slipJSON
        self.eventsJSON = eventsJSON
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
}
