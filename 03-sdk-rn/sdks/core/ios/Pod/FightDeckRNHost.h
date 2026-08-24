#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Owns the single RCTHost for all SDK features. ObjC++ surface — Fabric cannot be pure Swift.
@interface FightDeckRNHost : NSObject

+ (void)initializeHost;
+ (void)prewarm;
+ (UIViewController *)makeViewControllerWithModuleName:(NSString *)moduleName
                                            properties:(NSDictionary *)properties;
+ (void)updateProperties:(NSDictionary *)properties forModuleName:(NSString *)moduleName;
+ (void)destroySurface:(NSString *)moduleName;
+ (NSTimeInterval)coldStartMilliseconds;
+ (NSTimeInterval)prewarmedStartMilliseconds;

@end

NS_ASSUME_NONNULL_END
