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
    public let theme: FighterTheme

    public init(params: FighterParams, theme: FighterTheme) {
        self.params = params
        self.theme = theme
    }

    private var fighter: Fighter? {
        guard let data = params.fighterJSON.data(using: .utf8) else { return nil }
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

    @ViewBuilder
    private func profile(_ fighter: Fighter) -> some View {
        #if SKIP
        skipProfile(fighter)
        #else
        nativeProfile(fighter)
        #endif
    }

    #if SKIP
    private func skipProfile(_ fighter: Fighter) -> some View {
        ScrollView {
            VStack(spacing: theme.spacingLG) {
                hero(fighter)
                skipGroupedSection(title: "Profile") {
                    SkipGroupedRow(theme: theme, isLast: false) {
                        skipDetailRow("Record", fighter.recordDisplay)
                    }
                    SkipGroupedRow(theme: theme, isLast: false) {
                        skipDetailRow("Wins", "\(fighter.record.wins)")
                    }
                    SkipGroupedRow(theme: theme, isLast: fighter.record.noContests <= 0) {
                        skipDetailRow("Losses", "\(fighter.record.losses)")
                    }
                    if fighter.record.noContests > 0 {
                        SkipGroupedRow(theme: theme, isLast: true) {
                            skipDetailRow("No contests", "\(fighter.record.noContests)")
                        }
                    }
                }
                if hasPhysicals(fighter) {
                    skipPhysicalsSection(fighter)
                }
            }
            .padding(theme.spacingLG)
        }
    }

    private func skipPhysicalsSection(_ fighter: Fighter) -> some View {
        skipGroupedSection(title: "Physicals") {
            skipPhysicalRows(fighter)
        }
    }

    @ViewBuilder
    private func skipPhysicalRows(_ fighter: Fighter) -> some View {
        let rows = skipPhysicalRowData(fighter)
        ForEach(0 ..< rows.count, id: \.self) { index in
            SkipGroupedRow(theme: theme, isLast: index == rows.count - 1) {
                skipDetailRow(rows[index].label, rows[index].value)
            }
        }
    }

    private struct PhysicalRow {
        let label: String
        let value: String
    }

    private func skipPhysicalRowData(_ fighter: Fighter) -> [PhysicalRow] {
        var rows: [PhysicalRow] = []
        if let height = fighter.heightCm {
            rows.append(PhysicalRow(label: "Height", value: "\(height) cm"))
        }
        if let reach = fighter.reachIn {
            rows.append(PhysicalRow(label: "Reach", value: "\(reach) in"))
        }
        if let stance = fighter.stance {
            rows.append(PhysicalRow(label: "Stance", value: capitalizeFirst(stance)))
        }
        if let country = fighter.country {
            rows.append(PhysicalRow(label: "Country", value: country))
        }
        return rows
    }

    private func skipGroupedSection<Content: View>(
        title: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            if let title {
                Text(title)
                    .font(Typography.body(theme.fontCallout))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, theme.spacingLG)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLG))
        }
    }

    private struct SkipGroupedRow<Content: View>: View {
        let theme: FighterTheme
        let isLast: Bool
        @ViewBuilder let content: () -> Content

        var body: some View {
            VStack(spacing: 0) {
                content()
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

    private func skipDetailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(theme.textSecondary)
        }
        .font(Typography.body(theme.fontBody))
    }
    #endif

    #if !SKIP
    private func nativeProfile(_ fighter: Fighter) -> some View {
        List {
            Section {
                hero(fighter)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section("Profile") {
                LabeledContent("Record", value: fighter.recordDisplay)
                LabeledContent("Wins", value: "\(fighter.record.wins)")
                LabeledContent("Losses", value: "\(fighter.record.losses)")
                if fighter.record.noContests > 0 {
                    LabeledContent("No contests", value: "\(fighter.record.noContests)")
                }
            }
            if hasPhysicals(fighter) {
                Section("Physicals") {
                    if let height = fighter.heightCm {
                        LabeledContent("Height", value: "\(height) cm")
                    }
                    if let reach = fighter.reachIn {
                        LabeledContent("Reach", value: "\(reach) in")
                    }
                    if let stance = fighter.stance {
                        LabeledContent("Stance", value: stance.localizedCapitalized)
                    }
                    if let country = fighter.country {
                        LabeledContent("Country", value: country)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    #endif

    private func hasPhysicals(_ fighter: Fighter) -> Bool {
        fighter.heightCm != nil
            || fighter.reachIn != nil
            || fighter.stance != nil
            || fighter.country != nil
    }

    private func hero(_ fighter: Fighter) -> some View {
        portraitImage
            .frame(height: Layout.heroHeight)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(fighter.name)
                        #if SKIP
                        .font(Typography.bold(theme.fontDisplay))
                        #else
                        .font(.largeTitle.bold())
                        #endif
                        .foregroundStyle(theme.textPrimary)
                    if let nickname = fighter.nickname {
                        Text("“\(nickname)”")
                            #if SKIP
                            .font(Typography.body(theme.fontTitle))
                            #else
                            .font(.title3)
                            #endif
                            .foregroundStyle(theme.textSecondary)
                    }
                    Text(fighter.recordDisplay)
                        #if SKIP
                        .font(Typography.medium(theme.fontCaption))
                        #else
                        .font(.subheadline.weight(.medium))
                        #endif
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
    }

    @ViewBuilder
    private var portraitImage: some View {
        if let url = URL(string: params.portraitURL), !params.portraitURL.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Rectangle().fill(theme.surface)
                }
            }
        } else {
            Rectangle().fill(theme.surface)
        }
    }

    private func capitalizeFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return String(first).uppercased() + value.dropFirst()
    }
}
