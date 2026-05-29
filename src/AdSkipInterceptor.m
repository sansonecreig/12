#import "AdSkipInterceptor.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

static IMP original_viewDidLoad = NULL;

static void new_viewDidLoad(id self, SEL _cmd) {
    ((void(*)(id,SEL))original_viewDidLoad)(self, _cmd);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIButton *closeBtn = [AdSkipInterceptor findCloseButtonInView:(UIView *)self];
        if (closeBtn) [closeBtn sendActionsForControlEvents:UIControlEventTouchUpInside];
    });
}

@implementation AdSkipInterceptor

+ (UIButton *)findCloseButtonInView:(UIView *)view {
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)sub;
            NSString *title = [btn titleForState:UIControlStateNormal];
            if ([title containsString:@"关闭"] || [title containsString:@"X"] || [title containsString:@"Close"]) return btn;
        }
        UIButton *found = [self findCloseButtonInView:sub];
        if (found) return found;
    }
    return nil;
}

+ (void)startIntercepting {
    Class cls = NSClassFromString(@"BURewardedVideoWebViewController");
    if (cls) {
        Method m = class_getInstanceMethod(cls, @selector(viewDidLoad));
        if (m) original_viewDidLoad = method_setImplementation(m, (IMP)new_viewDidLoad);
    }
}

+ (void)stopIntercepting {
    Class cls = NSClassFromString(@"BURewardedVideoWebViewController");
    if (cls && original_viewDidLoad) {
        Method m = class_getInstanceMethod(cls, @selector(viewDidLoad));
        if (m) method_setImplementation(m, original_viewDidLoad);
    }
}

@end
