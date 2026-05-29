#import "NetworkInterceptor.h"
#import <objc/runtime.h>

// ========== 自定义 NSURLProtocol ==========
static NSString *const kMatrixHandledKey = @"MatrixURLProtocolHandled";

@interface MatrixURLProtocol : NSURLProtocol <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSessionDataTask *task;
@end

@implementation MatrixURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if ([NSURLProtocol propertyForKey:kMatrixHandledKey inRequest:request]) return NO;
    NSString *scheme = request.URL.scheme.lowercaseString;
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) return YES;
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *newRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:kMatrixHandledKey inRequest:newRequest];
    
    // 拦截特定域名并返回假数据
    NSString *host = self.request.URL.host;
    NSString *path = self.request.URL.path;
    if ([host containsString:@"kkong.xyz"] || [path containsString:@"ces.php"]) {
        NSDictionary *fakeJSON = @{@"status": @1, @"message": @"ok"};
        NSData *fakeData = [NSJSONSerialization dataWithJSONObject:fakeJSON options:0 error:nil];
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                                   statusCode:200
                                                                  HTTPVersion:@"HTTP/1.1"
                                                                 headerFields:@{@"Content-Type": @"application/json"}];
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:fakeData];
        [self.client URLProtocolDidFinishLoading:self];
        return;
    }
    
    // 正常转发请求
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    self.task = [session dataTaskWithRequest:newRequest];
    [self.task resume];
}

- (void)stopLoading {
    [self.task cancel];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) [self.client URLProtocol:self didFailWithError:error];
    else [self.client URLProtocolDidFinishLoading:self];
}

@end

// ========== NetworkInterceptor 控制类 ==========
@implementation NetworkInterceptor

+ (void)startIntercepting {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [NSURLProtocol registerClass:[MatrixURLProtocol class]];
        NSLog(@"[NetworkInterceptor] NSURLProtocol registered");
    });
}

+ (void)stopIntercepting {
    [NSURLProtocol unregisterClass:[MatrixURLProtocol class]];
}

@end
