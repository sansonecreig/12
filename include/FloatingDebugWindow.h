#import <UIKit/UIKit.h>

@interface FloatingDebugWindow : UIWindow
+ (instancetype)sharedWindow;
- (void)showDeviceSpooferMenu;
@end
