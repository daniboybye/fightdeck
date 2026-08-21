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
| `tools/` | Size and cold-start measurement scripts. |

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
a fresh one. The headline:

| Approach | iOS `.app` | Android arm64 | Cost of the *second* feature |
| --- | --- | --- | --- |
| Native baseline | 1.9 MB | 13.2 MB | — |
| Rust core | 2.6 MB | 13.7 MB | — |
| Skip SDK | 2.7 MB | 16.0 MB | 76 KB iOS / 49 KB Android |
| React Native SDK | 22.6 MB | 22.6 MB | 48 KB iOS / **4.8 KB** Android |

The last column is the point of the whole repository. React Native costs 9.4 MB on Android
to get the runtime in the door, and then 4.8 KB for the next screen — a ratio of roughly
1:2000. The first feature pays for the runtime; the second pays only for itself.

Three caveats that belong next to every number above: measurements are from simulator and
emulator rather than physical devices, Android R8 is off everywhere (so Android figures are
uniformly inflated), and **Swift-on-Android does not build here** — `01-core-swift` runs a
Kotlin stub on Android and says so in the code. All ten implementations pass all five golden
fixture suites.

## Getting started

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
