# R8 rules — 03-sdk-rn
#
# React Native's own artifacts ship consumer rules, so the framework protects itself. What they
# cannot know about is our side of the bridge: a native module is reached from JavaScript by the
# name it registers, and a Fabric view manager by the name in its component descriptor. Neither
# is a call R8 can see, so both would be renamed or removed as unreachable.
-keep class com.fightdeck.rn.runtime.** { *; }
-keep class com.fightdeck.sdk.** { *; }

# Methods exposed to JavaScript are invoked reflectively by the bridge.
-keepclassmembers class * {
    @com.facebook.react.bridge.ReactMethod <methods>;
}
-keepclassmembers class * {
    @com.facebook.react.uimanager.annotations.ReactProp <methods>;
    @com.facebook.react.uimanager.annotations.ReactPropGroup <methods>;
}

# Serializable dataset models — the generated serialisers are reached through the companion.
-keepclassmembers class com.fightdeck.baseline.data.** {
    *** Companion;
}
-keepclasseswithmembers class com.fightdeck.baseline.data.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.fightdeck.baseline.data.**$$serializer { *; }
