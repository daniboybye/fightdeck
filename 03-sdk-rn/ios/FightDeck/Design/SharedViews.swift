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
            Button("Retry", action: retry)
                .buttonStyle(.glassProminent)
                .minimumTapTarget()
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

/// The one action a screen exists for. Full width, `.glassProminent`, and never shorter than
/// the 44pt tap target — a bare `Button` sizes to its label and lands around 34pt.
struct PrimaryActionButton: View {
    let title: String
    var systemImage: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.Layout.primaryActionHeight)
        }
        .buttonStyle(.glassProminent)
        .tint(DesignTokens.ColorToken.accent)
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

/// Sits next to the primary action while a number pad is up. The keyboard toolbar placement
/// would draw this on top of the action bar instead of beside it.
struct KeyboardDoneButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Done")
                .font(.headline)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .frame(minHeight: DesignTokens.Layout.primaryActionHeight)
        }
        .buttonStyle(.glass)
        .tint(DesignTokens.ColorToken.accent)
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
