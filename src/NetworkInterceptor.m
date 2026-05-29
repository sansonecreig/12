#import "NetworkInterceptor.h"
#import <objc/runtime.h>

@interface MatrixURLProtocol : NSURLProtocol
@end

static NSString *const kMatrixHandledKey = @"MatrixURLProtocolHandled";

@implementation MatrixURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if ([NSURLProtocol propertyForKey:kMatrixHandledKey inRequest:request]) {
        return NO;
    }
    NSString *scheme = request.URL.scheme.lowercaseString;
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        return YES;
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *newRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:kMatrixHandledKey inRequest:newRequest];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:newRequest
                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self.client URLProtocol:self didFailWithError:error];
        } else {
            if ([self.request.URL.host containsString:@"kkong.xyz"]) {
                NSString *fakeJSON = @"{\"status\":1,\"message\":\"ok\"}";
                data = [fakeJSON dataUsingEncoding:NSUTF8StringEncoding];
                NSHTTPURLResponse *fakeResponse = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                                              statusCode:200
                                                                             HTTPVersion:@"HTTP/1.1"
                                                                            headerFields:@{@"Content-Type": @"application/json"}];
                response = fakeResponse;
            }
            [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
            [self.client URLProtocol:self didLoadData:data];
            [self.client URLProtocolDidFinishLoading:self];
        }
    }];
    [task resume];
}

- (void)stopLoading {
}

@end

@implementation NetworkInterceptor

+ (void)startIntercepting {
    [NSURLProtocol registerClass:[MatrixURLProtocol class]];
}

+ (void)stopIntercepting {
    [NSURLProtocol unregisterClass:[MatrixURLProtocol class]];
}

@end

@implementation KingSessionConfiguration
+ (void)inject { [NetworkInterceptor startIntercepting]; }
+ (void)eject { [NetworkInterceptor stopIntercepting]; }
@end
