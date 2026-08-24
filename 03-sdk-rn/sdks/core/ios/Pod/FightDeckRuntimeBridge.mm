#import "FightDeckRuntimeBridge.h"

static NSString *const kFightDeckSurfaceLayoutNotification = @"FightDeckSurfaceLayout";

@implementation FightDeckRuntimeBridge {
  BOOL _hasListeners;
}

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[ @"fightdeckSurfaceLayout", @"fightdeckFeatureResult" ];
}

- (instancetype)init
{
  if (self = [super init]) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSurfaceLayout:)
                                                 name:kFightDeckSurfaceLayoutNotification
                                               object:nil];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)startObserving
{
  _hasListeners = YES;
}

- (void)stopObserving
{
  _hasListeners = NO;
}

- (void)handleSurfaceLayout:(NSNotification *)note
{
  [self sendEventWithName:@"fightdeckSurfaceLayout" body:note.userInfo ?: @{}];
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
