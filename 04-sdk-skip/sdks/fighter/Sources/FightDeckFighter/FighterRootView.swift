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

/// One label/value line of the profile. Both sections are lists whose length depends on what
/// the dataset carries, so both are built as data and rendered once. Deciding which row is
/// last from the list beats spelling the condition out at each row and getting it wrong when
/// one more becomes optional.
struct FighterDetailRow: Identifiable, Sendable {
    let label: String
    let value: String

    var id: String { label }
}

#if SKIP
/// Plain casing, not `localizedCapitalized`: the Android build links FoundationEssentials to
/// keep ICU out, and locale-aware casing lives on the other side of that line.
func displayStance(_ stance: String) -> String {
    guard let first = stance.first else { return stance }
    return String(first).uppercased() + stance.dropFirst()
}
#else
func displayStance(_ stance: String) -> String {
    stance.localizedCapitalized
}
#endif

public struct FighterRootView: View {
    public let params: FighterParams
    public let theme: ThemeTokens

    /// Built in the initialiser rather than read from a function inside `body`: `body` runs on
    /// every state change, and on Android on every recomposition, so building the rows there
    /// rebuilds a value that cannot change.
    private let profileRows: [FighterDetailRow]
    private let physicalRows: [FighterDetailRow]

    public init(params: FighterParams, theme: ThemeTokens) {
        self.params = params
        self.theme = theme
        self.profileRows = Self.profileRows(for: params.fighter)
        self.physicalRows = Self.physicalRows(for: params.fighter)
    }

    public var body: some View {
        profile(params.fighter)
            .background(theme.background)
    }

    private func hero(_ fighter: Fighter) -> some View {
        portraitImage
            .frame(height: Layout.heroHeight)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                heroCaption(fighter)
            }
            // Clipped again, outside the overlay: the caption's scrim is taller than the
            // caption, and on Android it spilled past the photo as a dark band behind the
            // first section heading.
            .clipped()
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

    private static func profileRows(for fighter: Fighter) -> [FighterDetailRow] {
        var rows = [
            FighterDetailRow(label: "Record", value: fighter.recordDisplay),
            FighterDetailRow(label: "Wins", value: "\(fighter.record.wins)"),
            FighterDetailRow(label: "Losses", value: "\(fighter.record.losses)"),
        ]
        if fighter.record.noContests > 0 {
            rows.append(FighterDetailRow(label: "No contests", value: "\(fighter.record.noContests)"))
        }
        return rows
    }

    private static func physicalRows(for fighter: Fighter) -> [FighterDetailRow] {
        var rows: [FighterDetailRow] = []
        if let height = fighter.heightCm {
            rows.append(FighterDetailRow(label: "Height", value: "\(height) cm"))
        }
        if let reach = fighter.reachIn {
            rows.append(FighterDetailRow(label: "Reach", value: "\(reach) in"))
        }
        if let stance = fighter.stance {
            rows.append(FighterDetailRow(label: "Stance", value: displayStance(stance)))
        }
        if let country = fighter.country {
            rows.append(FighterDetailRow(label: "Country", value: country))
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

    fileprivate func profile(_ fighter: Fighter) -> some View {
        ScrollView {
            VStack(spacing: theme.spacingLG) {
                hero(fighter)
                profileSection
                if !physicalRows.isEmpty {
                    physicalsSection
                }
            }
            .padding(theme.spacingLG)
        }
    }

    private var profileSection: some View {
        section(title: "Profile", rows: profileRows)
    }

    private var physicalsSection: some View {
        section(title: "Physicals", rows: physicalRows)
    }

    /// Built out of SkipUI's own `VStack`, `ForEach` and modifiers, with the pieces as local
    /// functions returning SkipUI primitives. Neither a container of ours taking `@ViewBuilder`
    /// content nor a `View` struct of ours placed among siblings survives transpilation — see
    /// `GroupedList.swift` for the whole trail.
    private func section(title: String, rows: [FighterDetailRow]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionTitle(title)
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    detailRow(row, isLast: row.id == rows.last?.id)
                }
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLG))
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(Typography.body(theme.fontCallout))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, theme.spacingLG)
    }

    private func detailRow(_ row: FighterDetailRow, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(row.label)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text(row.value)
                    .foregroundStyle(theme.textSecondary)
            }
            .font(Typography.body(theme.fontBody))
            .padding(.horizontal, theme.spacingLG)
            .padding(.vertical, theme.spacingMD)
            if !isLast {
                Rectangle()
                    .fill(theme.textSecondary.opacity(0.25))
                    .frame(height: 1)
                    .padding(.leading, theme.spacingLG)
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

    fileprivate func profile(_ fighter: Fighter) -> some View {
        List {
            Section {
                hero(fighter)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section("Profile") {
                ForEach(profileRows) { row in
                    LabeledContent(row.label, value: row.value)
                }
            }
            if !physicalRows.isEmpty {
                Section("Physicals") {
                    ForEach(physicalRows) { row in
                        LabeledContent(row.label, value: row.value)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
#endif
