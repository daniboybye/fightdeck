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
| `02-core-rust/` | Headless Rust via UniFFI: three namespaces, shipped as three Apple binaries and one aggregate Android `.so`. |
| `03-sdk-rn/` | UI-bearing SDK: React Native, one Hermes runtime, two surfaces. |
| `04-sdk-skip/` | UI-bearing SDK: Skip, Swift that becomes real Jetpack Compose. |
| `tools/` | Size, build-time, source-count and cold-start measurement scripts. |

Each approach folder holds `ios/`, `android/` and (where relevant) `sdks/`. The
`03-sdk-rn` and `04-sdk-skip` approaches split their `sdks/` into `core/`, `deposit/`,
`betslip/` and `fighter/` on purpose: **more than one feature over one runtime is the only
way to measure what the next screen actually costs**, which is the question everyone asks
and nobody answers. Three features rather than two because the first one is not
representative — it absorbs runtime that nothing had touched yet.

## Two ground rules

**Separate host apps, never a switcher.** No single app with a dropdown to swap
implementations. You cannot honestly measure binary size or cold start that way.

**SDK hosts use built artifacts, not a source fallback.** Rust, React Native and Skip hosts
resolve one local `.xcframework` / AAR path. A clean checkout builds those SDK artifacts
before the app; there is no second remote-release configuration to drift.

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

> **The Android column predates R8.** Release builds are minified now; these rows are not.
> Re-measure before quoting them.

† `01-core-swift`'s Android figure is what a Swift core actually costs on Android: 590 KB of
logic across three SDKs, pulling 19.1 MB of Swift runtime behind it. **This row predates the
ICU removal and must be re-measured** — it was taken when the runtime was 65.2 MB per ABI,
three fifths of it `lib_FoundationICU.so`, which arrived because the sources said
`import Foundation`. They now say `FoundationEssentials` on Android and format the digits
themselves; `01-core-swift/README.md` has the before and after. Its
Android build time is the cross-compile of both ABIs plus jextract binding generation, and
is not comparable to the Gradle-only figures in the other rows — jextract reruns on every
build and cascades a recompile, so this is also the per-change cost, not just the first
one.

‡ `02-core-rust` keeps three separate Apple binaries but now ships one aggregate Android
`libfightdeck.so`. This row predates that Android packaging change and must be re-measured;
its original build column was dominated by Rust packaging rather than by the app.

### What it costs to write

| Approach | iOS | Android | Shared | iOS adapter | Android adapter | Generated | Total | Total + adapters |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `00-native` baseline | 1,904 | 2,604 | 0 | 0 | 0 | — | **4,508** | **4,508** |
| `04-sdk-skip` | 1,095 | 1,722 | 1,878 | 18 | 343 | 2,425 | **4,695** | **5,056** |
| `01-core-swift` | 1,429 | 2,284 | 1,254 | 0 | 200 | 3,017 | **4,967** | **5,167** |
| `02-core-rust` | 1,445 | 2,249 | 1,557 | 51 | 58 | 8,304 | **5,251** | **5,360** |
| `03-sdk-rn` | 1,738 | 2,263 | 1,528 | 1,142 | 1,081 | — | **5,529** | **7,752** |

**Measured at `0c0f451`** by `python3 tools/count-significant-lines.py`. To refresh it,
read the commits since that hash rather than the whole tree; `--audit` prints every file
and the column it landed in.

A line counts when something executes or declares. Blank lines, `//` and `/* */` comments
and lines made only of punctuation are dropped — that is about a third of a Swift file, and
it is the third nobody writes twice. Also excluded, because keeping them would compare
different things: tests, manifests (`Package.swift`, `*.gradle.kts`, `Podfile`),
`04-sdk-skip`'s measurement harnesses, and the iOS SDK sources `03-sdk-rn` commits twice —
once for SwiftPM and once for CocoaPods — which are counted once.

*Adapter* means code whose only reason to exist is reaching the shared SDK: it declares
what crosses, adapts types the generator cannot carry, mounts the surface, or reconnects
change notification on the far side. *Generated* is build output — jextract's Java and
Swift, UniFFI's bindings, skipstone's Kotlin. Nobody maintains a line of it, and no line of
it is in the totals.

Three things to read off it. First, **the iOS adapter column is the whole argument.**
`01-core-swift` and `04-sdk-skip` need essentially none — 0 and 18 lines — because the
shared artefact is Swift and the host is Swift, so `EventsViews.swift` just says
`import FightCore`. `03-sdk-rn` needs 1,142, because the shared artefact is JavaScript and
something has to embed a surface, size it and feed it the host's layout.

Second, **every approach does take work out of the hosts.** Against the baseline's 4,508
lines of host code, Skip's two hosts hold 2,817 (−38%), Swift's and Rust's 3,713 and 3,694
(−18%), React Native's 4,001 (−11%). But React Native then adds 2,223 lines of adapter back,
so its hosts end up carrying 6,224 — more than writing both apps natively. A bigger shared
column is not the same as a smaller job.

Third, and this is the one worth saying out loud: **not one approach writes fewer total
lines than the baseline.** Skip is the closest and it is still 4% above; with adapters
counted, 12%. Rust is +16%, React Native +23% and +72%. Sharing code did not reduce how
much code exists here — it moved it, and it cut how many times the betting contract is
implemented from two to one. If the argument for any of these is "less code", this table
does not support it. The arguments that survive are in the next two sections: what a
change costs once it only has to be made once, and what it costs to ship.

The sharpest number in this section is not in the table. `count-lines.py` also counts how
many times each approach implements the same betting contract:

| Approach | Times the contract is implemented |
| --- | --- |
| `00-native` baseline | twice — 449 lines of Swift, 297 of Kotlin |
| `01-core-swift` | twice — 411 shared, 138 more in Kotlin |
| `02-core-rust` | three times — 240 shared, 78 in Swift, 72 in Kotlin |
| `03-sdk-rn` | three times — 378 in TypeScript, plus both hosts in full |
| `04-sdk-skip` | **once** — 581 lines, and nothing else |

Only Skip gets to one, and the reason is narrow enough to be worth saying plainly: its
shared artefact is source in each host's own language, so a host can consume the SDK's own
types. Rust ships a `.so` behind FFI and React Native ships JavaScript, so in both the host
can call shared *behaviour* but cannot hold a shared *type*.

Where that costs you differs, and the adapter columns above say so more precisely than an
earlier version of this section did. React Native pays it in hand-written adapter — 2,223
lines across the two hosts. `02-core-rust` pays almost none in adapter (109 lines), because
UniFFI generates the bindings; it pays 8,304 lines of generated code instead, and pays
again in what the shared code is allowed to be, since every type that crosses has to be
expressible in the FFI.

Holding a shared type is also what lets Skip share the layer above the contract. `04-sdk-skip`
is the only approach where the fight catalogue — reading the dataset, indexing it, and
formatting a result line, an event date or a clip length — exists once, in `sdks/events`.
Every other approach either hand-writes it twice (`00-native`, `03-sdk-rn`) or shares the
parsing but re-declares the types to get them across the boundary (`01-core-swift` pays 197
lines of jextract glue for exactly this, `02-core-rust` 328 lines of UniFFI FFI).

That last row was not free, and it is not an argument that Skip wins. Sharing types means
the host's Kotlin now handles transpiled Swift: `skip.lib.Array` instead of `List`, Swift
`ID` casing, no generated `copy()`, and a core whose formatting reaches for Android's ICU
and so no longer runs in a plain JVM test. Shared code is also written against a narrower
Swift than an iOS-only module would be — a generic `decode<T>` does not transpile, because
Kotlin needs a reified type parameter, and dates have to go through `DateFormatter` rather
than `.formatted(date:time:)`, because Skip's `FormatStyle` covers numbers only.

What it buys is that divergence stops being invisible. A bug in the shared core is a bug in
both apps at once — see `04-sdk-skip/README.md`, where deduplicating the core is what finally
surfaced odds maths that had been wrong on Android all along. Sharing the catalogue did the
same for presentation: the two apps had been title-casing `split_decision` differently, and
the iOS news list showed a relative date the Android one never rendered at all.

### The cost of the next feature

> **Stale — re-measure before quoting.** These rows predate the fighter-profile split, so
> they are missing the third feature entirely; they predate R8, so every Android figure is
> too large; and the Skip Android row disagrees with the most recent measurement on disk by
> more than a factor of two (47.09 MB of runtime, not 22.42 MB). Run
> `./tools/measure-second-feature.sh`, then `./tools/render-receipt.py`.

| Approach | Runtime alone | + deposit | + bet slip | Second feature |
| --- | ---: | ---: | ---: | ---: |
| `03-sdk-rn` iOS | 19.26 MB | 19.34 MB | 19.36 MB | 20.0 KB |
| `03-sdk-rn` Android | 24.72 MB | 24.76 MB | 24.78 MB | 21.6 KB |
| `04-sdk-skip` iOS | 0.15 MB | 1.37 MB | 1.38 MB | 12.0 KB |
| `04-sdk-skip` Android | 22.42 MB | 22.47 MB | 22.52 MB | 46.5 KB |

Produced by `./tools/measure-second-feature.sh`, which builds four hosts — one that only
starts the runtime, then one each as the deposit screen, the bet slip and the fighter
profile are added — and subtracts. Only the two UI-bearing SDKs appear: the headless cores
ship no UI, so a second feature there is ordinary application code.

The first feature is the least useful of the three, because it pays for whatever the runtime
only pulls in once a real screen uses it. The fighter profile is the most useful: it is pure
presentation, so what it adds is about as close as this repository gets to the floor price
of one more screen.

On iOS those four hosts are a dedicated measurement harness (`ios/Harness/`), not the demo
app with features switched off. That distinction is the whole reason the demo apps contain
no conditional compilation: a host that has to compile both with and without a feature SDK
needs `#if` around every import and every call site, and placeholder views to stand in for
the screens that are missing. Measuring a separate host instead means the app reads as an
app. It also changes what the numbers mean: none of the four iOS rows is the shipping app,
so the "+ bet slip" column does not match the `.app` sizes in the table above and is not
supposed to. Read the deltas, not the absolute sizes. Android needs none
of this: Kotlin has no preprocessor, so the flavours swap whole source directories, and the
demo app itself is what gets measured.

`02-core-rust` still splits source and APIs along the same axis below the UI — a `fightcore`
kernel plus `fightslip` and `fightevents` feature SDKs. The Android numbers below document
the previous three-`.so` experiment; current Android releases aggregate all three into one
`libfightdeck.so`, so they no longer expose a per-feature shipping delta:

| `02-core-rust` | Kernel alone | + `fightslip` | + `fightevents` | Second feature |
| --- | ---: | ---: | ---: | ---: |
| iOS (static, linker-deduped) | 0.60 MB | 0.89 MB | 1.30 MB | 410 KB |
| Android (historical: three `.so`) | 437 KB | 1,119 KB | 2,139 KB | 1,020 KB |

Different measurement, so read it on its own: the iOS row links against every exported
entrypoint with `-dead_strip`; the historical Android row measured the three stripped
`lib/arm64-v8a/` payloads. On iOS the linker keeps one copy of overlapping Rust code. The
old Android layout could not deduplicate across independently loaded libraries, which is why
it motivated the aggregate crate. The current arm64 `libfightdeck.so` is 2.08 MB, about 4%
smaller than the old three-file total; the more important trade is that Android updates are
now released as one native unit.

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

### What the shrinker changes

Every Android release build runs R8 with resource shrinking. It did not always, and turning
it on moved the numbers more than the approaches do. Universal APKs from one machine, so
read the ratios rather than the digits — a per-ABI download compresses its dex and drops
three of the four ABIs, so the download saving is smaller than the column below:

| Approach | APK unminified | APK minified | dex unminified | dex minified |
| --- | ---: | ---: | ---: | ---: |
| `00-native` | 46.32 MB | 3.02 MB | 45.65 MB | 2.71 MB |
| `01-core-swift` § | 178.01 MB | 134.76 MB | 45.68 MB | 2.77 MB |
| `02-core-rust` | 52.06 MB | 8.70 MB | 46.08 MB | 3.06 MB |
| `03-sdk-rn` | 105.29 MB | 54.90 MB | 53.03 MB | 3.73 MB |
| `04-sdk-skip` | 67.72 MB | 17.78 MB | 62.23 MB | 12.82 MB |

Four of the five hosts were carrying about 45 MB of dex they never ran — Compose, AndroidX,
Coil, OkHttp, all linked whole. That constant is the same in every column, so it was adding
noise to precisely the comparison this repository exists to make, and drowning the native
payload that actually distinguishes the approaches: before the aggregate `.so` change,
`02-core-rust` shipped 5.23 MB of Rust and was reporting a 52 MB APK. The current
`libfightdeck.so` layout must be re-measured before quoting this row.

§ `01-core-swift`'s two APK columns also predate the ICU removal. The minified universal APK
measures **44.40 MB** now, against the 134.76 MB below, because 46 MB per ABI of Foundation
internationalisation left the build; the dex columns are unaffected, since none of it was
dex. The arm64 download is 7.86 MB.

The one row that does not collapse to about 3 MB of dex is Skip's, and that is the finding.
Transpiled Swift needs 12.82 MB kept, four times any other host, because `Codable` transpiles
into reflection: `container.decode(String::class, forKey: CodingKeys.boutID)` names its type
and its key at runtime, so R8 sees nothing referencing the property being filled. SkipUI
resolves part of the SwiftUI shape reflectively too, which is why its AAR needs
`kotlin-reflect` at all. The approach that shares the most source is the one a shrinker can
see through the least, and it pays about 10 MB for it.

That price was checked rather than assumed. Keeping members but letting R8 delete classes
nothing statically references saves 1.70 MB and leaves an app that loads no data at all: the
events screen shows *Something went wrong* and logcat is empty, because the failed decode
arrives as an ordinary caught error rather than a crash. On this approach a shrinker
misconfiguration is invisible to the build and nearly invisible at runtime.

Nothing else needed persuading. The Rust host keeps the UniFFI bindings and JNA intact —
that FFI is name-based in both directions, so R8 can shrink around it but never through it —
and the Swift host is covered by the `proguard.txt` its own AARs ship. Both also had to name
a class their libraries reference and Android does not have: `jdk.jfr` annotations on
SwiftKit's thread-safety markers, `java.awt` in JNA's desktop bridge.

### Caveats that belong next to every number

Measurements come from simulator and emulator rather than physical devices. Android release
builds now run R8 with resource shrinking, which they did not when the tables above were
filled in, so every Android figure in this file is stale and too large — see [what the
shrinker changes](#what-the-shrinker-changes). Build times are clean builds
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

Binary SDK outputs are gitignored. Build them once after cloning, then build the hosts:

```bash
cd 02-core-rust/sdks && ./build-apple.sh && ./build-android.sh
cd 03-sdk-rn && npm ci --prefix sdks/core && ./sdks/build-apple.sh && ./sdks/build-android.sh
cd 04-sdk-skip/sdks && ./build-apple.sh && ./build-aars.sh
```

`01-core-swift` also needs its Android AARs; its iOS host intentionally remains the direct
SwiftPM source comparison:

```bash
cd 01-core-swift/sdks/core && swiftly run ./build-aar.sh +6.3.3
```

The `swiftly run … +6.3.3` prefix is load-bearing: Xcode's Swift cannot cross-compile
against the Android SDK even at a matching version number.

Every toolchain version is pinned in [`versions.lock.toml`](versions.lock.toml) and every
CI workflow reads from it. Workflows run the same SDK-build scripts before their host build.

## CI

Every workflow is `workflow_dispatch` only. Nothing runs on push.

`measure.yml` is the important one: it invokes the others, collects the numbers, and emits
the comparison table as a markdown artifact. Every figure quoted anywhere comes from that
artifact rather than from anybody's memory.

## License

Code is MIT. UFC event names, dates, results and fighter statistics are matters of public
record. No UFC-owned media is redistributed here.
