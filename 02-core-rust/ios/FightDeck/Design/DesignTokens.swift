//
// DesignTokens.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import SwiftUI

enum DesignTokens {
    enum ColorToken {
        static let background = Color(hex: "#0B0E14")
        static let surface = Color(hex: "#141922")
        static let surfaceElevated = Color(hex: "#1C2230")
        static let border = Color(hex: "#232A38")
        static let textPrimary = Color(hex: "#F5F7FA")
        static let textSecondary = Color(hex: "#9AA5B8")
        static let accent = Color(hex: "#E8B33C")
        static let onAccent = Color(hex: "#0B0E14")
        static let positive = Color(hex: "#3DD68C")
        static let negative = Color(hex: "#F2545B")
        static let cornerRed = Color(hex: "#D94A4A")
        static let cornerBlue = Color(hex: "#4A7FD9")
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Layout {
        /// Scroll content has to clear the floating tab bar, which otherwise sits on top of
        /// the last row — the Place bet button being the one that matters.
        static let tabBarClearance: CGFloat = 96
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let full: CGFloat = 999
    }

    enum FontSize {
        static let caption: CGFloat = 12
        static let body: CGFloat = 15
        static let callout: CGFloat = 17
        static let title: CGFloat = 22
        static let headline: CGFloat = 28
        static let display: CGFloat = 34
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
