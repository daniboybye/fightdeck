#import <Foundation/Foundation.h>
#import <FightDeckRuntimeSpec/FightDeckRuntimeSpec.h>
#import "FightDeckRNRuntime-Swift.h"

/// Implements the protocol codegen wrote from `NativeFightDeckRuntimeBridge.ts`. The JSI glue,
/// argument conversion and event plumbing are generated; this class only says where each call
/// lands. Registered through `codegenConfig.ios.modules`, never in the host app.
@interface FightDeckRuntimeBridge : NativeFightDeckRuntimeBridgeSpecBase <NativeFightDeckRuntimeBridgeSpec>
@end

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

@end
