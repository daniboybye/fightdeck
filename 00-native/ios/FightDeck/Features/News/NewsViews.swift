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
    let imageURL: URL

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            RemoteImage(url: imageURL)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            Text(item.headline)
                .font(.system(size: DesignTokens.FontSize.title, weight: .bold))
                .foregroundStyle(DesignTokens.ColorToken.textPrimary)
                .lineLimit(2)
            Text(item.body)
                .font(.system(size: DesignTokens.FontSize.body))
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                .lineLimit(2)
            HStack {
                Text(relativeDate(item.publishedAt))
                Text("·")
                Text("\(item.readMinutes) min read")
                Spacer()
                Text(item.source)
                    .foregroundStyle(DesignTokens.ColorToken.accent)
            }
            .font(.system(size: DesignTokens.FontSize.caption))
            .foregroundStyle(DesignTokens.ColorToken.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func relativeDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return iso }
        return date.formatted(.relative(presentation: .named))
    }
}

struct NewsArticleView: View {
    @Bindable var state: AppState
    let item: NewsItem
    let imageURL: URL
    @Binding var path: [EventsRoute]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                RemoteImage(url: imageURL)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                Text(item.headline)
                    .font(.system(size: DesignTokens.FontSize.title, weight: .bold))
                Text(item.body)
                    .font(.system(size: DesignTokens.FontSize.body))
                    .foregroundStyle(DesignTokens.ColorToken.textPrimary)
                Text("Source: \(item.source)")
                    .font(.system(size: DesignTokens.FontSize.caption))
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                if case .loaded(let media) = state.mediaState {
                    ForEach(media.filter { $0.eventId == item.eventId }) { video in
                        Button("Watch: \(video.title)") {
                            path.append(.video(video.id))
                        }
                        .foregroundStyle(DesignTokens.ColorToken.accent)
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
    }
}
