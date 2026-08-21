//
// EventsViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import FightDeckCore
import SwiftUI

struct EventsTabView: View {
    @Bindable var state: AppState
    @Binding var path: [EventsRoute]
    let mode: EventMode

    var body: some View {
        NavigationStack(path: $path) {
            LoadStateView(state: state.eventsState, retry: { Task { await state.loadEvents() } }) { events in
                ScrollView {
                    LazyVStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(events) { event in
                            EventCardRow(event: event, posterURL: posterURL(for: event), mode: mode)
                                .onTapGesture { path.append(.event(event.id)) }
                        }
                        if mode.showsResults {
                            newsSection
                        }
                    }
                    .padding(DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Layout.tabBarClearance)
                }
                .refreshable { await state.loadEvents() }
            } empty: {
                Text("No events")
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            }
            .navigationTitle(mode.title)
            .navigationDestination(for: EventsRoute.self) { route in
                destination(for: route, events: eventsOrEmpty)
            }
        }
    }

    @ViewBuilder
    private var newsSection: some View {
        if case .loaded(let items) = state.newsState, !items.isEmpty {
            Text("News")
                .font(.system(size: DesignTokens.FontSize.title, weight: .bold))
                .foregroundStyle(DesignTokens.ColorToken.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DesignTokens.Spacing.lg)
            ForEach(items) { item in
                NewsRow(item: item, imageURL: state.imageURL(item.heroImage))
                    .onTapGesture { path.append(.article(item.id)) }
            }
        }
    }

    private var eventsOrEmpty: [EventItem] {
        if case .loaded(let events) = state.eventsState { return events }
        return []
    }

    @ViewBuilder
    private func destination(for route: EventsRoute, events: [EventItem]) -> some View {
        switch route {
        case .event(let id):
            if let event = events.first(where: { $0.id == id }) {
                EventDetailView(state: state, event: event, path: $path, mode: mode)
            }
        case .bout(let eventID, let boutID):
            if let event = events.first(where: { $0.id == eventID }),
               let bout = event.bouts.first(where: { $0.id == boutID }) {
                BoutDetailView(state: state, event: event, bout: bout, path: $path, mode: mode)
            }
        case .fighter(let id):
            FighterProfileView(state: state, fighterID: id)
        case .article(let id):
            if case .loaded(let items) = state.newsState,
               let item = items.first(where: { $0.id == id }) {
                NewsArticleView(state: state, item: item, imageURL: state.imageURL(item.heroImage), path: $path)
            }
        case .video(let id):
            if case .loaded(let media) = state.mediaState,
               let item = media.first(where: { $0.id == id }) {
                VideoScreenView(item: item, posterURL: state.imageURL(item.poster))
            }
        }
    }

    private func posterURL(for event: EventItem) -> URL {
        state.imageURL("assets/events/\(event.id).jpg")
    }
}

private struct EventCardRow: View {
    let event: EventItem
    let posterURL: URL
    let mode: EventMode

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            RemoteImage(url: posterURL)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            Text(event.name)
                .font(.system(size: DesignTokens.FontSize.title, weight: .bold))
                .foregroundStyle(DesignTokens.ColorToken.textPrimary)
            Text("\(event.venue) · \(event.city)")
                .font(.system(size: DesignTokens.FontSize.body))
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            HStack {
                Text(formattedDate(event.date))
                    .font(.system(size: DesignTokens.FontSize.caption))
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                Spacer()
                Text("\(event.bouts.count) fights")
                    .font(.system(size: DesignTokens.FontSize.caption, weight: .medium))
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(DesignTokens.ColorToken.surfaceElevated)
                    .clipShape(Capsule())
                statusBadge
            }
        }
        .cardStyle()
    }

    private var statusBadge: some View {
        let title = mode.showsResults ? "FINISHED" : "OPEN"
        let tint = mode.showsResults ? DesignTokens.ColorToken.positive : DesignTokens.ColorToken.accent
        return Text(title)
            .font(.system(size: DesignTokens.FontSize.caption, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .background(tint.opacity(0.15))
            .clipShape(Capsule())
    }

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: iso + "T12:00:00Z") else { return iso }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct EventDetailView: View {
    @Bindable var state: AppState
    let event: EventItem
    @Binding var path: [EventsRoute]
    let mode: EventMode

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(segmentOrder, id: \.self) { segment in
                    if let bouts = grouped[segment], !bouts.isEmpty {
                        Section {
                            ForEach(bouts) { bout in
                                BoutRowView(state: state, event: event, bout: bout, mode: mode) {
                                    path.append(.bout(eventID: event.id, boutID: bout.id))
                                }
                            }
                        } header: {
                            Text(segmentTitle(segment))
                                .font(.system(size: DesignTokens.FontSize.caption, weight: .semibold))
                                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, DesignTokens.Spacing.md)
                        }
                    }
                }
                if mode.showsResults {
                    mediaSection
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var mediaSection: some View {
        if case .loaded(let media) = state.mediaState {
            let clips = media.filter { $0.eventId == event.id }
            if !clips.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Video")
                        .font(.system(size: DesignTokens.FontSize.callout, weight: .semibold))
                        .foregroundStyle(DesignTokens.ColorToken.textPrimary)
                    ForEach(clips) { clip in
                        Button("Watch: \(clip.title)") {
                            path.append(.video(clip.id))
                        }
                        .foregroundStyle(DesignTokens.ColorToken.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
        }
    }

    private var grouped: [String: [BoutItem]] {
        Dictionary(grouping: event.bouts.sorted { $0.order < $1.order }, by: \.segment)
    }

    private var segmentOrder: [String] {
        ["main", "main_card", "prelims", "early_prelims"]
    }

    private func segmentTitle(_ segment: String) -> String {
        switch segment {
        case "main": "Main Event"
        case "main_card": "Main Card"
        case "prelims": "Prelims"
        default: "Early Prelims"
        }
    }
}

struct BoutRowView: View {
    @Bindable var state: AppState
    let event: EventItem
    let bout: BoutItem
    let mode: EventMode
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            header
            cornerRow(bout.redCorner, ring: DesignTokens.ColorToken.cornerRed)
            cornerRow(bout.blueCorner, ring: DesignTokens.ColorToken.cornerBlue)
            if mode.showsResults {
                resultStrip
            }
        }
        .cardStyle()
        .onTapGesture(perform: onTap)
    }

    private var header: some View {
        HStack {
            Text("\(bout.weightClass.uppercased())\(bout.titleFight ? " · TITLE" : "")")
                .font(.system(size: DesignTokens.FontSize.caption))
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            Spacer()
            Text("\(bout.scheduledRounds) RNDS")
                .font(.system(size: DesignTokens.FontSize.caption))
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
        }
    }

    private func cornerRow(_ corner: CornerItem, ring: Color) -> some View {
        HStack {
            Circle()
                .stroke(ring, lineWidth: 2)
                .frame(width: 40, height: 40)
                .overlay {
                    RemoteImage(url: state.imageURL("assets/fighters/\(corner.fighterId).jpg"))
                        .clipShape(Circle())
                }
            VStack(alignment: .leading) {
                Text(corner.name)
                    .font(.system(size: DesignTokens.FontSize.callout, weight: .medium))
                Text(fighterRecord(corner.fighterId))
                    .font(.system(size: DesignTokens.FontSize.caption))
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            }
            Spacer()
            if mode.showsOdds {
                OddsButton(
                    label: FightCoreDisplay.formatOdds(Money.parse(corner.closingOdds.decimal)),
                    fractional: corner.closingOdds.fractional,
                    isSelected: state.isSelected(boutID: bout.id, fighterID: corner.fighterId)
                ) {
                    state.toggleSelection(bout: bout, fighterID: corner.fighterId, odds: corner.closingOdds.decimal)
                }
            }
        }
    }

    private var resultStrip: some View {
        Text("✓ \(bout.result.winnerName) · \(bout.result.method.uppercased()) · R\(bout.result.endRound) \(bout.result.endTime)")
            .font(.system(size: DesignTokens.FontSize.caption))
            .foregroundStyle(DesignTokens.ColorToken.positive)
    }

    private func fighterRecord(_ id: String) -> String {
        if case .loaded(let fighters) = state.fightersState,
           let fighter = fighters.first(where: { $0.id == id }) {
            return fighter.recordDisplay
        }
        return "—"
    }
}

struct OddsButton: View {
    let label: String
    let fractional: String
    let isSelected: Bool
    let action: () -> Void

    @State private var showFractional = false

    var body: some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(showFractional ? fractional : label)
                .font(.system(size: DesignTokens.FontSize.callout, weight: .semibold))
                .foregroundStyle(isSelected ? DesignTokens.ColorToken.onAccent : DesignTokens.ColorToken.accent)
                .frame(minWidth: 72, minHeight: 44)
                .background(isSelected ? DesignTokens.ColorToken.accent : DesignTokens.ColorToken.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isSelected)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                showFractional.toggle()
            }
        )
    }
}
