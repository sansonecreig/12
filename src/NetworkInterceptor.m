#import "NetworkInterceptor.h"
#import <substrate.h>
#import <objc/runtime.h>

static IMP original_dataTaskWithCompletion = NULL;
static NSMutableArray<NSString *> *targetHosts = nil;
static NSString *const kRemoteConfigURL = @"https://raw.githubusercontent.com/sansonecreig/12/main/domains.json";
static NSString *const kLastUpdateKey = @"MatrixNetworkLastUpdate";
static NSString *const kCachedDomainsKey = @"MatrixNetworkCachedDomains";

// 默认域名列表（当远程获取失败时使用）
static NSArray<NSString *> *defaultDomains(void) {
    return @[@"kkong.xyz", @"ces.php"];
}

// 加载本地缓存
static void loadCachedDomains() {
    NSArray *cached = [[NSUserDefaults standardUserDefaults] objectForKey:kCachedDomainsKey];
    if (cached && [cached isKindOfClass:[NSArray class]]) {
        @synchronized (targetHosts) {
            [targetHosts removeAllObjects];
            [targetHosts addObjectsFromArray:cached];
        }
    } else {
        @synchronized (targetHosts) {
            [targetHosts removeAllObjects];
            [targetHosts addObjectsFromArray:defaultDomains()];
        }
    }
}

// 保存到缓存
static void saveCachedDomains(NSArray *domains) {
    [[NSUserDefaults standardUserDefaults] setObject:domains forKey:kCachedDomainsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// 异步从 GitHub 拉取配置
static void fetchRemoteDomains(void (^completion)(NSArray *newDomains, NSError *error)) {
    NSURL *url = [NSURL URLWithString:kRemoteConfigURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10.0];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            if (completion) completion(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError || ![dict isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(nil, jsonError);
            return;
        }
        NSArray *domains = dict[@"domains"];
        if (![domains isKindOfClass:[NSArray class]]) {
            if (completion) completion(nil, [NSError errorWithDomain:@"MatrixNetwork" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid format"}]);
            return;
        }
        NSMutableArray *validDomains = [NSMutableArray array];
        for (id obj in domains) {
            if ([obj isKindOfClass:[NSString class]]) {
                [validDomains addObject:obj];
            }
        }
        if (completion) completion(validDomains, nil);
    }];
    [task resume];
}

// 更新拦截域名列表
static void updateTargetHosts(NSArray *newDomains) {
    if (!newDomains || newDomains.count == 0) return;
    @synchronized (targetHosts) {
        [targetHosts removeAllObjects];
        [targetHosts addObjectsFromArray:newDomains];
    }
    saveCachedDomains(newDomains);
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kLastUpdateKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"[NetworkInterceptor] Updated domains: %@", newDomains);
}

// 检查是否需要远程更新（24小时一次）
static BOOL shouldUpdate() {
    NSDate *last = [[NSUserDefaults standardUserDefaults] objectForKey:kLastUpdateKey];
    if (!last) return YES;
    NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:last];
    return interval > 24 * 60 * 60;
}

// 初始化本地域名列表
static void initTargetHosts() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        targetHosts = [NSMutableArray array];
        loadCachedDomains();
        if ([[NSUserDefaults standardUserDefaults] objectForKey:kCachedDomainsKey] == nil) {
            fetchRemoteDomains(^(NSArray *newDomains, NSError *error) {
                if (newDomains) updateTargetHosts(newDomains);
            });
        } else if (shouldUpdate()) {
            fetchRemoteDomains(^(NSArray *newDomains, NSError *error) {
                if (newDomains) updateTargetHosts(newDomains);
            });
        }
    });
}

// 检查请求是否需要被拦截
static BOOL shouldInterceptRequest(NSURLRequest *request) {
    if ([request.URL.absoluteString isEqualToString:kRemoteConfigURL]) {
        return NO;
    }
    NSString *host = request.URL.host;
    NSString *path = request.URL.path;
    @synchronized (targetHosts) {
        for (NSString *target in targetHosts) {
            if ([host containsString:target] || [path containsString:target]) {
                return YES;
            }
        }
    }
    return NO;
}

// 伪造响应
static NSURLResponse *createFakeResponse(NSURLRequest *request, NSInteger statusCode, NSDictionary *headers) {
    return [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                       statusCode:statusCode
                                      HTTPVersion:@"HTTP/1.1"
                                     headerFields:headers];
}

// Hook 的新实现
static id new_dataTaskWithRequest(id self, SEL _cmd, NSURLRequest *request, void (^completionHandler)(NSData *, NSURLResponse *, NSError *)) {
    if (shouldInterceptRequest(request)) {
        NSDictionary *fakeJSON = @{@"status": @1, @"message": @"ok"};
        NSData *fakeData = [NSJSONSerialization dataWithJSONObject:fakeJSON options:0 error:nil];
        NSDictionary *headers = @{@"Content-Type": @"application/json; charset=utf-8"};
        NSURLResponse *fakeResponse = createFakeResponse(request, 200, headers);
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(fakeData, fakeResponse, nil);
            });
        }
        static Class fakeTaskClass = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            fakeTaskClass = objc_allocateClassPair([NSObject class], "FakeDataTask", 0);
            class_addMethod(fakeTaskClass, @selector(resume), imp_implementationWithBlock(^{}), "v@:");
            class_addMethod(fakeTaskClass, @selector(cancel), imp_implementationWithBlock(^{}), "v@:");
            objc_registerClassPair(fakeTaskClass);
        });
        return [[fakeTaskClass alloc] init];
    }
    typedef id (*OriginalFunc)(id, SEL, NSURLRequest *, id);
    OriginalFunc orig = (OriginalFunc)original_dataTaskWithCompletion;
    return orig(self, _cmd, request, completionHandler);
}

@implementation NetworkInterceptor

+ (void)startIntercepting {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        initTargetHosts();
        Class cls = NSClassFromString(@"__NSCFLocalDataTask");
        if (!cls) cls = [NSURLSession class];
        SEL sel = @selector(dataTaskWithRequest:completionHandler:);
        MSHookMessageEx(cls, sel, (IMP)new_dataTaskWithRequest, (IMP *)&original_dataTaskWithCompletion);
        NSLog(@"[NetworkInterceptor] installed");
    });
}

+ (void)stopIntercepting {
    if (original_dataTaskWithCompletion) {
        Class cls = NSClassFromString(@"__NSCFLocalDataTask");
        if (!cls) cls = [NSURLSession class];
        MSHookMessageEx(cls, @selector(dataTaskWithRequest:completionHandler:), original_dataTaskWithCompletion, NULL);
        original_dataTaskWithCompletion = NULL;
    }
}

@end

// KingSessionConfiguration 用于外部调用注入/卸载
@interface KingSessionConfiguration : NSObject
+ (void)inject;
+ (void)eject;
@end

@implementation KingSessionConfiguration
+ (void)inject { [NetworkInterceptor startIntercepting]; }
+ (void)eject { [NetworkInterceptor stopIntercepting]; }
@end
