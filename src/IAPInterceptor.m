#import "IAPInterceptor.h"
#import <objc/runtime.h>
#import <StoreKit/StoreKit.h>

static IMP original_addPayment = NULL;

static id new_addPayment(id self, SEL _cmd, SKPayment *payment) {
    NSLog(@"[IAP] Intercepted addPayment: %@", payment.productIdentifier);
    return nil;
}

@implementation IAPInterceptor

+ (void)startIntercepting {
    Class skQueue = NSClassFromString(@"SKPaymentQueue");
    if (skQueue) {
        Method m = class_getInstanceMethod(skQueue, @selector(addPayment:));
        if (m) original_addPayment = method_setImplementation(m, (IMP)new_addPayment);
    }
}

+ (void)stopIntercepting {
    Class skQueue = NSClassFromString(@"SKPaymentQueue");
    if (skQueue && original_addPayment) {
        Method m = class_getInstanceMethod(skQueue, @selector(addPayment:));
        if (m) method_setImplementation(m, original_addPayment);
    }
}

@end
