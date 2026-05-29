#import <Foundation/Foundation.h>

@interface NetworkInterceptor : NSObject
+ (void)startIntercepting;
+ (void)stopIntercepting;
@end

// 用于外部调用的兼容类
@interface KingSessionConfiguration : NSObject
+ (void)inject;
+ (void)eject;
@end
