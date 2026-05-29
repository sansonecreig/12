#import "DeviceSpoofer.h"
#import <sys/sysctl.h>
#import <UIKit/UIKit.h>

@implementation DeviceSpoofer {
    NSDictionary *_deviceDB;
    NSString *_selectedModel;
    NSString *_shadowSuffix;
}

+ (instancetype)shared {
    static DeviceSpoofer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DeviceSpoofer alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _deviceDB = [self buildDeviceDatabase];
        _selectedModel = [self currentRealModel];
        _shadowSuffix = [[NSUserDefaults standardUserDefaults] stringForKey:@"ShadowDomainKey"];
        if (!_shadowSuffix) {
            _shadowSuffix = [NSString stringWithFormat:@"_NEBULA_%@", [[NSUUID UUID].UUIDString substringToIndex:8]];
            [[NSUserDefaults standardUserDefaults] setObject:_shadowSuffix forKey:@"ShadowDomainKey"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
    return self;
}

- (NSDictionary *)buildDeviceDatabase {
    NSMutableDictionary *db = [NSMutableDictionary dictionary];
    db[@"iPhone15,3"] = @{@"productName": @"iPhone 14 Pro Max", @"boardID": @"d74pAP", @"chipID": @"0x8061", @"memory": @8589934592, @"cpuCount": @6};
    db[@"iPhone15,2"] = @{@"productName": @"iPhone 14 Pro", @"boardID": @"d74pAP", @"chipID": @"0x8061", @"memory": @6442450944, @"cpuCount": @6};
    db[@"iPhone14,7"] = @{@"productName": @"iPhone 14", @"boardID": @"d28sAP", @"chipID": @"0x8010", @"memory": @4294967296, @"cpuCount": @6};
    db[@"iPhone14,4"] = @{@"productName": @"iPhone 13 mini", @"boardID": @"d25sAP", @"chipID": @"0x8010", @"memory": @4294967296, @"cpuCount": @6};
    db[@"iPhone14,5"] = @{@"productName": @"iPhone 13", @"boardID": @"d26sAP", @"chipID": @"0x8010", @"memory": @4294967296, @"cpuCount": @6};
    return db;
}

- (NSString *)currentRealModel {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *model = [NSString stringWithUTF8String:machine];
    free(machine);
    return model;
}

- (NSDictionary *)deviceInfoForModel:(NSString *)model {
    return _deviceDB[model];
}

- (NSArray<NSString *> *)allSupportedModels {
    return [_deviceDB allKeys];
}

- (void)setTargetModel:(NSString *)model {
    if (_deviceDB[model]) _selectedModel = model;
}

- (NSString *)currentModel { return _selectedModel; }
- (NSString *)fakeMachine { return _selectedModel; }
- (NSString *)fakeProductType { return _selectedModel; }
- (NSString *)fakeBoardID { return _deviceDB[_selectedModel][@"boardID"] ?: @"unknown"; }
- (uint64_t)fakeMemory { return [_deviceDB[_selectedModel][@"memory"] unsignedLongLongValue]; }
- (NSInteger)fakeCPUCount { return [_deviceDB[_selectedModel][@"cpuCount"] integerValue]; }

- (void)applySpoofingWithModel:(NSString *)model completion:(void(^)(BOOL))completion {
    if (!_deviceDB[model]) { if (completion) completion(NO); return; }
    _selectedModel = model;
    [self resetKeychainShadowDomain];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DeviceSpoofingDidChange" object:model];
    if (completion) completion(YES);
}

- (void)resetKeychainShadowDomain {
    _shadowSuffix = [NSString stringWithFormat:@"_NEBULA_%@", [[NSUUID UUID].UUIDString substringToIndex:8]];
    [[NSUserDefaults standardUserDefaults] setObject:_shadowSuffix forKey:@"ShadowDomainKey"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
