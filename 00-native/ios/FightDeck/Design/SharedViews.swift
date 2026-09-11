//
// SharedViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
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
            .listRowInsets(.init())
        }
        .listStyle(.insetGrouped)
        .redacted(reason: .placeholder)
    }
}

struct RemoteImage: View {
    let url: URL?

    var body: some View {
        if let url {
            KFImage(url)
            .placeholder { Rectangle().fill(.quaternary) }
            .fade(duration: 0.2)
            .resizable()
            .scaledToFill()
        } else {
            Rectangle().fill(.quaternary)
        }
    }
}

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

/// A `GlassEffectContainer` so the chips' glass merges at the edges instead of stacking four
/// separate highlights.
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

struct RemoteImageTile: View {
    let url: URL?
    var aspectRatio: CGFloat = DesignTokens.Layout.mediaTileAspectRatio

    var body: some View {
        if let url {
            KFImage(url)
            .placeholder { Rectangle().fill(.quaternary) }
            .fade(duration: 0.2)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .background(.quaternary)
            .clipShape(.rect(cornerRadius: DesignTokens.Radius.md))
        } else {
            Rectangle().fill(.quaternary)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(.rect(cornerRadius: DesignTokens.Radius.md))
        }
    }
}
