//
// FighterRootView.swift
// FightDeckFighter
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import Foundation
import SwiftUI

private enum Layout {
    static let heroHeight: CGFloat = 320
    static let heroScrimHeight: CGFloat = 200
}

public struct FighterRootView: View {
    public let params: FighterParams
    public let theme: ThemeTokens

    /// Decoded once here rather than read from a computed property: `body` runs on every
    /// state change, and on Android every recomposition, so a computed decode re-parses the
    /// payload each pass for a value that cannot change.
    private let fighter: Fighter?

    public init(params: FighterParams, theme: ThemeTokens) {
        self.params = params
        self.theme = theme
        self.fighter = Self.decode(params.fighterJSON)
    }

    private static func decode(_ json: String) -> Fighter? {
        guard let data = json.data(using: String.Encoding.utf8) else { return nil }
        return try? JSONDecoder().decode(Fighter.self, from: data)
    }

    public var body: some View {
        Group {
            if let fighter {
                profile(fighter)
            } else {
                loadingState
            }
        }
        .background(theme.background)
    }

    private var loadingState: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func hero(_ fighter: Fighter) -> some View {
        portraitImage
            .frame(height: Layout.heroHeight)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                heroCaption(fighter)
            }
    }

    private func heroCaption(_ fighter: Fighter) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(fighter.name)
                .font(heroNameFont)
                .foregroundStyle(theme.textPrimary)
            if let nickname = fighter.nickname {
                Text("“\(nickname)”")
                    .font(heroNicknameFont)
                    .foregroundStyle(theme.textSecondary)
            }
            Text(fighter.recordDisplay)
                .font(heroRecordFont)
                .foregroundStyle(theme.accent)
        }
        .padding(theme.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Layout.heroScrimHeight)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var portraitImage: some View {
        if let url = portraitURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    portraitPlaceholder
                }
            }
        } else {
            portraitPlaceholder
        }
    }

    private var portraitURL: URL? {
        params.portraitURL.isEmpty ? nil : URL(string: params.portraitURL)
    }

    private var portraitPlaceholder: some View {
        Rectangle().fill(theme.surface)
    }

    /// Both sections are lists of label/value pairs whose length depends on what the dataset
    /// carries, so both are built as data and rendered once. Deciding which row is last from
    /// the list beats spelling the condition out at each row and getting it wrong when one
    /// more becomes optional.
    private struct DetailRow: Identifiable, Sendable {
        let label: String
        let value: String

        var id: String { label }
    }

    private func profileRows(for fighter: Fighter) -> [DetailRow] {
        var rows = [
            DetailRow(label: "Record", value: fighter.recordDisplay),
            DetailRow(label: "Wins", value: "\(fighter.record.wins)"),
            DetailRow(label: "Losses", value: "\(fighter.record.losses)"),
        ]
        if fighter.record.noContests > 0 {
            rows.append(DetailRow(label: "No contests", value: "\(fighter.record.noContests)"))
        }
        return rows
    }

    private func physicalRows(for fighter: Fighter) -> [DetailRow] {
        var rows: [DetailRow] = []
        if let height = fighter.heightCm {
            rows.append(DetailRow(label: "Height", value: "\(height) cm"))
        }
        if let reach = fighter.reachIn {
            rows.append(DetailRow(label: "Reach", value: "\(reach) in"))
        }
        if let stance = fighter.stance {
            rows.append(DetailRow(label: "Stance", value: displayStance(stance)))
        }
        if let country = fighter.country {
            rows.append(DetailRow(label: "Country", value: country))
        }
        return rows
    }
}

// MARK: - Skip (Android)

#if SKIP
extension FighterRootView {
    fileprivate var heroNameFont: Font {
        Typography.bold(theme.fontDisplay)
    }

    fileprivate var heroNicknameFont: Font {
        Typography.body(theme.fontTitle)
    }

    fileprivate var heroRecordFont: Font {
        Typography.medium(theme.fontCaption)
    }

    fileprivate func displayStance(_ stance: String) -> String {
        guard let first = stance.first else { return stance }
        return String(first).uppercased() + stance.dropFirst()
    }

    fileprivate func profile(_ fighter: Fighter) -> some View {
        ScrollView {
            VStack(spacing: theme.spacingLG) {
                hero(fighter)
                profileSection(fighter)
                if !physicalRows(for: fighter).isEmpty {
                    physicalsSection(fighter)
                }
            }
            .padding(theme.spacingLG)
        }
    }

    private func profileSection(_ fighter: Fighter) -> some View {
        detailSection(title: "Profile", rows: profileRows(for: fighter))
    }

    private func physicalsSection(_ fighter: Fighter) -> some View {
        detailSection(title: "Physicals", rows: physicalRows(for: fighter))
    }

    private func detailSection(title: String, rows: [DetailRow]) -> some View {
        GroupedSection(theme: theme, title: title) {
            ForEach(0 ..< rows.count, id: \.self) { index in
                GroupedRow(theme: theme, isLast: index == rows.count - 1) {
                    GroupedLabeledRow(
                        theme: theme,
                        label: rows[index].label,
                        value: rows[index].value,
                        valueStyle: theme.textSecondary
                    )
                }
            }
        }
    }
}
#endif

// MARK: - Native (iOS)

#if !SKIP
extension FighterRootView {
    fileprivate var heroNameFont: Font {
        .largeTitle.bold()
    }

    fileprivate var heroNicknameFont: Font {
        .title3
    }

    fileprivate var heroRecordFont: Font {
        .subheadline.weight(.medium)
    }

    fileprivate func displayStance(_ stance: String) -> String {
        stance.localizedCapitalized
    }

    fileprivate func profile(_ fighter: Fighter) -> some View {
        List {
            Section {
                hero(fighter)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section("Profile") {
                ForEach(profileRows(for: fighter)) { row in
                    LabeledContent(row.label, value: row.value)
                }
            }
            if !physicalRows(for: fighter).isEmpty {
                Section("Physicals") {
                    ForEach(physicalRows(for: fighter)) { row in
                        LabeledContent(row.label, value: row.value)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
#endif
