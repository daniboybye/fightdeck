#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>

/// JS → native channel. Registered inside the SDK pod, never in the host app.
@interface FightDeckRuntimeBridge : NSObject <RCTBridgeModule>
@end
