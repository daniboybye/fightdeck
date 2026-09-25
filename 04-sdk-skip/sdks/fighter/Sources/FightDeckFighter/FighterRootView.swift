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
    @Environment(\.fightDeckTheme) private var theme: ThemeTokens

    /// Built in the initialiser rather than read from a function inside `body`: `body` runs on
    /// every state change, and on Android on every recomposition, so building the rows there
    /// rebuilds a value that cannot change.
    private let profileRows: [FighterDetailRow]
    private let physicalRows: [FighterDetailRow]

    public init(params: FighterParams) {
        self.params = params
        self.profileRows = Self.profileRows(for: params.fighter)
        self.physicalRows = Self.physicalRows(for: params.fighter)
    }

    public var body: some View {
        profile(params.fighter)
            .background(theme.background)
    }

    /// One `List` for both platforms. `Form`, `List` and `Section` are all supported by SkipUI,
    /// so the grouped structure itself is shared and each platform's own list styling draws it —
    /// inset-grouped cards on iOS, a Material list on Android. Only the row's contents differ,
    /// because `LabeledContent` has no SkipUI mapping.
    private func profile(_ fighter: Fighter) -> some View {
        listChrome(List {
            Section {
                heroRow(fighter)
            }
            Section {
                ForEach(profileRows) { row in
                    detailRow(row)
                }
            } header: {
                sectionTitle("Profile")
            }
            if !physicalRows.isEmpty {
                Section {
                    ForEach(physicalRows) { row in
                        detailRow(row)
                    }
                } header: {
                    sectionTitle("Physicals")
                }
            }
        })
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

    /// A section header, through a function — never `Text(…)` carrying a modifier of *ours* at
    /// the call site. A `View` extension of our own transpiles to a Kotlin extension function
    /// that `skipstone` does not recognise as producing a view: it emits the call with no
    /// `.Compose(context)` after it and the header silently renders nothing. That is attempt (2)
    /// in `GroupedList.swift`, reached by a different road. A plain function call is composed.
    ///
    /// The font is the whole of the Android fix — see `Typography.sectionHeader`. iOS gets a
    /// bare `Text` and therefore exactly the header SwiftUI drew before.
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
        #if SKIP
            .font(Typography.sectionHeader(theme))
        #endif
    }

    /// Identical on both platforms, so it is not behind an `#if`. It used to be, from when a
    /// shared view of ours was thought not to render on Android.
    private func detailRow(_ row: FighterDetailRow) -> some View {
        LabeledRow(theme: theme, label: row.label, value: row.value, valueStyle: theme.textSecondary)
    }

    /// The photo *is* the row, so a row background behind it draws a card frame around the
    /// picture — both platforms clear it. iOS also zeroes the row's insets so the image runs
    /// edge to edge; `.listRowInsets` has no SkipUI mapping, so Android keeps its own inset.
    private func heroRow(_ fighter: Fighter) -> some View {
        hero(fighter)
            .listRowBackground(Color.clear)
        #if !SKIP
            .listRowInsets(EdgeInsets())
        #endif
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

    /// `.listStyle(.insetGrouped)` and `.listRowInsets` are both unsupported by SkipUI, so the
    /// list keeps Compose's own Material styling — which is the Android-native look anyway.
    /// That styling reads `MaterialTheme.colorScheme`, and the scheme SkipUI installs is not the
    /// host's, so the palette has to be handed in here. See `fightDeckColorScheme`.
    fileprivate func listChrome(_ content: some View) -> some View {
        content
            // Without this the list paints its own container — `surfaceColorAtElevation(3dp)` —
            // over the root's background, on a slightly different shade from the rest of the app.
            .scrollContentBackground(.hidden)
            // The closest a SkipUI list gets to Material cards. `.listStyle(.insetGrouped)` is
            // unavailable and `listSectionCornerRadius` is a constant inside SkipUI, so the
            // slabs cannot be inset or rounded from the row side — but padding the whole list
            // moves them off the screen edges, which is the difference the eye actually reads.
            // The cost is on this screen only: the hero row is inset with everything else,
            // where `00-native` runs it edge to edge. Drop this line to get the photo back.
            .padding(.horizontal, theme.spacingLG)
            .material3ColorScheme { _, _ in fightDeckColorScheme(theme) }
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

    fileprivate func listChrome(_ content: some View) -> some View {
        content.listStyle(.insetGrouped)
    }

}
#endif
