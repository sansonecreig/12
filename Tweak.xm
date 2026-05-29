#import "DeviceSpoofer.h"
#import "AdvancedMemAccess.h"
#import "FloatingDebugWindow.h"
#import "NetworkInterceptor.h"
#import "IAPInterceptor.h"
#import "AdSkipInterceptor.h"
#import "AESCryptoManager.h"

static void appDidFinishLaunching(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FloatingDebugWindow sharedWindow] setHidden:NO];
        [NetworkInterceptor startIntercepting];
        [IAPInterceptor startIntercepting];
        [AdSkipInterceptor startIntercepting];
    });
}

%ctor {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [DeviceSpoofer shared];
        [AdvancedMemAccess sharedInstance];
    });
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL,
                                    appDidFinishLaunching,
                                    (CFStringRef)UIApplicationDidFinishLaunchingNotification,
                                    NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
