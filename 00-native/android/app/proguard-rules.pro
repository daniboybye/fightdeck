# R8 rules — 00-native
#
# The baseline has no foreign runtime to protect: no JNI, no FFI, no transpiled code. The only
# thing R8 cannot see through is kotlinx.serialization, whose generated serialisers are looked
# up through the companion rather than called directly.

# Serializable dataset models. Keeping the generated serialisers by name is narrower than
# keeping the classes themselves: the fields still get renamed, only the mapping survives.
-keepclassmembers class com.fightdeck.baseline.data.** {
    *** Companion;
}
-keepclasseswithmembers class com.fightdeck.baseline.data.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.fightdeck.baseline.data.**$$serializer { *; }
