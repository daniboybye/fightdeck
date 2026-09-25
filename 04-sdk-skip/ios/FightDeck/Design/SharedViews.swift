//
// SharedViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI
import FightDeckEvents
import Kingfisher

struct LoadStateView<Value: Sendable, Content: View, Empty: View>: View {
    let state: CatalogLoad<Value>
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
