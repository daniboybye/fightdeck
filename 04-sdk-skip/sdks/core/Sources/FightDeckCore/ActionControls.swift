//
// ActionControls.swift
// FightDeckCore
//
// Created by FightDeck on 25.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import SwiftUI

// The controls the SDK screens share, and the one place their platform branches live. Liquid
// Glass is iOS's and a filled capsule is Material's, so each control is written twice — here,
// once — and the screens that use it are written once.
//
// Two rules from `GroupedList.swift` shape how a screen reaches these:
//   - a view of ours goes through a function in the screen (`primaryButton(…)` returning
//     `PrimaryActionButton(…)`), never as a bare initialiser inside a `@ViewBuilder`;
//   - what wraps a screen's content is a `ViewModifier` applied with `.modifier(…)`, never a
//     `View` extension of ours, which skipstone does not compose.

/// The full-width capsule a pinned bar leads with: Place bet, Confirm deposit.
///
/// Disabled, iOS drops the glass tint and greys the label; Android dims the fill and the label
/// to Material's 0.38, the same as `00-native`'s `PrimaryActionButton`. `.disabled()` alone would
/// change nothing on Android, because the fill is ours and SkipUI has no reason to touch it.
///
/// The symbol is iOS's only: SkipUI has no Material icon for most SF Symbols and draws a warning
/// triangle announced as "missing icon" instead (README #15).
public struct PrimaryActionButton: View {
    let title: String
    let systemImage: String?
    let isEnabled: Bool
    let theme: ThemeTokens
    let action: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        theme: ThemeTokens,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.theme = theme
        self.action = action
    }

    public var body: some View {
        #if SKIP
        Button(action: action) {
            Text(title)
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(isEnabled ? theme.onAccent : theme.onAccent.opacity(Metrics.disabledOpacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Metrics.primaryActionHeight)
        .background(isEnabled ? theme.accent : theme.accent.opacity(Metrics.disabledOpacity))
        .clipShape(Capsule())
        .disabled(!isEnabled)
        #else
        Button(action: action) {
            label
                .font(.headline)
                .foregroundStyle(isEnabled ? theme.onAccent : Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.primaryActionHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular
                .tint(isEnabled ? theme.accent : nil)
                .interactive(isEnabled),
            in: .capsule
        )
        .disabled(!isEnabled)
        #endif
    }

    #if !SKIP
    @ViewBuilder
    private var label: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
    #endif
}

/// A capsule that hugs its label: Browse Events, and Done on a confirmation.
public struct SecondaryActionButton: View {
    let title: String
    let theme: ThemeTokens
    let action: () -> Void

    public init(_ title: String, theme: ThemeTokens, action: @escaping () -> Void) {
        self.title = title
        self.theme = theme
        self.action = action
    }

    public var body: some View {
        #if SKIP
        Button(action: action) {
            Text(title)
                .font(Typography.semibold(theme.fontCallout))
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, Metrics.secondaryActionPadding)
                .frame(maxHeight: .infinity)
        }
        .frame(height: Metrics.secondaryActionHeight)
        .background(theme.accent)
        .clipShape(Capsule())
        #else
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, Metrics.secondaryActionPadding)
                .frame(height: Metrics.secondaryActionHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(theme.accent).interactive(), in: .capsule)
        #endif
    }
}

/// Done beside the primary button while a field has the keyboard. It sits in the bar rather
/// than on a keyboard toolbar because SkipUI draws `ToolbarItemGroup(placement: .keyboard)`
/// nowhere, and it is the shape the native screens use anyway.
///
/// On Android this is the one place the SDK drops to Compose. Setting `@FocusState` to false
/// clears SkipUI's focus but does not dismiss the IME; only Compose's focus manager does, and
/// reaching it needs a composable scope, which `ComposeView` is the documented way to open under
/// Skip Lite. `FilledTonalButton` is also what `00-native` uses, and it reads
/// `secondaryContainer`/`onSecondaryContainer`, which `FightDeckScreen` points at the palette.
public struct KeyboardDoneButton: View {
    let theme: ThemeTokens
    let action: () -> Void

    public init(theme: ThemeTokens, action: @escaping () -> Void) {
        self.theme = theme
        self.action = action
    }

    public var body: some View {
        #if SKIP
        ComposeView { _ in
            let focusManager = androidx.compose.ui.platform.LocalFocusManager.current
            androidx.compose.material3.FilledTonalButton(
                onClick: {
                    focusManager.clearFocus()
                    action()
                },
                shape: androidx.compose.foundation.shape.RoundedCornerShape(percent: 50)
            ) {
                androidx.compose.material3.Text("Done")
            }
        }
        .frame(height: Metrics.secondaryActionHeight)
        #else
        Button(action: action) {
            Text("Done")
                .font(.headline)
                .foregroundStyle(theme.accent)
                .padding(.horizontal, theme.spacingLG)
                .frame(height: Metrics.primaryActionHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        #endif
    }
}

/// How a pinned bar sits over the content on Android. iOS draws both the same way, because
/// `safeAreaBar` gives the bar its own scroll-edge treatment there.
public enum ActionBarStyle: Sendable {
    /// Floats over the list with nothing behind it (the slip, above the host's selections pill).
    case floating
    /// A solid strip the content scrolls under (the deposit form, like its native counterpart).
    case filled
}

/// The primary button and, while a field is focused, Done beside it.
public struct ActionBar: View {
    let title: String
    let systemImage: String?
    let isEnabled: Bool
    let showsDone: Bool
    let style: ActionBarStyle
    let theme: ThemeTokens
    let onPrimary: () -> Void
    let onDone: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        isEnabled: Bool,
        showsDone: Bool,
        style: ActionBarStyle,
        theme: ThemeTokens,
        onPrimary: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.showsDone = showsDone
        self.style = style
        self.theme = theme
        self.onPrimary = onPrimary
        self.onDone = onDone
    }

    public var body: some View {
        #if SKIP
        if style == ActionBarStyle.filled {
            row
                .padding(.horizontal, theme.spacingLG)
                .padding(.top, theme.spacingSM)
                .padding(.bottom, Metrics.actionBarGap)
                .frame(maxWidth: .infinity)
                .background(theme.surface)
        } else {
            row
                .padding(.horizontal, theme.spacingLG)
                .padding(.bottom, Metrics.floatingActionBarGap)
        }
        #else
        row
            .padding(.horizontal, theme.spacingLG)
            .padding(.bottom, Metrics.actionBarGap)
            .animation(.snappy(duration: 0.25), value: showsDone)
        #endif
    }

    private var row: some View {
        HStack(spacing: theme.spacingSM) {
            PrimaryActionButton(
                title,
                systemImage: systemImage,
                isEnabled: isEnabled,
                theme: theme,
                action: onPrimary
            )
            if showsDone {
                doneButton
            }
        }
    }

    private var doneButton: some View {
        KeyboardDoneButton(theme: theme, action: onDone)
        #if !SKIP
            .transition(.move(edge: .trailing).combined(with: .opacity))
        #endif
    }
}

/// Pins an `ActionBar` to the bottom of a scrolling list or form and keeps the last rows
/// reachable above it.
///
/// iOS: `safeAreaBar` does both, and rides above the keyboard for free. `accessoryClearance`
/// is extra room for what the host puts below the screen — the tab bar accessory on the slip.
///
/// Android: `safeAreaBar` is unavailable in SkipUI, so the bar is laid over the content in a
/// `ZStack`, and `contentMargins` — which SkipUI's `List` turns into the `LazyColumn`'s content
/// padding — reserves its height at the end of the scroll. That replaced an empty trailing list
/// row, from when `contentMargins` had no SkipUI mapping.
public struct PinnedActionBar: ViewModifier {
    let bar: ActionBar
    let accessoryClearance: CGFloat?

    public init(_ bar: ActionBar, accessoryClearance: CGFloat? = nil) {
        self.bar = bar
        self.accessoryClearance = accessoryClearance
    }

    public func body(content: Content) -> some View {
        #if SKIP
        ZStack(alignment: .bottom) {
            content
                .contentMargins(.bottom, Metrics.primaryActionHeight + Metrics.floatingActionBarGap, for: .scrollContent)
            bar
        }
        #else
        if let accessoryClearance {
            pinned(content.contentMargins(.bottom, accessoryClearance, for: .scrollContent))
        } else {
            pinned(content)
        }
        #endif
    }

    #if !SKIP
    private func pinned(_ content: some View) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .safeAreaBar(edge: .bottom) { bar }
    }
    #endif
}

/// The grouped look for a `List` or `Form`. iOS gets its inset-grouped cards. SkipUI has no
/// `.insetGrouped`, and its section radius is a constant, so on Android the closest is to hide
/// the list's own container — `surfaceColorAtElevation(3dp)`, a shade off the page — and move
/// the slabs off the screen edges.
public struct InsetGroupedList: ViewModifier {
    let theme: ThemeTokens

    public init(theme: ThemeTokens) {
        self.theme = theme
    }

    public func body(content: Content) -> some View {
        #if SKIP
        content
            .scrollContentBackground(.hidden)
            .padding(.horizontal, theme.spacingLG)
        #elseif os(iOS)
        content.listStyle(.insetGrouped)
        #else
        // macOS builds this package only for the core's fixture tests, and has no inset style.
        content
        #endif
    }
}

/// A section header. Left to itself SkipUI dresses one the way iOS does — small, grey and
/// upper-cased — and the upper-casing only goes away when a font is set (see
/// `Typography.sectionHeader`). iOS gets a bare `Text` and exactly the header SwiftUI draws.
public struct SectionHeader: View {
    let title: String
    let theme: ThemeTokens

    public init(_ title: String, theme: ThemeTokens) {
        self.title = title
        self.theme = theme
    }

    public var body: some View {
        Text(title)
        #if SKIP
            .font(Typography.sectionHeader(theme))
        #endif
    }
}

/// A red line under a form or slip that cannot go ahead. Text on Android: the triangle symbol
/// has no Material mapping and would be announced as "missing icon".
public struct ErrorRow: View {
    let message: String
    let theme: ThemeTokens

    public init(_ message: String, theme: ThemeTokens) {
        self.message = message
        self.theme = theme
    }

    public var body: some View {
        #if SKIP
        Text(message)
            .foregroundStyle(theme.negative)
            .font(Typography.body(theme.fontCallout))
            .frame(maxWidth: .infinity, alignment: .leading)
        #else
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(theme.negative)
        #endif
    }
}

/// A list row that is a button, with the whole width as its target.
public struct RowButton: View {
    let title: String
    let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget, alignment: .leading)
            #if !SKIP
                .contentShape(.rect)
            #endif
        }
        #if SKIP
        // Without this the row takes Material's filled-button look instead of a list row.
        .buttonStyle(.plain)
        #endif
    }
}

/// The check that replaces a form once it has gone through. Only the bounce is iOS's: symbol
/// effects have no SkipUI mapping. The circle is one of the symbols SkipUI does map.
public struct ConfirmationIcon: View {
    let size: CGFloat
    let theme: ThemeTokens

    public init(size: CGFloat, theme: ThemeTokens) {
        self.size = size
        self.theme = theme
    }

    public var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(Typography.body(size))
            .foregroundStyle(theme.positive)
        #if !SKIP
            .symbolEffect(.bounce, options: .nonRepeating)
        #endif
    }
}

/// How a confirmation arrives in place of the content it replaces: scaled in on iOS. Compose
/// animates its own state changes, so Android needs nothing.
public struct ConfirmationTransition: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        #if SKIP
        content
        #else
        content.transition(.scale(scale: 0.92).combined(with: .opacity))
        #endif
    }
}
