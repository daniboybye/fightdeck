# R8 rules — 04-sdk-skip
#
# The Skip AARs ship no consumer rules, and the transpiled code is the most reflective of any
# approach here. Two reasons, both structural rather than sloppy:
#
#   1. Codable becomes reflective. Swift's synthesised `init(from:)` transpiles to
#      `container.decode(String::class, forKey = CodingKeys.boutID)` — the type and the key are
#      runtime values, so R8 sees no reference to the property it fills.
#   2. SkipUI resolves parts of the SwiftUI shape through kotlin-reflect, which is why the AAR
#      build has to add that dependency at all.
#
# So the shared modules and the Skip runtime are kept whole. That is the honest trade: the
# approach that shares the most code is also the one R8 can shrink the least.
-keep class fight.deck.** { *; }
-keepclassmembers class fight.deck.** { *; }
-keep class skip.** { *; }
-keepclassmembers class skip.** { *; }

# `-keep` and not merely `-keepclassmembers`. The narrower rule — keep every member but let R8
# delete classes nothing statically references — was tried and measured: it saves 1.70 MB and
# the app then loads no data at all. The events screen shows "Something went wrong" and logcat
# is empty, because the decode failure surfaces as an ordinary caught error rather than a
# crash. A shrinker misconfiguration on the reflective path is invisible to the build and
# nearly invisible at runtime, which is a good reason not to trade 1.70 MB for it.

# kotlin-reflect reads @Metadata to recover Kotlin declarations; without it the reflective
# lookups above resolve against the erased Java view and fail.
-keep class kotlin.Metadata { *; }
-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*
