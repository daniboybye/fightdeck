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
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Check your connection and try again.")
        } actions: {
            SecondaryActionButton(title: "Retry", action: retry)
        }
    }
}

struct SkeletonListView: View {
    var body: some View {
        List(0..<4, id: \.self) { _ in
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .frame(height: 140)
                Text("Placeholder event name")
                    .font(.headline)
                Text("Placeholder venue and city")
                    .font(.subheadline)
            }
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.insetGrouped)
        .redacted(reason: .placeholder)
    }
}

struct RemoteImage: View {
    let url: URL

    var body: some View {
        KFImage(url)
            .placeholder { Rectangle().fill(.quaternary) }
            .fade(duration: 0.2)
            .resizable()
            .scaledToFill()
    }
}

/// The one action a screen exists for. `.glassProminent` sizes itself around its label and
/// lands near 60pt for a headline title, which reads as a banner; the glass goes on a plain
/// button instead so the capsule is exactly as tall as the tap target and no taller. The
/// label carries the frame so every point of that capsule is inside the button.
struct PrimaryActionButton: View {
    let title: String
    var systemImage: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(.headline)
                .foregroundStyle(isEnabled ? DesignTokens.ColorToken.onAccent : Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.Layout.primaryActionHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular
                .tint(isEnabled ? DesignTokens.ColorToken.accent : nil)
                .interactive(isEnabled),
            in: .capsule
        )
        .disabled(!isEnabled)
    }

    @ViewBuilder
    private var label: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

/// A confirmation or a way out — sized to its label, not to the screen, so it does not read
/// as the primary action of the view it closes.
struct SecondaryActionButton: View {
    let title: String
    var isProminent = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(isProminent ? DesignTokens.ColorToken.onAccent : Color.primary)
                .padding(.horizontal, DesignTokens.Layout.secondaryActionPadding)
                .frame(height: DesignTokens.Layout.secondaryActionHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular
                .tint(isProminent ? DesignTokens.ColorToken.accent : nil)
                .interactive(),
            in: .capsule
        )
    }
}

/// Sits next to the primary action while a number pad is up. The keyboard toolbar placement
/// would draw this on top of the action bar instead of beside it.
struct KeyboardDoneButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Done")
                .font(.headline)
                .foregroundStyle(DesignTokens.ColorToken.accent)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .frame(height: DesignTokens.Layout.primaryActionHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

/// A chip in a row of preset values. Same reason as `PrimaryActionButton` for putting the
/// frame on the label: the capsule has to grow, not just the space around it.
struct PresetChipButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignTokens.ColorToken.accent)
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.Layout.secondaryActionHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

/// Preset chips read as one control broken into parts; the container lets their glass merge
/// at the edges instead of stacking four separate highlights.
struct PresetChipRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassEffectContainer(spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                content()
            }
        }
    }
}

/// A poster or portrait that fills its slot without letting the image push the row wider
/// than the list. `scaledToFill` alone would do exactly that.
struct RemoteImageTile: View {
    let url: URL
    var height: CGFloat

    var body: some View {
        RemoteImage(url: url)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
    }
}
