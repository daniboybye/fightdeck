//
// EventsViews.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

struct EventsTabView: View {
    @Bindable var state: AppState
    @Binding var path: [EventsRoute]
    let mode: EventMode

    @Namespace private var posterNamespace

    var body: some View {
        NavigationStack(path: $path) {
            LoadStateView(state: state.eventsState, retry: { Task { await state.loadEvents() } }) { events in
                List {
                    Section {
                        ForEach(events) { event in
                            NavigationLink(value: EventsRoute.event(event.id)) {
                                EventRow(event: event, posterURL: posterURL(for: event), mode: mode)
                            }
                        }
                    }
                    if mode.showsResults {
                        newsSection(events: events)
                        videoSection(events: events)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await state.refreshAll() }
            } empty: {
                ContentUnavailableView("No events", systemImage: "calendar")
            }
            .navigationTitle(mode.title)
            .balanceToolbar(state: state)
            .navigationDestination(for: EventsRoute.self) { route in
                destination(for: route, events: eventsOrEmpty)
                    .balanceToolbar(state: state)
            }
        }
    }

    /// Every article carries its event, and the feed mixes both cards, so the row has to say
    /// which event it belongs to — otherwise the list reads as unrelated stories.
    @ViewBuilder
    private func newsSection(events: [EventItem]) -> some View {
        if case .loaded(let items) = state.newsState, !items.isEmpty {
            Section("News") {
                ForEach(items) { item in
                    NavigationLink(value: EventsRoute.article(item.id)) {
                        NewsRow(
                            item: item,
                            eventName: events.first { $0.id == item.eventId }?.name ?? "",
                            imageURL: state.imageURL(item.heroImage)
                        )
                    }
                }
            }
        }
    }

    /// Clips also hang off their event, but nobody opens an event card looking for the press
    /// conference, so the feed carries them next to the news.
    @ViewBuilder
    private func videoSection(events: [EventItem]) -> some View {
        if case .loaded(let clips) = state.mediaState, !clips.isEmpty {
            Section("Video") {
                ForEach(clips) { clip in
                    NavigationLink(value: EventsRoute.video(clip.id)) {
                        VideoRow(
                            item: clip,
                            eventName: events.first { $0.id == clip.eventId }?.name ?? "",
                            posterURL: state.imageURL(clip.poster)
                        )
                    }
                }
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
                EventDetailView(state: state, event: event, mode: mode)
            }
        case .bout(let eventID, let boutID):
            if let event = events.first(where: { $0.id == eventID }),
               let bout = event.bouts.first(where: { $0.id == boutID }) {
                BoutDetailView(state: state, event: event, bout: bout, path: $path, mode: mode)
            }
        case .fighter(let id):
            FighterBridgeView(state: state, fighterID: id)
                .navigationTransition(.zoom(sourceID: id, in: posterNamespace))
        case .article(let id):
            if case .loaded(let items) = state.newsState,
               let item = items.first(where: { $0.id == id }) {
                NewsArticleView(state: state, item: item, imageURL: state.imageURL(item.heroImage))
            }
        case .video(let id):
            if case .loaded(let media) = state.mediaState,
               let item = media.first(where: { $0.id == id }) {
                VideoScreenView(item: item, posterURL: state.imageURL(item.poster))
            }
        }
    }

    private func posterURL(for event: EventItem) -> URL? {
        state.imageURL("assets/events/\(event.id).jpg")
    }
}

private struct EventRow: View {
    let event: EventItem
    let posterURL: URL?
    let mode: EventMode

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            RemoteImageTile(url: posterURL)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(event.name)
                    .font(.headline)
                Text("\(event.venue) · \(event.city)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(event.date.formattedEventDate)
                    Text("·")
                    Text("^[\(event.bouts.count) fight](inflect: true)")
                    Spacer()
                    statusBadge
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private var statusBadge: some View {
        let title = mode.showsResults ? "FINISHED" : "OPEN"
        let tint = mode.showsResults ? DesignTokens.ColorToken.positive : DesignTokens.ColorToken.accent
        return Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(tint.opacity(0.15), in: .capsule)
    }
}

struct EventDetailView: View {
    @Bindable var state: AppState
    let event: EventItem
    let mode: EventMode

    var body: some View {
        List {
            ForEach(segmentOrder, id: \.self) { segment in
                if let bouts = grouped[segment], !bouts.isEmpty {
                    Section(segmentTitle(segment)) {
                        ForEach(bouts) { bout in
                            NavigationLink(value: EventsRoute.bout(eventID: event.id, boutID: bout.id)) {
                                BoutRowView(state: state, bout: bout, mode: mode)
                            }
                        }
                    }
                }
            }
            if mode.showsResults {
                mediaSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var mediaSection: some View {
        if case .loaded(let media) = state.mediaState {
            let clips = media.filter { $0.eventId == event.id }
            if !clips.isEmpty {
                Section("Video") {
                    ForEach(clips) { clip in
                        NavigationLink(value: EventsRoute.video(clip.id)) {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(clip.title)
                                    Text(clip.durationSeconds.formattedDuration)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "play.circle.fill")
                                    .foregroundStyle(DesignTokens.ColorToken.accent)
                            }
                        }
                    }
                }
            }
        }
    }

    private var grouped: [String: [BoutItem]] {
        Dictionary(grouping: event.bouts.sorted { $0.order < $1.order }, by: \.segment)
    }

    private var segmentOrder: [String] {
        ["main", "main_card", "prelim", "prelims", "early_prelim", "early_prelims"]
    }

    private func segmentTitle(_ segment: String) -> String {
        switch segment {
        case "main": "Main Event"
        case "main_card": "Main Card"
        case "prelim", "prelims": "Prelims"
        default: "Early Prelims"
        }
    }
}

struct BoutRowView: View {
    @Bindable var state: AppState
    let bout: BoutItem
    let mode: EventMode

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("\(bout.weightClass.replacingOccurrences(of: "_", with: " ").uppercased())\(bout.titleFight ? " · TITLE" : "") · \(bout.scheduledRounds) RNDS")
                .font(.caption2)
                .foregroundStyle(.secondary)
            cornerRow(bout.redCorner, ring: DesignTokens.ColorToken.cornerRed)
            cornerRow(bout.blueCorner, ring: DesignTokens.ColorToken.cornerBlue)
            if mode.showsResults {
                Label(
                    "\(bout.result.winnerName) · \(bout.result.method.displayMethod) · R\(bout.result.endRound) \(bout.result.endTime)",
                    systemImage: "checkmark.seal.fill"
                )
                .font(.caption)
                .foregroundStyle(DesignTokens.ColorToken.positive)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private func cornerRow(_ corner: CornerItem, ring: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            FighterAvatar(url: state.imageURL("assets/fighters/\(corner.fighterId).jpg"), ring: ring, size: 40)
            VStack(alignment: .leading) {
                Text(corner.name)
                    .font(.callout)
                Text(state.record(for: corner.fighterId))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
}

/// The poster with a play badge, the way Photos and TV present a clip: the thumbnail is the
/// tappable object and the text sits under it.
struct VideoRow: View {
    let item: MediaItem
    let eventName: String
    let posterURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ZStack {
                RemoteImageTile(url: posterURL)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white, .ultraThinMaterial)
                    .shadow(radius: 8)
            }
            .overlay(alignment: .bottomTrailing) {
                Text(item.durationSeconds.formattedDuration)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(.black.opacity(0.6), in: .capsule)
                    .foregroundStyle(.white)
                    .padding(DesignTokens.Spacing.sm)
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                if !eventName.isEmpty {
                    Text(eventName.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignTokens.ColorToken.accent)
                }
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
}

struct FighterAvatar: View {
    let url: URL?
    let ring: Color
    var size: CGFloat

    var body: some View {
        RemoteImage(url: url)
            .frame(width: size, height: size)
            .clipShape(.circle)
            .overlay(Circle().stroke(ring, lineWidth: 2))
    }
}

struct OddsButton: View {
    let label: String
    let fractional: String
    let isSelected: Bool
    let action: () -> Void

    @State private var showFractional = false

    // A selected leg is the one piece of state on this row worth shouting about, so it gets
    // the filled treatment and everything else stays quiet.
    @ViewBuilder
    var body: some View {
        if isSelected {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private var button: some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(showFractional ? fractional : label)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 64, minHeight: DesignTokens.Layout.minTapTarget)
        }
        .tint(DesignTokens.ColorToken.accent)
        .buttonBorderShape(.roundedRectangle(radius: DesignTokens.Radius.sm))
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isSelected)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                showFractional.toggle()
            }
        )
    }
}
