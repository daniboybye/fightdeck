// Fabric native component — ObjC++ wrapper is mandatory; a Fabric component cannot
// be pure Swift. This RCTViewComponentView hosts SwiftUI via UIHostingController.
//
// Linked when the CocoaPods RN runtime xcframework pass is enabled on CI.

#import <UIKit/UIKit.h>

#if __has_include(<React/RCTViewComponentView.h>)
#import <React/RCTViewComponentView.h>
#import <react/renderer/components/FightDeckNativeBadgeSpec/ComponentDescriptors.h>
#import <react/renderer/components/FightDeckNativeBadgeSpec/Props.h>

@interface FightDeckNativeBadgeComponentView : RCTViewComponentView
@end

@implementation FightDeckNativeBadgeComponentView

+ (void)load {
  // Component registration via codegen — see FightDeckNativeBadgeNativeComponent.ts
}

@end
#endif
