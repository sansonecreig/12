#import <Foundation/Foundation.h>

@interface DeviceSpoofer : NSObject
+ (instancetype)shared;
- (NSDictionary *)deviceInfoForModel:(NSString *)model;
- (NSArray<NSString *> *)allSupportedModels;
- (void)applySpoofingWithModel:(NSString *)model completion:(void(^)(BOOL needsReboot))completion;
@end
