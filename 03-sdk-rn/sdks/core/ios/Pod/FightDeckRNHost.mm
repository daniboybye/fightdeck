#import "FightDeckRNHost.h"

#import <React/RCTBundleURLProvider.h>
#import <React/RCTSurfaceHostingProxyRootView.h>
#import <React/RCTFabricSurface.h>
#import "RCTDefaultReactNativeFactoryDelegate.h"
#import "RCTAppDependencyProvider.h"
#import "RCTReactNativeFactory.h"
#import "RCTRootViewFactory.h"
#import <React/RCTBundleManager.h>
#import <React/RCTDevMenu.h>
#import <react/renderer/core/ReactPrimitives.h>

using facebook::react::DisplayMode;

@interface FightDeckRNFactoryDelegate : RCTDefaultReactNativeFactoryDelegate
@end

@implementation FightDeckRNFactoryDelegate

- (NSURL *)bundleURL
{
  NSBundle *frameworkBundle = [NSBundle bundleForClass:[FightDeckRNFactoryDelegate class]];
  NSBundle *resourceBundle = [NSBundle bundleWithPath:[frameworkBundle pathForResource:@"FightDeckRNRuntime" ofType:@"bundle"]];
  if (resourceBundle != nil) {
    NSURL *hbc = [resourceBundle URLForResource:@"fightdeck" withExtension:@"hbc"];
    if (hbc != nil) {
      return hbc;
    }
    NSURL *jsbundle = [resourceBundle URLForResource:@"fightdeck" withExtension:@"jsbundle"];
    if (jsbundle != nil) {
      return jsbundle;
    }
  }
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"src/runtime/index"];
#else
  return nil;
#endif
}

@end

@interface FightDeckRNSurfaceController : UIViewController
@property (nonatomic, strong) UIView *surfaceView;
@end

@implementation FightDeckRNSurfaceController

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
  if (self.surfaceView != nil) {
    self.surfaceView.frame = self.view.bounds;
    self.surfaceView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.surfaceView];
  }
}

@end

static void FightDeckRNSetSurfaceDisplayMode(UIView *surfaceView, DisplayMode mode)
{
  if (![surfaceView isKindOfClass:[RCTSurfaceHostingProxyRootView class]]) {
    return;
  }
  RCTSurfaceHostingProxyRootView *hostingView = (RCTSurfaceHostingProxyRootView *)surfaceView;
  id<RCTSurfaceProtocol> surface = hostingView.surface;
  if (![surface isKindOfClass:[RCTFabricSurface class]]) {
    return;
  }
  const auto &handler = [(RCTFabricSurface *)surface surfaceHandler];
  handler.setDisplayMode(mode);
}

static void FightDeckRNTearDownSurfaceView(UIView *surfaceView)
{
  if (surfaceView == nil) {
    return;
  }
  if ([surfaceView isKindOfClass:[RCTSurfaceHostingProxyRootView class]]) {
    RCTSurfaceHostingProxyRootView *hostingView = (RCTSurfaceHostingProxyRootView *)surfaceView;
    id<RCTSurfaceProtocol> surface = hostingView.surface;
    [surface stop];
  }
  [surfaceView removeFromSuperview];
}

@implementation FightDeckRNHost {
  RCTReactNativeFactory *_factory;
  FightDeckRNFactoryDelegate *_delegate;
  NSMutableDictionary<NSString *, FightDeckRNSurfaceController *> *_controllers;
  NSTimeInterval _coldStartMs;
  NSTimeInterval _prewarmedStartMs;
  BOOL _prewarmed;
  BOOL _hostPaused;
}

+ (instancetype)shared
{
  static FightDeckRNHost *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [FightDeckRNHost new];
  });
  return instance;
}

- (instancetype)init
{
  if (self = [super init]) {
    _controllers = [NSMutableDictionary new];
    _delegate = [FightDeckRNFactoryDelegate new];
    _delegate.dependencyProvider = [RCTAppDependencyProvider new];
    _factory = [[RCTReactNativeFactory alloc] initWithDelegate:_delegate];
  }
  return self;
}

+ (void)initializeHost
{
  (void)[self shared];
}

+ (void)prewarm
{
  NSTimeInterval start = CFAbsoluteTimeGetCurrent();
  FightDeckRNHost *host = [self shared];
  if (host->_prewarmed) {
    return;
  }
  [host->_factory.rootViewFactory initializeReactHostWithLaunchOptions:nil
                                                   bundleConfiguration:[RCTBundleConfiguration defaultConfiguration]
                                                  devMenuConfiguration:[RCTDevMenuConfiguration defaultConfiguration]];
  host->_prewarmedStartMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0;
  host->_prewarmed = YES;
}

+ (UIViewController *)makeViewControllerWithModuleName:(NSString *)moduleName
                                            properties:(NSDictionary *)properties
{
  NSTimeInterval start = CFAbsoluteTimeGetCurrent();
  FightDeckRNHost *host = [self shared];

  FightDeckRNSurfaceController *existing = host->_controllers[moduleName];
  if (existing != nil) {
    [self updateProperties:properties forModuleName:moduleName];
    return existing;
  }

  if (!host->_prewarmed) {
    host->_coldStartMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0;
  }

  UIView *surfaceView = [host->_factory.rootViewFactory viewWithModuleName:moduleName
                                                         initialProperties:properties ?: @{}];

  FightDeckRNSurfaceController *controller = [FightDeckRNSurfaceController new];
  controller.surfaceView = surfaceView;
  host->_controllers[moduleName] = controller;
  [self updateProperties:properties forModuleName:moduleName];
  if (host->_hostPaused) {
    FightDeckRNSetSurfaceDisplayMode(surfaceView, DisplayMode::Suspended);
  }
  return controller;
}

+ (void)updateProperties:(NSDictionary *)properties forModuleName:(NSString *)moduleName
{
  FightDeckRNSurfaceController *controller = [self shared]->_controllers[moduleName];
  if (controller == nil || controller.surfaceView == nil) {
    return;
  }
  if ([controller.surfaceView isKindOfClass:[RCTSurfaceHostingProxyRootView class]]) {
    ((RCTSurfaceHostingProxyRootView *)controller.surfaceView).appProperties = properties ?: @{};
  }
}

+ (void)destroySurface:(NSString *)moduleName
{
  FightDeckRNHost *host = [self shared];
  FightDeckRNSurfaceController *controller = host->_controllers[moduleName];
  if (controller == nil) {
    return;
  }
  FightDeckRNTearDownSurfaceView(controller.surfaceView);
  controller.surfaceView = nil;
  [host->_controllers removeObjectForKey:moduleName];
}

+ (void)onHostResume
{
  FightDeckRNHost *host = [self shared];
  host->_hostPaused = NO;
  for (FightDeckRNSurfaceController *controller in host->_controllers.allValues) {
    FightDeckRNSetSurfaceDisplayMode(controller.surfaceView, DisplayMode::Visible);
  }
}

+ (void)onHostPause
{
  FightDeckRNHost *host = [self shared];
  host->_hostPaused = YES;
  for (FightDeckRNSurfaceController *controller in host->_controllers.allValues) {
    FightDeckRNSetSurfaceDisplayMode(controller.surfaceView, DisplayMode::Suspended);
  }
}

+ (void)onHostDestroy
{
  FightDeckRNHost *host = [self shared];
  NSArray<NSString *> *moduleNames = host->_controllers.allKeys;
  for (NSString *moduleName in moduleNames) {
    [self destroySurface:moduleName];
  }
  host->_prewarmed = NO;
  host->_hostPaused = NO;
}

+ (NSTimeInterval)coldStartMilliseconds
{
  return [self shared]->_coldStartMs;
}

+ (NSTimeInterval)prewarmedStartMilliseconds
{
  return [self shared]->_prewarmedStartMs;
}

@end
