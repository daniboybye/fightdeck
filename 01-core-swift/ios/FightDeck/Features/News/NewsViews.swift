//
// NewsViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import SwiftUI

struct NewsRow: View {
    let item: NewsItem
    let eventName: String
    let imageURL: URL

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            RemoteImageTile(url: imageURL, height: 140)
                .clipShape(.rect(cornerRadius: DesignTokens.Radius.md))
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                if !eventName.isEmpty {
                    Text(eventName.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignTokens.ColorToken.accent)
                }
                Text(item.headline)
                    .font(.headline)
                    .lineLimit(3)
                Text(item.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\(item.publishedAt.formattedRelativeDate) · \(item.readMinutes) min read")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
}

struct NewsArticleView: View {
    @Bindable var state: AppState
    let item: NewsItem
    let imageURL: URL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                RemoteImage(url: imageURL)
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text(item.headline)
                        .font(.title.bold())
                    Text("\(item.publishedAt.formattedRelativeDate) · \(item.readMinutes) min read · \(item.source)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.body)
                        .font(.body)
                    relatedVideo
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var relatedVideo: some View {
        if case .loaded(let media) = state.mediaState {
            let clips = media.filter { $0.eventId == item.eventId }
            if !clips.isEmpty {
                Divider()
                Text("Watch")
                    .font(.headline)
                ForEach(clips) { clip in
                    NavigationLink(value: EventsRoute.video(clip.id)) {
                        Label(clip.title, systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }
}
