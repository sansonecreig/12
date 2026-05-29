#import <Foundation/Foundation.h>

@interface DeviceSpoofer : NSObject
+ (instancetype)shared;
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
