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
| `02-core-rust/` | Headless Rust via UniFFI: a `fightcore` kernel plus `fightslip` and `fightevents` feature SDKs, three binaries per platform. |
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
| `01-core-swift` † | 1.98 MB | 36.18 MB | +23.67 MB | 0m16s / 12m28s |
| `02-core-rust` ‡ | 2.89 MB | 13.70 MB | +2.10 MB | 3m34s / 2m00s |
| `04-sdk-skip` | 3.11 MB | 22.52 MB | +11.14 MB | 0m29s / 4m18s |
| `03-sdk-rn` | 21.21 MB | 24.78 MB | +31.50 MB | 0m57s / 1m16s |

*Total overhead* is the iOS and Android growth added together, against the baseline that
shares nothing. Android figures are per-ABI download size for `arm64-v8a` from the app
bundle, which is what a phone actually pulls — the universal APK is three to four times
larger and nobody downloads it.

† `01-core-swift`'s Android figure is what a Swift core actually costs on Android: 273 KB
of logic pulling 68 MB of Swift runtime behind it, of which three fifths is ICU. Its
Android build time is the cross-compile of both ABIs plus jextract binding generation, and
is not comparable to the Gradle-only figures in the other rows — jextract reruns on every
build and cascades a recompile, so this is also the per-change cost, not just the first
one.

‡ `02-core-rust` ships three separate Rust binaries per platform, not one, and its build
column is dominated by Rust packaging rather than by the app: 3m09s of the iOS 3m34s and
1m39s of the Android 2m00s is `cargo` compiling three crates for three Apple targets and
two Android ABIs. The app itself builds in 25 seconds.

### What it costs to write

| Approach | iOS | Android | Shared | Config | Total | Shared |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `00-native` baseline | 3,111 | 3,168 | 0 | 160 | 6,439 | 0% |
| `01-core-swift` | 2,457 | 3,081 | 1,269 | 225 | 7,032 | 18% |
| `02-core-rust` | 2,741 | 2,715 | 2,435 | 397 | 8,288 | 29% |
| `04-sdk-skip` | 2,677 | 3,137 | 2,699 | 566 | 9,079 | 30% |
| `03-sdk-rn` | 3,243 | 3,489 | 3,714 | 665 | 11,111 | 33% |

Hand-written lines only, from `python3 tools/count-lines.py`. Generated bindings and
transpiler output are excluded — counting them would credit a code generator for typing.
The same script reports them separately, next to the hand-written boundary code, because
the ratio between the two is the case for using a generator at all: jextract writes 3,678
lines and leaves 319, UniFFI writes 12,354 and leaves 971.

Read the per-platform columns before the shared one. Every approach that shares logic
takes work *out* of the hosts, except React Native, which is the only one where the
platform-specific code goes **up**: 6,732 lines across the two hosts against the
baseline's 6,279, because embedding a surface, sizing it and feeding it the host's layout
is code that only exists because the SDK is there. A bigger shared column is not the same
as a smaller job.

### The cost of the second feature

| Approach | Runtime alone | + deposit | + bet slip | Second feature |
| --- | ---: | ---: | ---: | ---: |
| `03-sdk-rn` iOS | 19.26 MB | 19.34 MB | 19.36 MB | 20.0 KB |
| `03-sdk-rn` Android | 24.72 MB | 24.76 MB | 24.78 MB | 21.6 KB |
| `04-sdk-skip` iOS | 0.15 MB | 1.37 MB | 1.38 MB | 12.0 KB |
| `04-sdk-skip` Android | 22.42 MB | 22.47 MB | 22.52 MB | 46.5 KB |

Produced by `./tools/measure-second-feature.sh`, which builds three hosts — one that only
starts the runtime, one that also mounts the deposit screen, one that mounts both — and
subtracts. Only the two UI-bearing SDKs appear: the headless cores ship no UI, so a second
feature there is ordinary application code.

On iOS those three hosts are a dedicated measurement harness (`ios/Harness/`), not the demo
app with features switched off. That distinction is the whole reason the demo apps contain
no conditional compilation: a host that has to compile both with and without a feature SDK
needs `#if` around every import and every call site, and placeholder views to stand in for
the screens that are missing. Measuring a separate host instead means the app reads as an
app. It also changes what the numbers mean: none of the three iOS rows is the shipping app,
so the "+ bet slip" column does not match the `.app` sizes in the table above and is not
supposed to. Read the deltas, not the absolute sizes. Android needs none
of this: Kotlin has no preprocessor, so the flavours swap whole source directories, and the
demo app itself is what gets measured.

`02-core-rust` splits along the same axis but below the UI, into three separately built
binaries — a `fightcore` kernel plus `fightslip` and `fightevents` feature SDKs — so the
same question has an answer there too:

| `02-core-rust` | Kernel alone | + `fightslip` | + `fightevents` | Second feature |
| --- | ---: | ---: | ---: | ---: |
| iOS (static, linker-deduped) | 0.60 MB | 0.89 MB | 1.30 MB | 410 KB |
| Android (three `.so`, no dedup) | 437 KB | 1,119 KB | 2,167 KB | 1,048 KB |

Different measurement, so read it on its own: the iOS row links against every exported
entrypoint with `-dead_strip`, the Android row is the `lib/arm64-v8a/` payload in the APK.
The gap between the rows is the finding. On iOS each feature crate statically links the
kernel and the linker keeps one copy, so the second feature costs only its own logic. On
Android each AAR is a real shared object that carries its own kernel and its own Rust
`std`, so the same split costs 2.2 MB instead of 0.7 MB. Splitting a Rust SDK into feature
binaries is close to free on one platform and very much not on the other — which is a
thing you can only find out by shipping more than one.

This is the point of the whole repository. React Native's iOS host is 19.26 MB before a
single feature screen exists, and the two screens together add 100 KB — the runtime is
roughly two hundred times the code it carries. Android tells the same story with different
digits: 24.72 MB standing still, 59 KB for both screens.

Skip splits the bill differently. A host that mounts no feature screen is 0.15 MB, because
it links no SkipUI at all: the transpiled UI layer arrives with the first feature and costs
1.22 MB. The second then costs 12 KB. Same shape as React Native — pay once, then nearly
nothing — but a Skip host carrying one feature is fourteen times smaller than the React
Native equivalent, and it pays nothing at all until a feature needs a UI.

React Native's two platforms now agree on what the second feature costs — 20.0 KB on iOS
against 21.6 KB on Android. Skip does not: 12 KB on iOS against 46.5 KB on Android, where
the feature's Kotlin is transpiled rather than compiled from the same Swift the iOS side
links.

Do not read the iOS kilobyte figures too closely. Every iOS number is the archived `.app`
measured with `du`, so all of them are multiples of 4 KB — a 12 KB delta is three disk
blocks, not a byte count. The Android figures are APK download sizes and are exact.

### Caveats that belong next to every number

Measurements come from simulator and emulator rather than physical devices, and Android R8
is off everywhere, so Android figures are uniformly inflated. Build times are clean builds
with dependencies already fetched — they include each approach's own SDK step, which is why
Rust pays on iOS (three-target `xcframework`) and Skip pays on Android (transpilation), but
they exclude package downloads, which measure the network rather than the approach. CI now
caches those downloads, which brings it closer to this methodology, but it still publishes
only sizes: nothing in the receipt is a duration, so the cache cannot flatter a build time.
Gradle's task-output cache stays off for the same reason — a size on a slide has to come
from a build that actually happened.

**Swift-on-Android needs a second Swift** — `01-core-swift` cross-compiles only on an
open-source toolchain installed beside Xcode's, and its Kotlin calls the result through
JNI bindings generated by `swift-java jextract --mode=jni`. All ten implementations pass
all five golden fixture suites, but not all in the same place: that approach's Android run
is an instrumented test on a device, because a JVM on macOS cannot load an Android `.so`,
so CI's contract workflow gates the cores rather than every host.

## Getting started

**Full bootstrap (all ten apps on one simulator + one emulator):** follow [`RUNBOOK.md`](RUNBOOK.md).

Clone and open. The two UI-bearing SDKs need nothing built first: Swift Package Manager and
Gradle resolve pinned release artifacts over HTTPS.

The two headless cores are the exception: their generated bindings and native libraries are
build output rather than committed files, so each needs one packaging run after cloning.

```bash
cd 02-core-rust/sdks && ./build-apple.sh && ./build-android.sh
```

`01-core-swift` needs this only for Android — the iOS host resolves the package through
SPM, but the Compose host links a cross-compiled `.so` and will not configure without it:

```bash
cd 01-core-swift/sdks/core && swiftly run ./build-aar.sh +6.3.3
```

The `swiftly run … +6.3.3` prefix is load-bearing: Xcode's Swift cannot cross-compile
against the Android SDK even at a matching version number.

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
