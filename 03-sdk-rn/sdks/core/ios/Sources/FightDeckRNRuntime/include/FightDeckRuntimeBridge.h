#import <React/RCTEventEmitter.h>

/// JS ↔ native channel. Registered inside the SDK pod, never in the host app.
@interface FightDeckRuntimeBridge : RCTEventEmitter
@end
