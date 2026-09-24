#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Host → JS half of the codegen'd bridge: stores the layout for `surfaceLayout()` and emits
/// `onSurfaceLayout` when it changed. Plain C so Swift can call it; the module class behind it
/// includes the generated C++ spec and cannot be imported from Swift.
FOUNDATION_EXPORT void FightDeckPublishSurfaceLayout(
    NSString *moduleName,
    double safeAreaTop,
    double safeAreaBottom,
    double keyboardBottomInset,
    NSString *chromeBackground,
    BOOL textInputActive);

NS_ASSUME_NONNULL_END
