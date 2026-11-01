# Findings

The conclusions behind the talk **"Share Code, Keep Your Native iOS & Android UI"**, written
down so they can be read without the slides. The numbers come from this repository and are
explained, with their methodology, in the [README](README.md); the rough edges behind each
conclusion are in each approach's own README.

The point is not to rank technologies or promote one. It is to show a family of options that
is easy to overlook: ways to share code across iOS and Android **while the UI stays SwiftUI
and Jetpack Compose**, and the price each of them asks.

## TL;DR

- **Keep the app native and make the SDK the variable.** Each feature ships as its own SDK;
  the technology behind it stays hidden behind the SDK boundary, so one app can mix them and
  swap one for another.
- **Logic shares well; UI shares less than it promises.** Skip is the only approach here that
  empties the host apps (−46% host code), and once its adapters are counted it is level with
  writing both apps natively.
- **Most of the cost is a runtime you pay once.** After the first feature, the next one is
  cheap in every approach. Pick a technology by its fixed cost and by where its seams show,
  not by the size of the first feature.
- **Every approach moves the cost; none removes it.** C++ pays in hand-written wrappers, Rust
  in generated code, Swift in Android tooling, React Native in runtime size and visible UI
  seams, Skip in the limits of transpilation.

| Approach | Shares | Where the cost lands | One-line verdict |
| --- | --- | --- | --- |
| Rust + UniFFI | Logic | Generated code, API-boundary design | Where I would start a new headless core in 2026 |
| Swift cross-compiled | Logic | Android runtime size, Android tooling | Free on iOS; Android pays for the runtime and the debugger |
| React Native | Logic + UI | Runtime on both platforms, visible toolkit seam | Mature and cheap per screen, but not invisible |
| Skip Lite | Logic + UI | Swift/SwiftUI subset, silent failures | Real Compose on Android, at the price of transpilation rules |

## Where these conclusions come from

Before this project, my code had already crossed platform lines several times. Each time
taught one lesson, and those lessons set the expectations tested here. (They rate my
experience, not the technologies: I am biased toward what I have shipped.)

| Technology | Shipped on | Lesson |
| --- | --- | --- |
| C++ | Android · iOS · macOS · Windows · Web | Works everywhere, but you pay a high price in wrappers. |
| Swift / Obj-C / Obj-C++ | iOS · macOS | Sharing logic *and* UI is easy — inside one ecosystem. |
| C# / .NET | Windows · macOS | One platform pays nothing; the others carry the whole load at every level. |
| React Native (TypeScript) | Android · iOS · Web | You really can share UI, and you accept the framework's limits. |

**C++.** It compiles for every platform, has no garbage collector and adds almost nothing in
performance or megabytes. Complex business logic and the types it works on are written once;
each platform wraps them in a class that implements its own ViewModel interface. The problem
is the bridge to Swift and Kotlin: two memory models, different API-design conventions on
each side, and wrapper code that cannot use the modern features of either language.

**Swift between iOS and macOS.** Sharing logic and even UI is natural, but only because both
platforms live in one ecosystem with shared frameworks.

**C# between Windows and macOS.** On Windows C# is the natural choice and sharing is free. On
macOS the app carries the .NET runtime, a performance overhead, two IDEs, two memory-management
systems and call stacks that are hard to read.

**React Native.** Screens written in TypeScript render as real native views, can be embedded
in an existing app and, implemented carefully, are indistinguishable for the user. The
limitations are covered below.

## The frame: four constraints

Every technology in this repo was chosen against the same four constraints.

### 1. Only solutions that end in a native UI

A framework that draws its own UI on a canvas has to re-implement behaviour every other app
gets for free from the system. **A canvas loses the system, not the pixels:**

- accessibility
- text selection
- the input method editor
- gestures
- Dynamic Type
- new design languages such as Liquid Glass

Any technology can produce a good app or a poor one. But the platform behaviour above is
something a native UI gets on day one, and a re-implementation has to chase forever.

### 2. The app stays native; the SDK is the variable

The host apps remain SwiftUI and Compose. That keeps full control:

- new platform APIs are usable from the first day;
- the cross-platform technology is hidden behind the SDK boundary, so one app can use several
  of them at once and replace one with another, including a technology from outside the
  platform's ecosystem.

### 3. Not the whole app in one framework

Each feature is its own SDK. *A hundred desktop features shouldn't ship their runtime into a
phone — you pay for what you mount, not for what exists.*

What it buys: each SDK owns its domain model, abstractions stay small and understandable,
release and deprecation cycles are independent, and new approaches are easy to try.

What it costs, and should be accepted knowingly:

- lost consistency between features;
- coordination between teams and SDKs;
- adaptation fixes at every boundary;
- diamond dependencies (two SDKs pulling different versions of the same library);
- duplicated logic;
- a testing illusion: each SDK passes on its own, and the integration still breaks.

### 4. Pay the runtime once

The first feature pays for the runtime; every further feature pays only for its own code.
That is why the UI-bearing SDKs here are split into `core` plus three feature screens: more
than one feature over one runtime is the only way to measure what the *next* screen costs.

## The four technologies: expected vs. found

### Rust + UniFFI — share logic

**Expected:** a thin platform ViewModel and small overhead; called directly from Android and
iOS, without the C++ wrapping pain, with the memory model hidden.

**How it works.** Swift and Kotlin cannot call Rust directly; they meet at the C ABI through a
foreign function interface (FFI). UniFFI, an open-source tool started by Mozilla, generates
both sides of the bridge from macros such as `uniffi::export` and `uniffi::Record`: the Rust
*scaffolding*, and the Swift and Kotlin *bindings* plus a C header. iOS calls the C functions
through that header; Android calls them through JNA, which finds them by name in the `.so`
without hand-written JNI.

**Found:**

- Bindings are fully generated: not one line of wrapper is written by hand. UniFFI writes
  8,473 lines so the hosts need only 64 lines of adapter.
- The API boundary still has to be designed, but with far fewer constraints than in C++.
- Bindings are idiomatic: `Option` and `Vec` arrive as `Optional` and `Array`.
- Records are copied every time they cross the boundary, so prefer a few coarse calls over
  many fine ones.
- UniFFI does not produce reactive state. Small adapters republish changes as `@Observable`
  on iOS and `StateFlow` on Android; they are architecture glue, not business logic.
- The memory model is hidden on Swift. Kotlin wrappers are `AutoCloseable`, and an explicit
  `close()` is recommended.
- Work in progress: the generated Swift bindings are not yet fully compatible with Swift 6
  strict concurrency. They live in a separate SwiftPM target in Swift 5 mode while the app
  stays on Swift 6.

**Conclusion:** Rust keeps the strengths of C++ and drops most of its weaknesses. Logic and
its tests live in one place, and the bridge is written by a generator, not by people.

### Swift, cross-compiled for Android — share logic

**Expected:** a real shared core and an honest bill; called directly from Android, native on
iOS, without the C++ wrapping pain, with the memory model hidden.

**How it works.** On iOS the app and the SDK are the same language: no bridge, no cost. On
Android the Swift SDK for Android compiles the code into a `.so`, and `swift-java`'s
`jextract` reads the public Swift interface and generates Java classes plus small Swift JNI
thunks. At run time Kotlin calls the Java class, JNI enters the thunk, and the thunk calls the
real Swift. Android has no Panama/FFM, so the bridge runs in `jni` mode.

**Found:**

- Bindings to Java are fully generated, but a Swift facade for Java has to be designed by
  hand. It hides unsupported types, exposes only what Android needs, keeps `jextract` and
  `swift-java` out of the iOS build, and lets the bridge stay in Swift 5 mode while the SDK
  itself uses Swift 6 strict concurrency.
- Swift objects stay in Swift and the Java wrapper holds their address. Strings and arrays are
  copied; `Set` and `Dictionary` are live wrappers, so every access is a JNI call. A property
  of an unsupported type silently loses only its getter or setter.
- In general the memory model stays hidden: a global arena frees Swift objects when the JVM
  collects their Java wrappers.
- Android carries its own Swift runtime and Foundation: about 6.2 MB more to download and the
  largest install of any approach (21.75 MB against 2.88 MB for the baseline).
- Android iteration is slow, and Swift cannot be debugged from Android Studio.
- Unlike Rust's C-ABI scaffolding, which serves iOS and Android alike, the JNI thunks follow
  the JVM's conventions and only work against a JVM.
- Free on iOS.

**Conclusion:** the Compose app really does run the same Swift, and the bridge is generated.
It is the newest and least polished technology here — yet it needed the fewest iterations to
finish the demo, because Swift is the code I read and review best. Familiarity is a real cost
factor.

### React Native — share logic and UI

**Expected:** cheap reuse, visible seams — and the measuring instrument the other three get
measured against. React Native's motto is "learn once, write anywhere", not "write once, run
anywhere".

**How it works.** Whole screens are written once in TypeScript and rendered by React Native as
real native views. Each platform has a thin native adapter: on iOS it wraps
`RCTReactNativeFactory`, created once and then asked for screens by JS module name with no
second Hermes; on Android it creates a surface through `ReactHost`. Parameters go in as
simple types packed into props. In the New Architecture there is no message-queue bridge any
more: JSI lets Hermes hold direct references to native objects, and Codegen generates typed
interfaces for both platforms from a typed JS spec.

**Found:**

- One Hermes runtime is shared by all feature SDKs.
- The next feature is cheap: a thin adapter and more JS in the same bundle.
- The host never imports React Native; it sees only each SDK's Swift or Kotlin API.
- Codegen types the JS → native calls; props stay JSON.
- The toolkit seam is visible: these are React Native widgets, not Liquid Glass or Material 3.
  Layout comes from Yoga's flexbox rather than the platform (Auto Layout is gone on iOS).
- Types that already exist in the native app, and even existing component libraries, have to
  be re-implemented in JS.
- It is the most expensive approach in adapters (733 lines) and configuration, and the only
  one with a large fixed cost on iOS (~21 MB).

**Conclusion:** React Native really can share UI, it keeps maturing and has a large community,
but its limits are accepted twice: in the development process and in how the app looks.

### Skip Lite — share logic and UI

**Expected:** free on iOS, expensive on Android.

**How it works.** Skip never renders SwiftUI on Android. At build time `skipstone` transpiles
Swift to Kotlin, and SkipUI — a re-implementation of the SwiftUI API — calls Jetpack Compose.
On the device there is only Kotlin and Compose; on iOS the same code is plain SwiftUI, with no
bridge and no runtime on top. (Skip's other mode, Fuse, compiles Swift natively for Android:
the whole language, at the price of the runtime and almost no debugging on Android. Skip
recommends Fuse for new apps; this repo uses Lite.)

**Found:**

- Real Compose on Android, debuggable from Android Studio as ordinary Kotlin — the most
  important difference from cross-compiled Swift.
- Only a subset of Swift and SwiftUI is available. Platform-specific code, even inline
  Kotlin, can live in the shared SDK behind `#if` checks.
- **The generator translates the declaration, not the platform behaviour.** Failures come in
  two kinds. The loud kind is an unsupported SwiftUI API that stops the build. The silent kind
  only shows on the device: views and icons that do not render, and the things SwiftUI does
  implicitly — lifting content above the keyboard, adding *Done* above it — have nothing to
  translate, because the code never asked for them. Most failures are silent.
- Generated Kotlin is never edited by hand; the next build overwrites it.
- Skip's libraries bring their own versions (Kotlin, Navigation 3) into the host, so Skip's
  version axis becomes yours.
- The Android job changes from "write Compose" to "read Compose".
- Free on iOS.

**Conclusion:** with Skip Lite, the cost moves to the limits of transpilation. It is the only
approach that empties the host apps, and a natural fit where iOS leads the product or Android
design follows iOS.

## What the numbers say

Release builds, arm64. Full tables, definitions and methodology: [README](README.md).

**What it costs to ship**

| Approach | iOS `.app` | Android download | Android install | Fixed runtime (iOS / Android) |
| --- | ---: | ---: | ---: | --- |
| Native baseline | 1.96 MB | 1.47 MB | 2.88 MB | — |
| Rust | 2.83 MB | 2.17 MB | 4.62 MB | ~0.55 / ~0.4 MB |
| Swift | 1.97 MB | 7.76 MB | 21.75 MB | 0 / ~6.2 MB |
| React Native | 23.32 MB | 6.70 MB | 17.00 MB | ~21.2 / ~5.2 MB |
| Skip Lite | 2.07 MB | 4.83 MB | 13.54 MB | 0 / ~3.3 MB |

**What it costs to write** (significant hand-written lines)

| Approach | Host code vs baseline | Adapters | Total | Generated |
| --- | ---: | ---: | ---: | ---: |
| Native baseline | — | — | 4,492 | — |
| Rust | −27% | 64 | 4,878 | 8,473 |
| Swift | −28% | 569 | 4,743 | 1,152 |
| React Native | −25% | 733 | 5,531 | 282 |
| Skip Lite | −46% | 216 | 4,524 | 2,785 |

Reading them together:

1. **No approach writes less code in total than the baseline.** Sharing moves lines out of
   the hosts and into shared code, adapters and generated code. The win is *one* copy of the
   logic to change and test, not fewer lines.
2. **Sharing logic empties the hosts by about a quarter**, whichever language does it — and
   so does React Native, whose screens still need native hosting and adapters. Only Skip,
   whose shared UI *is* the hosts' own toolkit, goes further (−46%).
3. **Fixed cost decides, per-feature cost rarely does.** Every approach adds roughly 0–100 KB
   per further feature; the runtime is what separates them. Swift and Skip are free on iOS
   because the Swift runtime ships with the OS; React Native pays on both platforms.
4. **Rust is the cheapest way to share logic in bytes**, and pays in generated code instead.

## Context and caveats

- The demo deliberately targets **iOS 26 and Android 17**, which penalises the technologies
  that share UI: new design languages land in SwiftUI and Compose first.
- It is a demonstration app with no real business logic, so the share of logic — and with it
  the benefit of sharing it — is smaller than in a production app. Tests are not counted.
- The two native apps were generated from a [spec](shared-ui-spec/) with AI tools; the other
  four pairs were built on top of them by extracting code step by step and watching what
  changed, not by maximising reuse.
- **On AI:** for a small app, AI handles writing everything twice well. In a large app the
  problems are consistency, maintenance and scale. A transpiler such as Skip is effectively a
  rulebook for how SwiftUI and iOS APIs map to Android, which makes AI + Skip a potentially
  strong combination.

## References

**Rust on mobile**
- [The UniFFI user guide](https://mozilla.github.io/uniffi-rs/latest/)
- [UniFFI repository](https://github.com/mozilla/uniffi-rs)

**Swift on Android**
- [Getting Started with the Swift SDK for Android](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html)
- [swift-java repository](https://github.com/swiftlang/swift-java)
- [Android Doesn't Deserve Swift — But We Did It Anyway](https://www.youtube.com/watch?v=EIGl6GOo210)
- [Our Android App Is Written in Swift](https://forums.swift.org/t/our-android-app-is-written-in-swift/88778)

**React Native**
- [React Native repository](https://github.com/react/react-native)
- [Integration with existing apps](https://reactnative.dev/docs/integration-with-existing-apps)
- [Hermes](https://reactnative.dev/docs/hermes)
- [Codegen](https://reactnative.dev/docs/the-new-architecture/what-is-codegen)

**Skip**
- [SwiftUI support table](https://skip.dev/docs/modules/skip-ui/#supported-swiftui)
- [Skip vs. the other frameworks](https://skip.dev/compare/)
- [Lite vs. Fuse](https://skip.dev/docs/modes/)
- [Skip repositories](https://github.com/orgs/skiptools/repositories)
