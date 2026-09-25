#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Owns the single RCTHost for all SDK features. ObjC++ surface — Fabric cannot be pure Swift.
@interface FightDeckRNHost : NSObject

+ (void)initializeHost;
+ (void)prewarm;
/// A new surface every time, as on Android: a screen shown again starts from its properties.
+ (UIViewController *)makeViewControllerWithModuleName:(NSString *)moduleName
                                            properties:(NSDictionary *)properties;
+ (void)updateProperties:(NSDictionary *)properties forViewController:(UIViewController *)controller;
+ (void)stopViewController:(UIViewController *)controller;
+ (void)onHostResume;
+ (void)onHostPause;
+ (NSTimeInterval)coldStartMilliseconds;
+ (NSTimeInterval)prewarmedStartMilliseconds;

@end

NS_ASSUME_NONNULL_END
