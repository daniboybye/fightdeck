//
// MoneyDigits.swift
// FightCore
//
// Created by FightDeck on 15.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

// The price of leaving ICU behind on Android, in full. Everything here exists so that
// Money.swift's Android branch never reaches for NumberFormatter, because the module that
// defines it links libFoundationInternationalization, which links lib_FoundationICU: 38 MB
// per ABI, to print a euro amount in a shape that has no locale in it at all.
//
// Nothing below needs one either. All three of the formatters this replaces are POSIX with
// grouping switched off and a fixed number of fraction digits, which makes them digit
// arithmetic. Decimal.description is the only route to the digits that FoundationEssentials
// offers, and it writes plain notation for every magnitude a betting slip holds.
#if os(Android)
import FoundationEssentials

extension Money {
    /// `value` with exactly `scale` fraction digits, rounded HALF_UP as the contract asks —
    /// ties away from zero, which is what `NSDecimalRound(.plain)` does on the Apple side.
    static func fixedPoint(_ value: Decimal, scale: Int) -> String {
        var (negative, digits) = scaled(value, scale: scale)
        // Zero prints without a sign whichever side of it the input was on.
        if digits.allSatisfy({ $0 == 0 }) { negative = false }

        let point = digits.count - scale
        let integer = digits[..<point]
        let fraction = digits[point...]

        var text = negative ? "-" : ""
        text += string(integer)
        if scale > 0 {
            text += "."
            text += string(fraction)
        }
        return text
    }

    /// The integer part, truncated toward zero, the way `NSDecimalNumber.intValue` is.
    static func truncated(_ value: Decimal) -> Int {
        let text = value.description
        guard let point = text.firstIndex(of: ".") else { return Int(text) ?? 0 }
        return Int(text[..<point]) ?? 0
    }

    /// The exact-odds formatter sets no minimum, so a whole number prints whole.
    static func trimmingZeros(_ text: String) -> String {
        guard text.contains(".") else { return text }
        var trimmed = text
        while trimmed.hasSuffix("0") { trimmed.removeLast() }
        if trimmed.hasSuffix(".") { trimmed.removeLast() }
        return trimmed
    }

    /// `|value|` × 10^`scale`, rounded, as digits from the most significant down. At least
    /// `scale` + 1 of them, so the caller can always split an integer part off the front.
    private static func scaled(_ value: Decimal, scale: Int) -> (negative: Bool, digits: [UInt8]) {
        var text = value.description
        let negative = text.hasPrefix("-")
        if negative { text.removeFirst() }

        let point = text.firstIndex(of: ".")
        let integer = point.map { text[..<$0] } ?? text[...]
        let fraction = point.map { text[text.index(after: $0)...] } ?? ""[...]

        var digits = Array((integer + fraction.prefix(scale)).utf8.map { $0 - UInt8(ascii: "0") })
        // A short fraction is padded out to the scale; a long one gets to decide the
        // rounding with its first dropped digit, since nothing past that can change a
        // HALF_UP result.
        digits.append(contentsOf: repeatElement(0, count: max(0, scale - fraction.count)))
        if fraction.dropFirst(scale).first.map({ $0 >= "5" }) == true {
            increment(&digits)
        }
        if digits.count == scale { digits.insert(0, at: 0) }
        return (negative, digits)
    }

    /// Adds one to a digit array, growing it when the carry runs off the front.
    private static func increment(_ digits: inout [UInt8]) {
        for index in digits.indices.reversed() {
            if digits[index] < 9 {
                digits[index] += 1
                return
            }
            digits[index] = 0
        }
        digits.insert(1, at: 0)
    }

    private static func string(_ digits: ArraySlice<UInt8>) -> String {
        digits.isEmpty ? "0" : String(decoding: digits.map { $0 + UInt8(ascii: "0") }, as: UTF8.self)
    }
}
#endif
