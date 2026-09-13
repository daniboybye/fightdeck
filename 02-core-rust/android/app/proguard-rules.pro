# R8 rules — 02-core-rust
#
# UniFFI's Kotlin talks to the Rust `.so` through JNA, which is name-based in both directions:
# the `Library` interface's method names *are* the exported Rust symbols, and JNA reads
# `Structure` subclasses' fields reflectively in declaration order. Renaming either is a
# runtime UnsatisfiedLinkError or a silently misread struct, so the generated bindings and the
# JNA runtime both have to survive intact. This is the price of a name-based FFI: R8 can shrink
# the app around it but not through it.
-keep class com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.** { *; }
-keep class * implements com.sun.jna.Library { *; }
-keep class * implements com.sun.jna.Callback { *; }

# JNA ships one artifact for desktop and Android, and its AWT bridge references java.awt, which
# Android does not have. That path is never taken here; the reference just has to be named.
-dontwarn java.awt.**

-keep class uniffi.** { *; }
-keepclassmembers class uniffi.** { *; }

# Serializable dataset models — the generated serialisers are reached through the companion.
-keepclassmembers class com.fightdeck.rust.data.** {
    *** Companion;
}
-keepclasseswithmembers class com.fightdeck.rust.data.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.fightdeck.rust.data.**$$serializer { *; }
