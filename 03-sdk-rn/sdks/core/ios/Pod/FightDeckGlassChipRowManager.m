#import <React/RCTViewManager.h>

@interface RCT_EXTERN_MODULE(FightDeckGlassChipRowViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(values, NSArray)
RCT_EXPORT_VIEW_PROPERTY(accentHex, NSString)
RCT_EXPORT_VIEW_PROPERTY(onSelect, RCTDirectEventBlock)

@end
