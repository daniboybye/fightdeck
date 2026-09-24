#import "FightDeckRuntimeBridge.h"

#import <FightDeckRuntimeSpec/FightDeckRuntimeSpec.h>
#import "FightDeckRNRuntime-Swift.h"

/// Implements the protocol codegen wrote from `NativeFightDeckRuntimeBridge.ts`. The JSI glue,
/// argument conversion and event plumbing are generated; this class only says where each call
/// lands. Registered through `codegenConfig.ios.modules`, never in the host app.
@interface FightDeckRuntimeBridge : NativeFightDeckRuntimeBridgeSpecBase <NativeFightDeckRuntimeBridgeSpec>
@end

static __weak FightDeckRuntimeBridge *sLiveBridge;
static NSMutableDictionary<NSString *, NSDictionary *> *sLayouts = [NSMutableDictionary new];

@implementation FightDeckRuntimeBridge

RCT_EXPORT_MODULE()

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeFightDeckRuntimeBridgeSpecJSI>(params);
}

/// Only the instance wired to JavaScript gets an emitter, so it is the one layouts go to.
- (void)setEventEmitterCallback:(EventEmitterCallbackWrapper *)eventEmitterCallbackWrapper
{
  [super setEventEmitterCallback:eventEmitterCallbackWrapper];
  sLiveBridge = self;
}

- (void)depositConfirmed
{
  [FightDeckFeatureResults depositConfirmed];
}

- (void)depositCompleted:(NSString *)amount
{
  [FightDeckFeatureResults depositCompleted:amount];
}

- (void)betslipUpdated:(NSString *)slipJSON
{
  [FightDeckFeatureResults betslipUpdated:slipJSON];
}

- (void)betslipBrowseEvents
{
  [FightDeckFeatureResults betslipBrowseEvents];
}

- (void)betslipDeposit
{
  [FightDeckFeatureResults betslipDeposit];
}

- (void)betslipPlaced:(NSString *)message slipJSON:(NSString *)slipJSON balance:(NSString *)balance
{
  [FightDeckFeatureResults betslipPlaced:message slipJSON:slipJSON balance:balance];
}

/// Synchronous, so it runs on the JavaScript thread while the host publishes from the main one.
- (NSDictionary *)surfaceLayout:(NSString *)moduleName
{
  @synchronized(sLayouts) {
    return sLayouts[moduleName];
  }
}

@end

void FightDeckPublishSurfaceLayout(
    NSString *moduleName,
    double safeAreaTop,
    double safeAreaBottom,
    double keyboardBottomInset,
    NSString *chromeBackground,
    BOOL textInputActive)
{
  // Sub-point differences come from layout rounding, not from anything the user can see.
  NSDictionary *layout = @{
    @"moduleName" : moduleName,
    @"safeAreaTop" : @(round(safeAreaTop)),
    @"safeAreaBottom" : @(round(safeAreaBottom)),
    @"keyboardBottomInset" : @(round(keyboardBottomInset)),
    @"chromeBackground" : chromeBackground,
    @"textInputActive" : @(textInputActive),
  };
  @synchronized(sLayouts) {
    if ([sLayouts[moduleName] isEqualToDictionary:layout]) {
      return;
    }
    sLayouts[moduleName] = layout;
  }
  [sLiveBridge emitOnSurfaceLayout:layout];
}
