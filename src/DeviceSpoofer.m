#import "DeviceSpoofer.h"
#import <sys/sysctl.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>

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
    
    // iPhone 16 Series
    db[@"iPhone17,1"] = @{@"productName": @"iPhone 16 Pro", @"boardID": @"d74pAP", @"chipID": @"0x8103", @"memory": @8589934592, @"cpuCount": @6};
    db[@"iPhone17,2"] = @{@"productName": @"iPhone 16 Pro Max", @"boardID": @"d74pAP", @"chipID": @"0x8103", @"memory": @8589934592, @"cpuCount": @6};
    db[@"iPhone17,3"] = @{@"productName": @"iPhone 16", @"boardID": @"d83apAP", @"chipID": @"0x8103", @"memory": @6442450944, @"cpuCount": @6};
    db[@"iPhone17,4"] = @{@"productName": @"iPhone 16 Plus", @"boardID": @"d83papAP", @"chipID": @"0x8103", @"memory": @6442450944, @"cpuCount": @6};
    
    // iPhone 15 Series
    db[@"iPhone15,4"] = @{@"productName": @"iPhone 15", @"boardID": @"d84apAP", @"chipID": @"0x8101", @"memory": @6442450944, @"cpuCount": @6};
    db[@"iPhone15,5"] = @{@"productName": @"iPhone 15 Plus", @"boardID": @"d84papAP", @"chipID": @"0x8101", @"memory": @6442450944, @"cpuCount": @6};
    db[@"iPhone16,1"] = @{@"productName": @"iPhone 15 Pro", @"boardID": @"d84dpAP", @"chipID": @"0x8101", @"memory": @8589934592, @"cpuCount": @6};
    db[@"iPhone16,2"] = @{@"productName": @"iPhone 15 Pro Max", @"boardID": @"d84dpAP", @"chipID": @"0x8101", @"memory": @8589934592, @"cpuCount": @6};
    
    // iPhone 14 Series
    db[@"iPhone14,7"] = @{@"productName": @"iPhone 14", @"boardID": @"d28sAP", @"chipID": @"0x8010", @"memory": @6442450944, @"cpuCount": @6};
    db[@"iPhone14,8"] = @{@"productName": @"iPhone 14 Plus", @"boardID": @"d28sAP", @"chipID": @"0x8010", @"memory": @6442450944, @"cpuCount": @6};
    db[@"iPhone15,2"] = @{@"productName": @"iPhone 14 Pro", @"boardID": @"d74pAP", @"chipID": @"0x8061", @"memory": @6442450944, @"cpuCount": @6};
    db[@"iPhone15,3"] = @{@"productName": @"iPhone 14 Pro Max", @"boardID": @"d74pAP", @"chipID": @"0x8061", @"memory": @6442450944, @"cpuCount": @6};
    
    // iPhone 13 Series
    db[@"iPhone14,4"] = @{@"productName": @"iPhone 13 mini", @"boardID": @"d25sAP", @"chipID": @"0x8010", @"memory": @4294967296, @"cpuCount": @6};
    db[@"iPhone14,5"] = @{@"productName": @"iPhone 13", @"boardID": @"d26sAP", @"chipID": @"0x8010", @"memory": @4294967296, @"cpuCount": @6};
    db[@"iPhone14,2"] = @{@"productName": @"iPhone 13 Pro", @"boardID": @"d25pAP", @"chipID": @"0x8010", @"memory": @6442450944, @"cpuCount": @6};
    db[@"iPhone14,3"] = @{@"productName": @"iPhone 13 Pro Max", @"boardID": @"d25pAP", @"chipID": @"0x8010", @"memory": @6442450944, @"cpuCount": @6};
    
    // iPhone 12 Series
    db[@"iPhone13,1"] = @{@"productName": @"iPhone 12 mini", @"boardID": @"d24pAP", @"chipID": @"0x8010", @"memory": @4294967296, @"cpuCount": @6};
    db[@"iPhone13,2"] = @{@"productName": @"iPhone 12", @"boardID": @"d24pAP", @"chipID": @"0x8010", @"memory": @4294967296, @"cpuCount": @6};
    db[@"iPhone13,3"] = @{@"productName": @"iPhone 12 Pro", @"boardID": @"d24ppAP", @"chipID": @"0x8010", @"memory": @6442450944, @"cpuCount": @6};
    db[@"iPhone13,4"] = @{@"productName": @"iPhone 12 Pro Max", @"boardID": @"d24ppAP", @"chipID": @"0x8010", @"memory": @6442450944, @"cpuCount": @6};
    
    // iPhone 11 Series
    db[@"iPhone12,1"] = @{@"productName": @"iPhone 11", @"boardID": @"d421apAP", @"chipID": @"0x8010", @"memory": @4294967296, @"cpuCount": @6};
    db[@"iPhone12,3"] = @{@"productName": @"iPhone 11 Pro", @"boardID": @"d421bpAP", @"chipID": @"0x8010", @"memory": @6442450944, @"cpuCount": @6};
    db[@"iPhone12,5"] = @{@"productName": @"iPhone 11 Pro Max", @"boardID": @"d421bpAP", @"chipID": @"0x8010", @"memory": @6442450944, @"cpuCount": @6};
    
    // iPhone SE Series
    db[@"iPhone14,6"] = @{@"productName": @"iPhone SE (3rd gen)", @"boardID": @"d59apAP", @"chipID": @"0x8010", @"memory": @4294967296, @"cpuCount": @6};
    db[@"iPhone12,8"] = @{@"productName": @"iPhone SE (2nd gen)", @"boardID": @"d79apAP", @"chipID": @"0x8010", @"memory": @3221225472, @"cpuCount": @6};
    
    // iPad Pro Series
    db[@"iPad13,4"] = @{@"productName": @"iPad Pro 11-inch (3rd gen)", @"boardID": @"J617apAP", @"chipID": @"0x8103", @"memory": @8589934592, @"cpuCount": @8};
    db[@"iPad13,5"] = @{@"productName": @"iPad Pro 11-inch (3rd gen)", @"boardID": @"J617apAP", @"chipID": @"0x8103", @"memory": @8589934592, @"cpuCount": @8};
    db[@"iPad13,6"] = @{@"productName": @"iPad Pro 11-inch (3rd gen)", @"boardID": @"J617apAP", @"chipID": @"0x8103", @"memory": @8589934592, @"cpuCount": @8};
    db[@"iPad13,7"] = @{@"productName": @"iPad Pro 11-inch (3rd gen)", @"boardID": @"J617apAP", @"chipID": @"0x8103", @"memory": @8589934592, @"cpuCount": @8};
    db[@"iPad13,8"] = @{@"productName": @"iPad Pro 12.9-inch (5th gen)", @"boardID": @"J618apAP", @"chipID": @"0x8103", @"memory": @8589934592, @"cpuCount": @8};
    db[@"iPad13,9"] = @{@"productName": @"iPad Pro 12.9-inch (5th gen)", @"boardID": @"J618apAP", @"chipID": @"0x8103", @"memory": @8589934592, @"cpuCount": @8};
    db[@"iPad13,10"] = @{@"productName": @"iPad Pro 12.9-inch (5th gen)", @"boardID": @"J618apAP", @"chipID": @"0x8103", @"memory": @8589934592, @"cpuCount": @8};
    db[@"iPad13,11"] = @{@"productName": @"iPad Pro 12.9-inch (5th gen)", @"boardID": @"J618apAP", @"chipID": @"0x8103", @"memory": @8589934592, @"cpuCount": @8};
    
    // iPad Air Series
    db[@"iPad13,1"] = @{@"productName": @"iPad Air (5th gen)", @"boardID": @"J617apAP", @"chipID": @"0x8103", @"memory": @8589934592, @"cpuCount": @8};
    db[@"iPad13,2"] = @{@"productName": @"iPad Air (5th gen)", @"boardID": @"J617apAP", @"chipID": @"0x8103", @"memory": @8589934592, @"cpuCount": @8};
    db[@"iPad13,16"] = @{@"productName": @"iPad Air (4th gen)", @"boardID": @"J307apAP", @"chipID": @"0x8010", @"memory": @4294967296, @"cpuCount": @6};
    db[@"iPad13,17"] = @{@"productName": @"iPad Air (4th gen)", @"boardID": @"J307apAP", @"chipID": @"0x8010", @"memory": @4294967296, @"cpuCount": @6};
    
    // iPad Mini Series
    db[@"iPad14,1"] = @{@"productName": @"iPad mini (6th gen)", @"boardID": @"J618apAP", @"chipID": @"0x8010", @"memory": @4294967296, @"cpuCount": @6};
    db[@"iPad14,2"] = @{@"productName": @"iPad mini (6th gen)", @"boardID": @"J618apAP", @"chipID": @"0x8010", @"memory": @4294967296, @"cpuCount": @6};
    
    // iPad (10th gen)
    db[@"iPad14,5"] = @{@"productName": @"iPad (10th gen)", @"boardID": @"J310apAP", @"chipID": @"0x8010", @"memory": @4294967296, @"cpuCount": @6};
    
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

- (void)applySpoofingWithModel:(NSString *)model completion:(void(^)(BOOL needsReboot))completion {
    if (!_deviceDB[model]) {
        if (completion) completion(NO);
        return;
    }
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
