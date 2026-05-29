#import <Foundation/Foundation.h>

typedef void (^SpoofingCompletion)(BOOL needsReboot);

@interface DeviceSpoofer : NSObject

+ (instancetype)shared;

// 延迟 Hook 安装方法
- (void)startHooking;

// 获取所有支持的设备型号
- (NSArray *)allSupportedModels;

// 获取设备信息
- (NSDictionary *)deviceInfoForModel:(NSString *)model;

// 应用伪装
- (void)applySpoofingWithModel:(NSString *)model completion:(SpoofingCompletion)completion;

@end
