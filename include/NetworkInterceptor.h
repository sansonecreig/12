#import <Foundation/Foundation.h>

@interface NetworkInterceptor : NSObject
+ (void)startIntercepting;
+ (void)stopIntercepting;
@end
