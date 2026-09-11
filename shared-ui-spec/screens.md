# Screens

Token names below refer to [`tokens.json`](tokens.json). Every screen implements four
states: **loading**, **loaded**, **empty**, **error**.

Standard state treatments, identical everywhere:

- **Loading** — skeleton placeholders matching the loaded layout's shape. Not a spinner:
  a spinner tells you nothing about what is coming, and a skeleton makes the perceived
  first-frame time honest.
- **Empty** — centred icon, one line of `textSecondary`, no call to action.
- **Error** — centred message plus a Retry button using `component.primaryButton`.
  Reachable by turning off wifi, and expected to be tested that way.

---

## 1. Event list

The landing screen of the Events tab.

**Layout.** Vertical scroll of event cards, `spacing.lg` outer padding, `spacing.md`
between cards.

**Event card** — `component.card`:

- Poster image, 16:9, `radius.md`, loaded **from the network** (never bundled). This is
  where Kingfisher, Coil and RN's `Image` are compared, so it must be a real fetch with
  a real cache.
- Event name — `fontSize.title` / `fontWeight.bold` / `textPrimary`
- Venue and city — `fontSize.body` / `textSecondary`
- Date, formatted for the device locale — `fontSize.caption` / `textSecondary`
- Bout count pill, e.g. "7 fights" — `surfaceElevated` background, `radius.full`
- A "FINISHED" badge, since both events are in the past. `positive` text on a tinted
  background.

**Interaction.** Tap pushes the event card screen. Pull to refresh.

**Data.** `dataset/events.json`.

---

## 2. Event card

Every bout on one event, in card order.

**Header.** Poster as a stretchy background, collapsing on scroll. Event name, venue,
date overlaid with a bottom gradient scrim for legibility.

**Segments.** Bouts grouped under sticky headers: Main Event, Main Card, Prelims, Early
Prelims. Segment comes from the bout's `segment` field.

**Bout row** — `component.card`, `spacing.md` internal:

```
┌────────────────────────────────────────────────┐
│ MIDDLEWEIGHT · TITLE                    5 RNDS │
│                                                │
│  ◐  Khamzat Chimaev              ┌──────────┐  │
│     15-0-0                       │   1.20   │  │
│                                  └──────────┘  │
│  ◑  Sean Strickland              ┌──────────┐  │
│     30-7-0                       │   4.75   │  │
│                                  └──────────┘  │
│                                                │
│  ✓ Strickland · Split decision · R5 5:00       │
└────────────────────────────────────────────────┘
```

- Weight class and title flag — `fontSize.caption` / `textSecondary`, uppercase.
  Title bouts show a `accent` "TITLE" tag.
- Scheduled rounds, right aligned, same style.
- Each corner: circular portrait 40pt with a 2pt ring in `cornerRed` / `cornerBlue`,
  name in `fontSize.callout` / `fontWeight.medium`, record in `fontSize.caption` /
  `textSecondary`.
- Odds button — `component.oddsButton`, minimum 44pt tall, showing decimal odds by
  default. Selected state uses `backgroundActive` / `labelActive`.
- Result strip, because both events are finished: winner, method, round and time in
  `fontSize.caption` / `positive`.

**Interaction.**

- Tap a bout row → bout detail
- Tap an odds button → toggles that selection on the slip, with a spring animation and
  a light haptic. Selecting the other corner of the same bout **replaces** the
  selection rather than raising `duplicate_bout`; the error exists for programmatic
  callers, and a UI that lets you build an invalid slip and then scolds you is a bad UI.
- Long-press an odds button → shows the fractional value. This is the odds-notation
  toggle, and it is the cheapest possible demonstration that the conversion lives in
  the shared core.

---

## 3. Bout detail

Tale of the tape plus the market for one bout.

**Hero.** Both portraits side by side, angled toward each other, corner-coloured rings.
Names beneath in `fontSize.headline`. A centred "VS" in `textSecondary`.

**Tale of the tape.** Two-column comparison, one row per attribute, label centred:

| Left | Attribute | Right |
| --- | --- | --- |
| 15-0-0 | RECORD | 30-7-0 |
| 188 cm | HEIGHT | 185 cm |
| 75 in | REACH | 76 in |
| Orthodox | STANCE | Orthodox |
| United Arab Emirates | COUNTRY | United States |

Missing values render as `—`. Several fighters genuinely have no published reach or
stance, and inventing one to fill a gap would put a fake number in a demo whose entire
premise is that the data is real.

**Market.** Both odds buttons, full width, stacked, with implied probability underneath
in `fontSize.caption` / `textSecondary` — computed by the core, never in the view.

**Result panel.** Winner, method, detail, round, time. Winner's name in `positive`.

**Interaction.** Tapping a fighter pushes the profile (iOS only; on Android the name is
not tappable). Odds buttons behave as on the event card.

---

## 4. Bet slip

The screen where the shared core is visible to the naked eye, and the one that must be
identical to the cent across all five approaches.

**Mode switch.** Segmented control at the top: **Single** / **Accumulator**. Switching
recalculates immediately. Accumulator is disabled with an explanatory caption when
fewer than two legs are on the slip.

**Selection rows.** One per leg:

- Fighter name — `fontSize.callout`
- Opponent and event, e.g. "vs Chimaev · UFC 328" — `fontSize.caption` / `textSecondary`
- Captured odds — `accent`, right aligned
- Remove button, 44pt hit target, swipe-to-delete on both platforms

**Stake field.** Numeric keyboard, currency-prefixed, `component.card` background.
Quick-stake chips beneath: €5, €10, €25, €50.

Keyboard avoidance is **required** and is the one behaviour worth getting exactly right,
because the talk spends several minutes on it. iOS: SwiftUI's built-in avoidance.
Android: `Modifier.imePadding()` with `WindowInsets.ime` under edge-to-edge. The field
must remain visible above the keyboard on both, on the current OS, with no third-party
package.

**Summary block** — `surfaceElevated`:

```
Total stake                    €10.00
Combined odds                   36.11        (accumulator only)
Potential return               €361.11
Potential profit               €351.11
```

All four values come from the core. The view formats nothing.

**Validation.** Errors render as `negative` rows beneath the summary, **all of them at
once**, in the contract's order. The place bet button disables while any error stands.

**Settlement.** Because both events are finished, a "Settle" action runs the slip
against the real results and reveals per-leg outcomes: `positive` tick for won,
`negative` cross for lost, `textSecondary` dash for void. The returned amount animates
in. **This is the money shot of the demo** — two phones, side by side, the same
€361.11.

**Cash-out.** When the slip is a partially settled accumulator, a cash-out card appears
with the offer and a confirm button.

**Empty state.** "No selections yet" plus a button back to Events.

---

## 5. Deposit

The screen that is a black box in `03-sdk-rn` and `04-sdk-skip`, and hand-written in
the other three. It must look and behave identically in all five, or the whole
comparison collapses.

**Steps.** A three-step flow inside one sheet:

1. **Amount** — big numeric entry, quick chips (€10, €25, €50, €100), balance shown
   above, minimum €10 and maximum €2,000 enforced with inline validation
2. **Method** — radio list: Card, Bank transfer, Wallet. Each with icon, name and a fee
   note. Card is preselected
3. **Confirm** — summary of amount, method, fee and total, then a primary button

**Result.** Success shows a tick, the new balance and a Done button. Failure shows the
error and a Retry.

**The contract with the host.** The host passes in parameters and receives one result:

```swift
protocol DepositHosting {
    func configure()
    func makeViewController(params: DepositParams,
                            onResult: @escaping (DepositResult) -> Void) -> UIViewController
}
```

```
DepositParams  { accessToken, environment, locale, themeJSON, currentBalance }
DepositResult  = completed(amount) | cancelled | failed(reason)
```

`themeJSON` is `tokens.json` serialised and handed across the boundary. That is not
incidental: it is the "share tokens, not components" argument applied to an entire
screen, and it is why the SDK-supplied deposit screen can match the host's theme
without the SDK importing a single one of the host's types.

**What the host must never do.** It must not import React Native, Skip, or anything the
SDK depends on. It sees `DepositHosting` and nothing else, and it must remain unit
testable with that protocol mocked and no runtime present.

The protocol only earns its keep where an SDK supplies the screen. The approaches that
build the screen in-app — `00-native` and `02-core-rust` on iOS — keep `DepositParams`
and `DepositResult` in a `DepositContract.swift` and present the view directly, since
there is no runtime to hide behind an adapter.

---

## 6. Fighter profile — iOS only

**Hero.** Portrait filling the top third, gradient scrim, name and nickname overlaid.

**Stats grid.** Two columns: record, height, reach, stance, country. Missing values
render as `—`.

**Bouts on these cards.** Compact rows for every bout this fighter appears in, with the
result.

Present only in `00-native/ios`. Exists to make the closing taxonomy concrete.

---

## 7. News feed — iOS only

Vertical list of `news.json` items: hero image, headline (`fontSize.title`), body
excerpt of two lines, relative timestamp and read time. Tapping expands to full text.

Every item is stamped `fightdeck-demo`, and the UI shows that attribution, because
demo-written copy sitting next to real results should say which is which.

---

## 8. Video — iOS only

The screen the talk names as the one you would never share.

**Player.** `AVPlayer` in a `VideoPlayer`, 16:9, poster shown until playback starts.
Source from `media.json` — real HLS.

**What it must demonstrate**, and the reason it is unshareable:

- Picture in Picture
- AirPlay via the system route picker
- Background audio with the correct `AVAudioSession` category
- Now Playing info in Control Center and on the Lock Screen

Every one of these is an iOS system integration with an Android counterpart that is not
merely different in API but different in model — ExoPlayer, `MediaSession`, Cast. A
cross-platform abstraction over this pair either leaks both or serves neither, which is
exactly the point being made.

**Below the player.** Title, event, duration, and a plain-text transcript placeholder.
