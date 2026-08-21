//
// SharedViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import SwiftUI
import Kingfisher

struct LoadStateView<Value: Sendable, Content: View, Empty: View>: View {
    let state: LoadState<Value>
    let retry: () -> Void
    @ViewBuilder var content: (Value) -> Content
    @ViewBuilder var empty: () -> Empty

    var body: some View {
        switch state {
        case .loading:
            SkeletonListView()
        case .loaded(let value):
            content(value)
        case .empty:
            empty()
        case .error:
            ErrorStateView(retry: retry)
        }
    }
}

struct ErrorStateView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            Text("Something went wrong")
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            Button("Retry", action: retry)
                .buttonStyle(PrimaryCapsuleButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SkeletonListView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                        .fill(DesignTokens.ColorToken.surface)
                        .frame(height: 180)
                        .redacted(reason: .placeholder)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }
}

struct RemoteImage: View {
    let url: URL

    var body: some View {
        KFImage(url)
            .resizable()
            .scaledToFill()
    }
}

struct PrimaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: DesignTokens.FontSize.callout, weight: .semibold))
            .foregroundStyle(DesignTokens.ColorToken.onAccent)
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(DesignTokens.ColorToken.accent)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignTokens.Spacing.lg)
            .background(DesignTokens.ColorToken.surface)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .stroke(DesignTokens.ColorToken.border)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardBackground())
    }
}

struct BetSlipBar: View {
    let legCount: Int
    let potentialReturn: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("\(legCount) selection\(legCount == 1 ? "" : "s")")
                    .font(.system(size: DesignTokens.FontSize.callout, weight: .medium))
                Spacer()
                Text("Return \(potentialReturn)")
                    .font(.system(size: DesignTokens.FontSize.callout, weight: .bold))
            }
            // Glass over the dark background, not the accent fill, so onAccent would render
            // near-black text on a near-black bar.
            .foregroundStyle(DesignTokens.ColorToken.textPrimary)
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity)
            .glassEffect()
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }
}
