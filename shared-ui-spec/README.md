# Shared UI spec

**Frozen, like `contract/`.** Five approaches must produce host apps that are visually
indistinguishable, because the mechanism of code sharing is the only variable the
comparison is allowed to have. If two apps also look different, no size or startup
number from either of them means anything.

- [`screens.md`](screens.md) — every screen, in detail
- [`tokens.json`](tokens.json) — colours, spacing, type, motion, in DTCG 2025.10

## Which screen exists where

| Screen | Measured | Every approach, both platforms |
| --- | :---: | :---: |
| Event list | ● | ● |
| Event card | ● | ● |
| Bout detail | ● | ● |
| Bet slip | ● | ● |
| Deposit | ● | ● |
| Fighter profile | | ● |
| News feed | | ● |
| Video | | ● |

The five-screen core set is what gets measured; every number in `tools/out` comes from
those screens and nothing else. The three rich screens are present everywhere but stay
out of the measurement, and their job is to make the closing taxonomy concrete — a video
screen is something you would never share, and the argument lands better against a screen
the audience has actually seen than against a hypothetical one.

Video is the one to point at on stage. It is a screen both platforms can do and neither
can share: Picture in Picture works in all ten apps, and the iOS and Android halves have
not one line in common. See [§8 of `screens.md`](screens.md) for what each side has to
say to get the same floating window.

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
Events  ──▶ Event card ──▶ Bout detail ──▶ Fighter profile
News    ──▶ Article ──▶ Video
Slip    ──▶ Bet slip
```

The bet slip is also reachable from a persistent bar above the tab bar whenever the slip
is non-empty, showing leg count and potential return. Tapping it switches to the Slip tab.

**Deposit is presented as a sheet** from the balance toolbar on every screen. In the SDK
approaches the deposit UI is supplied by the SDK, but the host still owns presentation:
`sheet(isPresented:)` on iOS and `ModalBottomSheet` on Android. That keeps one entry path
and matches how a real host would integrate a black-box deposit module without pushing
it onto an existing navigation stack.
