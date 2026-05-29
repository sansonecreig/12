#import <Foundation/Foundation.h>

@interface DeviceSpoofer : NSObject
+ (instancetype)shared;
- (void)startHooking;  // 延迟启动 Hook，避免 dyld 崩溃
- (NSDictionary *)deviceInfoForModel:(NSString *)model;
- (NSArray<NSString *> *)allSupportedModels;
- (void)applySpoofingWithModel:(NSString *)model completion:(void(^)(BOOL needsReboot))completion;
- (void)resetKeychainShadowDomain;
- (NSString *)fakeMachine;
- (NSString *)fakeProductType;
- (NSString *)fakeBoardID;
- (uint64_t)fakeMemory;
- (NSInteger)fakeCPUCount;
- (NSString *)fakeSerialNumber;
- (NSString *)fakeMLBSerial;
- (NSString *)fakeHardwareUUID;
@end
