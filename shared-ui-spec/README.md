# Shared UI spec

**Frozen, like `contract/`.** Five approaches must produce host apps that are visually
indistinguishable, because the mechanism of code sharing is the only variable the
comparison is allowed to have. If two apps also look different, no size or startup
number from either of them means anything.

- [`screens.md`](screens.md) — every screen, in detail
- [`tokens.json`](tokens.json) — colours, spacing, type, motion, in DTCG 2025.10

## Which screen exists where

| Screen | Every approach, both platforms | 00-native iOS only |
| --- | :---: | :---: |
| Event list | ● | |
| Event card | ● | |
| Bout detail | ● | |
| Bet slip | ● | |
| Deposit | ● | |
| Fighter profile | | ● |
| News feed | | ● |
| Video | | ● |

The five-screen core set is what gets measured. The three rich screens exist once, on
iOS, and their job is to make the closing taxonomy concrete — a video screen is
something you would never share, and the argument lands better against a screen the
audience has actually seen than against a hypothetical one.

This is also an honest admission of cost, and it is deliberate. Ten host apps is a lot,
the Android side is the expensive half, and building the rich screens ten times would
buy nothing the comparison needs.

## Rules

1. **Tokens, not literals.** Every colour, spacing step and type size comes from
   `tokens.json`. A hardcoded `#E8B33C` anywhere is a defect. This is the talk's own
   argument applied to its own demo: the shareable unit of a design system across three
   platforms is the token, not the component.
2. **Each platform uses its own toolkit properly.** The spec fixes layout and behaviour,
   not implementation. SwiftUI should look like SwiftUI and Compose like Compose —
   `NavigationStack` and `List` on one side, `NavHost` and `LazyColumn` on the other.
   Emulating one platform's navigation on the other in the name of consistency defeats
   the purpose of a native baseline.
3. **Platform conventions win over pixel identity.** Back gestures, safe areas, haptics,
   scroll physics, Dynamic Type and font scaling follow the platform. Where this spec
   and a platform convention disagree, the convention wins and the spec is wrong.
4. **Money always renders through the core.** No view formats a `Decimal` on its own.
   Five different formatters would eventually disagree, and that disagreement would show
   up on stage rather than in a test.
5. **Every screen has all four states**: loading, loaded, empty, error. The error state
   is reachable in the demo by turning off wifi, and it is expected to be exercised.

## Navigation

A three-tab shell. Tabs are `UITabView` on iOS and `NavigationBar` on Android; each tab
owns its own stack.

```
Events  ──▶ Event card ──▶ Bout detail ──▶ Fighter profile (iOS only)
News    ──▶ Article ──▶ Video (iOS only)
Slip    ──▶ Bet slip ──▶ Deposit
```

The bet slip is also reachable from a persistent bar above the tab bar whenever the slip
is non-empty, showing leg count and potential return. Tapping it pushes the slip.

**Deposit is pushed onto the existing stack**, never presented modally. That matters:
in the SDK approaches the deposit screen is supplied by the SDK as a
`UIViewController` or a Compose entry point, and pushing it onto a stack the host
already owns is the realistic integration and the one that exposes the seams — the
back gesture, the navigation bar, the theme, the safe area. A modal would hide most of
them, which would be convenient and dishonest.
