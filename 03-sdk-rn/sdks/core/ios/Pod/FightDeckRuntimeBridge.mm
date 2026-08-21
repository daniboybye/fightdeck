#import "FightDeckRuntimeBridge.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@implementation FightDeckRuntimeBridge

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

RCT_EXPORT_METHOD(postResult : (NSString *)feature payload : (NSDictionary *)payload)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FightDeckFeatureResult"
                                                        object:nil
                                                      userInfo:@{
                                                        @"feature" : feature,
                                                        @"payload" : payload ?: @{}
                                                      }];
  });
}

@end
