#import "NetworkInterceptor.h"
#import <objc/runtime.h>

static IMP original_dataTaskWithCompletion = NULL;
static BOOL isIntercepting = NO;

static id new_dataTaskWithCompletion(id self, SEL _cmd, NSURLRequest *request, void (^completionHandler)(NSData*, NSURLResponse*, NSError*)) {
    if ([NSURLProtocol propertyForKey:@"MatrixIntercepted" inRequest:request]) {
        typedef id (*Func)(id, SEL, NSURLRequest*, id);
        return ((Func)original_dataTaskWithCompletion)(self, _cmd, request, completionHandler);
    }
    
    if ([request.URL.host containsString:@"kkong.xyz"]) {
        if (completionHandler) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:nil];
            NSData *fakeData = [@"{\"status\":\"blocked\"}" dataUsingEncoding:NSUTF8StringEncoding];
            completionHandler(fakeData, resp, nil);
        }
        return nil;
    }
    
    NSMutableURLRequest *newReq = [request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"MatrixIntercepted" inRequest:newReq];
    typedef id (*Func)(id, SEL, NSURLRequest*, id);
    return ((Func)original_dataTaskWithCompletion)(self, _cmd, newReq, completionHandler);
}

@implementation NetworkInterceptor

+ (void)startIntercepting {
    if (isIntercepting) return;
    Class cls = [NSURLSession class];
    SEL sel = @selector(dataTaskWithRequest:completionHandler:);
    Method m = class_getInstanceMethod(cls, sel);
    if (m) {
        original_dataTaskWithCompletion = method_setImplementation(m, (IMP)new_dataTaskWithCompletion);
        isIntercepting = YES;
    }
}

+ (void)stopIntercepting {
    if (!isIntercepting) return;
    Class cls = [NSURLSession class];
    SEL sel = @selector(dataTaskWithRequest:completionHandler:);
    Method m = class_getInstanceMethod(cls, sel);
    if (m && original_dataTaskWithCompletion) {
        method_setImplementation(m, original_dataTaskWithCompletion);
        isIntercepting = NO;
    }
}

@end

@implementation KingSessionConfiguration
+ (void)inject { [NetworkInterceptor startIntercepting]; }
+ (void)eject { [NetworkInterceptor stopIntercepting]; }
@end
