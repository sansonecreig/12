#import <Foundation/Foundation.h>

@interface NetworkInterceptor : NSObject
+ (void)startIntercepting;
+ (void)stopIntercepting;
@end

@interface KingSessionConfiguration : NSObject
+ (void)inject;
+ (void)eject;
@end
