#import <Foundation/Foundation.h>

@interface DeviceSpoofer : NSObject
+ (instancetype)shared;
- (NSDictionary *)deviceInfoForModel:(NSString *)model;
- (NSArray<NSString *> *)allSupportedModels;
- (void)setTargetModel:(NSString *)model;
- (NSString *)currentModel;
- (NSString *)fakeMachine;
- (NSString *)fakeProductType;
- (NSString *)fakeBoardID;
- (uint64_t)fakeMemory;
- (NSInteger)fakeCPUCount;
- (void)applySpoofingWithModel:(NSString *)model completion:(void(^)(BOOL requiresReboot))completion;
- (void)resetKeychainShadowDomain;
@end
