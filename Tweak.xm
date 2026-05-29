#import "DeviceSpoofer.h"
#import "AdvancedMemAccess.h"
#import "FloatingDebugWindow.h"
#import "NetworkInterceptor.h"
#import "IAPInterceptor.h"
#import "AdSkipInterceptor.h"
#import "AESCryptoManager.h"

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [DeviceSpoofer shared];
            [AdvancedMemAccess sharedInstance];
        });
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[FloatingDebugWindow sharedWindow] setHidden:NO];
            [NetworkInterceptor startIntercepting];
            [IAPInterceptor startIntercepting];
            [AdSkipInterceptor startIntercepting];
        });
    });
}
