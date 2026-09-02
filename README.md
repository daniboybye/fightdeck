# fightdeck

Companion repository for the talk **"Share Code, Keep Your Native iOS & Android UI"**.

Five pairs of iOS and Android apps. Same product, same data, same screens. What differs is
one thing only: **the mechanism used to share code between the two platforms.** Everything
is measured against a baseline that shares nothing at all.

The product is a UFC betting app built on two real, already-finished events, so every odd,
every result and every settlement in the golden fixtures is a fact rather than an invention.

## The question this repo answers

When an app grows, the product starts asking for platform-specific flows and the framework
starts getting in the way. The stable end state is usually neither "everything cross-platform"
nor "everything written twice": the app stays native, platform-specific code stays native,
and individual features arrive as shared SDKs.

That leaves two questions, and this repo exists to answer them with numbers:

1. Which technology goes behind those SDKs so they do not look like a piece of somebody
   else's app?
2. What is the price of each choice?

## Layout

| Path | What it is |
| --- | --- |
| `contract/` | The `FightCore` API and golden fixtures. Frozen before any app was built. |
| `dataset/` | UFC event data, JSON schema, locally hosted assets. |
| `shared-ui-spec/` | Screen-by-screen spec so all five pairs look identical. |
| `00-native/` | Baseline. Zero shared code. SwiftUI and Compose, written twice. |
| `01-core-swift/` | Headless Swift core, cross-compiled for Android via the Swift SDK. |
| `02-core-rust/` | Headless Rust core via UniFFI. |
| `03-sdk-rn/` | UI-bearing SDK: React Native, one Hermes runtime, two surfaces. |
| `04-sdk-skip/` | UI-bearing SDK: Skip, Swift that becomes real Jetpack Compose. |
| `tools/` | Size, build-time, source-count and cold-start measurement scripts. |

Each approach folder holds `ios/`, `android/` and (where relevant) `sdks/`. The
`03-sdk-rn` and `04-sdk-skip` approaches split their `sdks/` into `core/`, `deposit/`
and `betslip/` on purpose: **two features over one runtime is the only way to measure what
the second screen actually costs**, which is the question everyone asks and nobody answers.

## Two ground rules

**Separate host apps, never a switcher.** No single app with a dropdown to swap
implementations. You cannot honestly measure binary size or cold start that way.

**SDKs ship as checksum-pinned binaries, not source.** "The host does not know what is
inside" is rhetoric if the host can read the source. Here the host resolves a `.zip` over
HTTPS against a pinned SHA-256 and has access to nothing else.

## The receipt

The full table with methodology is written to `tools/out/receipt.md` by the `measure`
workflow. It is deliberately not committed, so a stale local run can never be mistaken for
a fresh one.

The three tables below are the headline: what each approach costs to ship, what it costs to
write, and what the *next* feature costs once the first one has paid for the runtime. They
come from a local `tools/ci-local.sh --skip-tests measure` run on Apple silicon, and the
`measure` workflow re-derives every one of them on a clean runner.

### What it costs to ship

| Approach | iOS `.app` | Android arm64 | Total overhead | Clean build (iOS / Android) |
| --- | ---: | ---: | ---: | ---: |
| `00-native` baseline | 1.96 MB | 12.53 MB | — | 0m16s / 0m24s |
| `01-core-swift` † | 1.98 MB | 12.52 MB | +0.01 MB | 0m16s / 0m22s |
| `02-core-rust` | 2.82 MB | 13.07 MB | +1.40 MB | 3m52s / 1m58s |
| `04-sdk-skip` | 3.11 MB | 22.52 MB | +11.14 MB | 0m29s / 4m18s |
| `03-sdk-rn` | 21.21 MB | 24.78 MB | +31.50 MB | 0m57s / 1m16s |

*Total overhead* is the iOS and Android growth added together, against the baseline that
shares nothing. Android figures are per-ABI download size for `arm64-v8a` from the app
bundle, which is what a phone actually pulls — the universal APK is three to four times
larger and nobody downloads it.

† Do not read `01-core-swift`'s near-zero overhead as Swift-on-Android being free. Its
Android app runs a Kotlin stub, so that row prices a Swift core on iOS and a hand-written
reimplementation on Android. See the caveats.

### What it costs to write

| Approach | iOS | Android | Shared | Config | Total | Shared |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `00-native` baseline | 3,150 | 3,168 | 0 | 160 | 6,478 | 0% |
| `01-core-swift` † | 2,457 | 3,261 | 1,012 | 188 | 6,918 | 15% |
| `02-core-rust` | 2,847 | 2,797 | 1,473 | 280 | 7,397 | 20% |
| `04-sdk-skip` | 2,677 | 3,137 | 2,699 | 566 | 9,079 | 30% |
| `03-sdk-rn` | 3,243 | 3,489 | 3,714 | 653 | 11,099 | 33% |

Hand-written lines only, from `python3 tools/count-lines.py`. Generated bindings and
transpiler output are excluded — counting them would credit a code generator for typing.

Read the per-platform columns before the shared one. Every approach that shares logic
takes work *out* of the hosts, except React Native, which is the only one where the
platform-specific code goes **up**: 6,732 lines across the two hosts against the
baseline's 6,318, because embedding a surface, sizing it and feeding it the host's layout
is code that only exists because the SDK is there. A bigger shared column is not the same
as a smaller job.

### The cost of the second feature

| Approach | Runtime alone | + deposit | + bet slip | Second feature |
| --- | ---: | ---: | ---: | ---: |
| `03-sdk-rn` iOS | 21.05 MB | 21.17 MB | 21.21 MB | 40.0 KB |
| `03-sdk-rn` Android | 24.72 MB | 24.76 MB | 24.78 MB | 21.6 KB |
| `04-sdk-skip` iOS | 1.88 MB | 3.10 MB | 3.11 MB | 8.0 KB |
| `04-sdk-skip` Android | 22.42 MB | 22.47 MB | 22.52 MB | 46.5 KB |

Produced by `./tools/measure-second-feature.sh`, which builds each host three times — a
host that only starts the runtime, then one with the deposit screen, then one with both
screens — and subtracts. Only the two UI-bearing SDKs appear: the headless cores ship no
UI, so a second feature there is ordinary application code.

This is the point of the whole repository. React Native's iOS host is 21.05 MB before a
single feature screen exists, and the two screens together add 168 KB — the runtime is
over a hundred times the code it carries. Android tells the same story with different
digits: 24.72 MB standing still, 59 KB for both screens.

Skip splits the bill differently. Its runtime-only iOS host is 1.88 MB, *below* the
1.96 MB native baseline, because a host with no feature screens links no SkipUI. The first
feature pulls the transpiled UI layer in and costs 1.22 MB; the second costs 8 KB. Same
shape as React Native — pay once, then nearly nothing — but the once is fifteen times
smaller on iOS.

React Native's second feature costs more on iOS than on Android for a boring reason: the
iOS bundle ships as Hermes bytecode, which is larger than the minified JavaScript Android
loads, and the bet slip also brings a native pod with it.

### Caveats that belong next to every number

Measurements come from simulator and emulator rather than physical devices, and Android R8
is off everywhere, so Android figures are uniformly inflated. Build times are clean builds
with dependencies already fetched — they include each approach's own SDK step, which is why
Rust pays on iOS (three-target `xcframework`) and Skip pays on Android (transpilation), but
they exclude package downloads, which measure the network rather than the approach. CI has
no dependency cache at all, so its numbers will be higher across the board.

**Swift-on-Android does not build here** — `01-core-swift` runs a Kotlin stub on Android and
says so in the code, which is why its Android column is a native-baseline figure wearing a
shared-core label. All ten implementations pass all five golden fixture suites.

## Getting started

**Full bootstrap (all ten apps on one simulator + one emulator):** follow [`RUNBOOK.md`](RUNBOOK.md).

Clone and open. The two UI-bearing SDKs need nothing built first: Swift Package Manager and
Gradle resolve pinned release artifacts over HTTPS.

`02-core-rust` is the exception. Its UniFFI bindings and native libraries are build output
rather than committed files, so run its packaging script once after cloning:

```bash
cd 02-core-rust/sdks/core && ./build-xcframework.sh && ./build-aar.sh
```

To work on an SDK itself, flip to locally built artifacts:

```bash
export FIGHTDECK_LOCAL_SDK=1
```

Every toolchain version is pinned in [`versions.lock.toml`](versions.lock.toml) and every
CI workflow reads from it.

## CI

Every workflow is `workflow_dispatch` only. Nothing runs on push.

`measure.yml` is the important one: it invokes the others, collects the numbers, and emits
the comparison table as a markdown artifact. Every figure quoted anywhere comes from that
artifact rather than from anybody's memory.

## License

Code is MIT. UFC event names, dates, results and fighter statistics are matters of public
record. No UFC-owned media is redistributed here.
