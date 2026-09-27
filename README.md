# fightdeck

Companion repository for the talk **"Share Code, Keep Your Native iOS & Android UI"**.

Five pairs of iOS and Android apps. Same product, same data, same screens; the only thing that
differs is **how code is shared between the two platforms**. Everything is measured against a
baseline that shares nothing.

The product is a UFC betting app built on two real, finished events, so every odd, result and
settlement in the golden fixtures is a fact rather than an invention.

## The question

As an app grows, the stable end state is rarely "everything cross-platform" or "everything
written twice". The app stays native, platform-specific code stays native, and individual
features arrive as shared SDKs. That leaves two questions this repo answers with numbers:
which technology goes behind those SDKs, and what does each choice cost?

## Layout

| Path | What it is |
| --- | --- |
| [`contract/`](contract/) | The `FightCore` API and the golden fixtures every implementation passes. |
| [`dataset/`](dataset/) | UFC event data, JSON schema, locally hosted art. |
| [`shared-ui-spec/`](shared-ui-spec/) | Screen-by-screen spec, so all five pairs look the same. |
| [`00-native/`](00-native/) | Baseline. Nothing shared: SwiftUI and Compose, written twice. |
| [`01-core-swift/`](01-core-swift/) | Headless Swift core. Source on iOS; cross-compiled for Android and called through `swift-java`. |
| [`02-core-rust/`](02-core-rust/) | Headless Rust core behind UniFFI: three Apple xcframeworks, one Android `.so`. |
| [`03-sdk-rn/`](03-sdk-rn/) | UI-bearing SDKs on React Native: one Hermes runtime, three feature screens. |
| [`04-sdk-skip/`](04-sdk-skip/) | UI-bearing SDKs on Skip: Swift source on iOS, transpiled to Kotlin and Compose on Android. |
| [`tools/`](tools/) | Size, size-breakdown and line-count scripts, and a local mirror of CI. |

The two UI-bearing approaches split their SDKs into `core` plus `deposit`, `betslip` and
`fighter` on purpose: more than one feature over one runtime is the only way to measure what
the *next* screen costs.

**Separate host apps, never a switcher.** Binary size cannot be measured honestly in one app
that swaps implementations at runtime.

## What it costs to ship

Release builds, arm64, measured at `d3be422` by `tools/ci-local.sh all`.

| Approach | iOS `.app` | Android download | Android install |
| --- | ---: | ---: | ---: |
| `00-native` baseline | 1.96 MB | 1.47 MB | 2.88 MB |
| `01-core-swift` | 1.97 MB | 7.76 MB | 21.75 MB |
| `02-core-rust` | 2.83 MB | 2.17 MB | 4.62 MB |
| `03-sdk-rn` | 23.32 MB | 6.70 MB | 17.00 MB |
| `04-sdk-skip` | 2.07 MB | 4.83 MB | 13.54 MB |

*iOS* is the archived `.app` on disk. *Android download* is what the Play Store sends an arm64
phone (bundletool's split APKs, compressed); *install* is the same files unpacked on the
device. Download is the number users feel; install is what sits in storage.

Most of that is paid once. What an approach adds to the baseline splits into a fixed runtime
and a price per feature:

| | Fixed runtime (iOS / Android) | Each further feature (iOS / Android) |
| --- | --- | --- |
| Swift | 0 / ~6.2 MB | ~0 / ~50 KB |
| Rust | ~0.55 / ~0.4 MB | ~100 / ~100 KB |
| React Native | ~21.2 / ~5.2 MB | 8–84 / 2–41 KB |
| Skip | 0 / ~3.3 MB | 36–80 / 8–32 KB |

Android is download size. For React Native and Skip a feature is a screen, measured by
`tools/measure-second-feature.sh`: it builds a host with only the runtime, then adds the
deposit, bet slip and fighter screens one at a time. The range runs from the first screen,
which also pays for runtime nothing had touched yet, to the last and simplest. For Swift and
Rust a feature is a logic SDK, and the figures are estimates from `tools/size-breakdown.py`:
runtime libraries on one side, the SDKs' own code on the other.

Swift and Skip cost nothing fixed on iOS because the Swift runtime ships with the OS and both
compile their SDKs into the app from source. On Android, Swift brings its own runtime and
Foundation, Skip brings SkipUI and SkipFoundation as Kotlin, and React Native brings Hermes
and React on both platforms.

## What it costs to write

Significant hand-written lines, measured at `d3be422` by `tools/count-significant-lines.py`:

| Approach | iOS host | Android host | Shared | Platform specific | Adapters | Total | Hosts vs baseline | Generated | Config |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `00-native` baseline | 1,903 | 2,589 | — | — | — | **4,492** | — | — | 229 |
| `01-core-swift` | 1,199 | 2,052 | 923 | — | 569 | **4,743** | −28% | 1,152 | 500 |
| `02-core-rust` | 1,208 | 2,058 | 1,548 | — | 64 | **4,878** | −27% | 8,473 | 620 |
| `03-sdk-rn` | 1,405 | 1,960 | 1,433 | — | 733 | **5,531** | −25% | 282 | 1,212 |
| `04-sdk-skip` | 861 | 1,574 | 1,614 | 259 | 216 | **4,524** | −46% | 2,785 | 675 |

A line counts when it executes or declares; blanks, comments and punctuation-only lines are
dropped, and so are tests, manifests and the size-measurement harnesses. *Shared* is code
both platforms run. *Specific* is real code for one platform that lives in shared files;
*adapters* are wrappers that translate a type, theme or runtime handle across the boundary.
*Total* adds all of those up. *Generated* (UniFFI, jextract, skipstone) and *config* (build
scripts and settings) are outside it.

- **Only Skip shares UI, so only Skip empties the hosts** — by 46%. Once adapters are added
  back it is level with writing both apps natively (4,524 against 4,492).
- **Logic shares well, UI less so.** `tools/feature-lines.py` compares the baseline's two
  copies of each feature with Skip's one: the betting core is 32% smaller and the three
  screens 5–45% smaller, but the shared components and design tokens grow, because each
  carries a Liquid Glass branch and a Material one.
- **Rust pays in generated code, React Native in glue.** UniFFI writes 8,473 lines so the
  Rust hosts need only 64 of adapter; React Native needs 733 lines of adapter and the most
  configuration of any approach.

## Caveats

- Sizes come from simulator and emulator builds on one Apple silicon Mac; `measure.yml`
  re-derives them on clean runners.
- `01-core-swift`'s Android contract tests are instrumented tests on a device, because a JVM
  on macOS cannot load an Android `.so`.
- Each approach's README goes further: where the bytes go, what crosses the boundary, and
  the rough edges hit along the way.

## Getting started

[`RUNBOOK.md`](RUNBOOK.md) takes a clean machine to all ten apps on one simulator and one
emulator. Toolchain versions are pinned in [`versions.lock.toml`](versions.lock.toml), which
every workflow reads.

SDK binaries are not committed. Build them once after cloning:

```bash
(cd 01-core-swift/sdks && swiftly run ./build-aars.sh +6.3.3)
(cd 02-core-rust/sdks && ./build-apple.sh && ./build-android.sh)
(cd 03-sdk-rn && npm ci --prefix sdks/core && ./sdks/build-apple.sh && ./sdks/build-android.sh)
(cd 04-sdk-skip/sdks && ./build-aars.sh)
```

The `swiftly run … +6.3.3` prefix matters: Xcode's Swift cannot cross-compile against the
Swift SDK for Android, even at the same version number.

## CI

Every workflow is `workflow_dispatch` only; nothing runs on push. `measure.yml` builds all ten
apps, runs the contract suite and renders the comparison table as an artifact.
`tools/ci-local.sh` runs the same jobs on a Mac without spending Actions minutes.

## License

Code is MIT, see [`LICENSE`](LICENSE). UFC event names, dates, results and fighter statistics
are public record. No UFC-owned media is redistributed here.
