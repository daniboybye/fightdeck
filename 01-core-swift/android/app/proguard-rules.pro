# R8 rules — 01-core-swift
#
# The three Swift AARs already ship their own `-keep class com.fightdeck.fight*.** { *; }`, so
# the jextract bindings survive without anything here. What they do not cover is the SwiftKit
# runtime bundled beside them as a plain jar: the native side reaches back into it by name for
# memory-session and allocation callbacks, and a renamed class there fails only at runtime.
-keep class org.swift.swiftkit.** { *; }
-keepclassmembers class org.swift.swiftkit.** { *; }

# Anything the Swift side calls back into, and anything holding a native pointer, has to keep
# its native methods: JNI resolves them by exact name and descriptor.
-keepclasseswithmembernames class * {
    native <methods>;
}

# SwiftKit annotates its thread-safety markers with JDK Flight Recorder annotations, which do
# not exist on Android. The annotations are never read here, so the dangling reference is
# harmless — but R8 treats a missing class as an error until it is named.
-dontwarn jdk.jfr.**

# Serializable dataset models — the generated serialisers are reached through the companion.
-keepclassmembers class com.fightdeck.swiftcore.data.** {
    *** Companion;
}
-keepclasseswithmembers class com.fightdeck.swiftcore.data.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.fightdeck.swiftcore.data.**$$serializer { *; }
