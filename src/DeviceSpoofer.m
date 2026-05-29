#import "DeviceSpoofer.h"
#import <sys/sysctl.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <substrate.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <AdSupport/AdSupport.h>

// ============================================================================
// 辅助函数：生成随机标识符
// ============================================================================

static NSString* generateRandomSerialNumber(NSString *model) {
    NSString *prefix = @"C39";
    NSMutableString *serial = [NSMutableString stringWithString:prefix];
    static NSString *letters = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    for (int i = 0; i < 9; i++) {
        [serial appendFormat:@"%c", [letters characterAtIndex:arc4random_uniform((uint32_t)letters.length)]];
    }
    return serial;
}

static NSString* generateRandomMLBSerial() {
    NSMutableString *mlb = [NSMutableString string];
    static NSString *letters = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    for (int i = 0; i < 12; i++) {
        [mlb appendFormat:@"%c", [letters characterAtIndex:arc4random_uniform((uint32_t)letters.length)]];
    }
    return mlb;
}

static NSString* generateRandomUUID() {
    return [[NSUUID UUID] UUIDString];
}

// ============================================================================
// DeviceSpoofer 实现
// ============================================================================

@interface DeviceSpoofer ()
@property (nonatomic, copy) NSString *fakeSerialNumber;
@property (nonatomic, copy) NSString *fakeMLBSerial;
@property (nonatomic, copy) NSString *fakeHardwareUUID;
@property (nonatomic, copy) NSString *fakeDeviceColor;
@end

@implementation DeviceSpoofer {
    NSDictionary *_deviceDB;
    NSString *_selectedModel;
    NSString *_shadowSuffix;
}

static DeviceSpoofer *_sharedInstance = nil;

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[DeviceSpoofer alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _deviceDB = [self buildDeviceDatabase];
        _selectedModel = [[NSUserDefaults standardUserDefaults] stringForKey:@"SelectedModel"];
        if (!_selectedModel || !_deviceDB[_selectedModel]) {
            _selectedModel = [self currentRealModel];
        }
        _shadowSuffix = [[NSUserDefaults standardUserDefaults] stringForKey:@"ShadowDomainKey"];
        if (!_shadowSuffix) {
            _shadowSuffix = [NSString stringWithFormat:@"_NEBULA_%@", [[NSUUID UUID].UUIDString substringToIndex:8]];
            [[NSUserDefaults standardUserDefaults] setObject:_shadowSuffix forKey:@"ShadowDomainKey"];
        }
        
        // 初始化伪造标识符
        _fakeSerialNumber = [[NSUserDefaults standardUserDefaults] stringForKey:@"FakeSerialNumber"];
        if (!_fakeSerialNumber) {
            _fakeSerialNumber = generateRandomSerialNumber(_selectedModel);
            [[NSUserDefaults standardUserDefaults] setObject:_fakeSerialNumber forKey:@"FakeSerialNumber"];
        }
        _fakeMLBSerial = [[NSUserDefaults standardUserDefaults] stringForKey:@"FakeMLBSerial"];
        if (!_fakeMLBSerial) {
            _fakeMLBSerial = generateRandomMLBSerial();
            [[NSUserDefaults standardUserDefaults] setObject:_fakeMLBSerial forKey:@"FakeMLBSerial"];
        }
        _fakeHardwareUUID = [[NSUserDefaults standardUserDefaults] stringForKey:@"FakeHardwareUUID"];
        if (!_fakeHardwareUUID) {
            _fakeHardwareUUID = generateRandomUUID();
            [[NSUserDefaults standardUserDefaults] setObject:_fakeHardwareUUID forKey:@"FakeHardwareUUID"];
        }
        _fakeDeviceColor = [[NSUserDefaults standardUserDefaults] stringForKey:@"FakeDeviceColor"];
        if (!_fakeDeviceColor) {
            _fakeDeviceColor = [NSString stringWithFormat:@"%d", arc4random_uniform(10)];
            [[NSUserDefaults standardUserDefaults] setObject:_fakeDeviceColor forKey:@"FakeDeviceColor"];
        }
        
        [[NSUserDefaults standardUserDefaults] synchronize];
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

- (NSString *)fakeMachine {
    return _selectedModel;
}

- (NSString *)fakeBoardID {
    return _deviceDB[_selectedModel][@"boardID"] ?: @"j123ap";
}

- (NSString *)fakeChipID {
    return _deviceDB[_selectedModel][@"chipID"] ?: @"0x8010";
}

- (NSNumber *)fakeMemory {
    return _deviceDB[_selectedModel][@"memory"] ?: @4294967296;
}

- (NSNumber *)fakeCPUCount {
    return _deviceDB[_selectedModel][@"cpuCount"] ?: @6;
}

- (NSString *)fakeProductName {
    return _deviceDB[_selectedModel][@"productName"] ?: @"iPhone";
}

- (void)applySpoofingWithModel:(NSString *)model completion:(void(^)(BOOL needsReboot))completion {
    if (!_deviceDB[model]) {
        if (completion) completion(NO);
        return;
    }
    _selectedModel = model;
    [[NSUserDefaults standardUserDefaults] setObject:model forKey:@"SelectedModel"];
    
    // 重新生成所有可变的标识符
    _fakeSerialNumber = generateRandomSerialNumber(model);
    _fakeMLBSerial = generateRandomMLBSerial();
    _fakeHardwareUUID = generateRandomUUID();
    _fakeDeviceColor = [NSString stringWithFormat:@"%d", arc4random_uniform(10)];
    
    [[NSUserDefaults standardUserDefaults] setObject:_fakeSerialNumber forKey:@"FakeSerialNumber"];
    [[NSUserDefaults standardUserDefaults] setObject:_fakeMLBSerial forKey:@"FakeMLBSerial"];
    [[NSUserDefaults standardUserDefaults] setObject:_fakeHardwareUUID forKey:@"FakeHardwareUUID"];
    [[NSUserDefaults standardUserDefaults] setObject:_fakeDeviceColor forKey:@"FakeDeviceColor"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 重置 Keychain 影子域
    [self resetKeychainShadowDomain];
    
    // 发送通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DeviceSpoofingDidChange" object:model];
    
    NSLog(@"[DeviceSpoofer] Switched to model: %@, Serial: %@, UUID: %@", model, _fakeSerialNumber, _fakeHardwareUUID);
    
    if (completion) completion(YES);
}

- (void)resetKeychainShadowDomain {
    _shadowSuffix = [NSString stringWithFormat:@"_NEBULA_%@", [[NSUUID UUID].UUIDString substringToIndex:8]];
    [[NSUserDefaults standardUserDefaults] setObject:_shadowSuffix forKey:@"ShadowDomainKey"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)shadowDomainSuffix {
    return _shadowSuffix;
}

@end

// ============================================================================
// Hook 实现：sysctl
// ============================================================================

static int (*orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t) = NULL;

static int hooked_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    DeviceSpoofer *spoofer = [DeviceSpoofer shared];
    
    if (strcmp(name, "hw.machine") == 0) {
        const char *machine = [spoofer.fakeMachine UTF8String];
        size_t len = strlen(machine) + 1;
        if (oldp && oldlenp) {
            if (*oldlenp >= len) {
                memcpy(oldp, machine, len);
            }
            *oldlenp = len;
        }
        return 0;
    }
    
    if (strcmp(name, "hw.memsize") == 0 || strcmp(name, "hw.physmem") == 0) {
        uint64_t mem = [spoofer.fakeMemory unsignedLongLongValue];
        if (oldp && oldlenp) {
            if (*oldlenp >= sizeof(uint64_t)) {
                memcpy(oldp, &mem, sizeof(uint64_t));
            }
            *oldlenp = sizeof(uint64_t);
        }
        return 0;
    }
    
    if (strcmp(name, "hw.ncpu") == 0) {
        int cpu = [spoofer.fakeCPUCount intValue];
        if (oldp && oldlenp) {
            if (*oldlenp >= sizeof(int)) {
                memcpy(oldp, &cpu, sizeof(int));
            }
            *oldlenp = sizeof(int);
        }
        return 0;
    }
    
    return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}

// ============================================================================
// Hook 实现：MGCopyAnswer (MobileGestalt)
// ============================================================================

static void* (*orig_MGCopyAnswer)(CFStringRef) = NULL;

static void* hooked_MGCopyAnswer(CFStringRef property) {
    NSString *key = (__bridge NSString *)property;
    DeviceSpoofer *spoofer = [DeviceSpoofer shared];
    
    // 序列号
    if ([key isEqualToString:@"SerialNumber"]) {
        return (__bridge_retained void *)[spoofer.fakeSerialNumber copy];
    }
    
    // MLB 序列号
    if ([key isEqualToString:@"MLBSerialNumber"]) {
        return (__bridge_retained void *)[spoofer.fakeMLBSerial copy];
    }
    
    // UniqueDeviceID / UniqueChipID
    if ([key isEqualToString:@"UniqueDeviceID"] || [key isEqualToString:@"UniqueChipID"]) {
        return (__bridge_retained void *)[spoofer.fakeSerialNumber copy];
    }
    
    // 硬件 UUID
    if ([key isEqualToString:@"IOPlatformUUID"] || [key isEqualToString:@"HardwareUUID"]) {
        return (__bridge_retained void *)[spoofer.fakeHardwareUUID copy];
    }
    
    // 设备颜色
    if ([key isEqualToString:@"DeviceColor"]) {
        return (__bridge_retained void *)[spoofer.fakeDeviceColor copy];
    }
    
    // 设备类型
    if ([key isEqualToString:@"DeviceClass"]) {
        NSString *model = spoofer.fakeMachine;
        NSString *deviceClass = @"iPhone";
        if ([model hasPrefix:@"iPad"]) deviceClass = @"iPad";
        return (__bridge_retained void *)[deviceClass copy];
    }
    
    // 产品类型 / 机型
    if ([key isEqualToString:@"ProductType"] || [key isEqualToString:@"UserAssignedDeviceName"]) {
        return (__bridge_retained void *)[spoofer.fakeMachine copy];
    }
    
    // 主板 ID
    if ([key isEqualToString:@"BoardId"]) {
        return (__bridge_retained void *)[spoofer.fakeBoardID copy];
    }
    
    // 芯片 ID
    if ([key isEqualToString:@"ChipID"]) {
        NSString *chipID = spoofer.fakeChipID;
        unsigned int chipIdVal = 0;
        NSScanner *scanner = [NSScanner scannerWithString:chipID];
        [scanner scanHexInt:&chipIdVal];
        return (void *)(uintptr_t)chipIdVal;
    }
    
    // 调用原始函数
    if (orig_MGCopyAnswer) {
        return orig_MGCopyAnswer(property);
    }
    return NULL;
}

// ============================================================================
// Hook 实现：IOKit IORegistryEntryCreateCFProperty
// ============================================================================

static CFTypeRef (*orig_IORegistryEntryCreateCFProperty)(mach_port_t, CFStringRef, CFAllocatorRef, uint32_t) = NULL;

static CFTypeRef hooked_IORegistryEntryCreateCFProperty(mach_port_t entry, CFStringRef property, CFAllocatorRef allocator, uint32_t options) {
    NSString *key = (__bridge NSString *)property;
    DeviceSpoofer *spoofer = [DeviceSpoofer shared];
    
    if ([key isEqualToString:@"IOPlatformSerialNumber"]) {
        return CFBridgingRetain([spoofer.fakeSerialNumber copy]);
    }
    
    if ([key isEqualToString:@"IOPlatformUUID"]) {
        return CFBridgingRetain([spoofer.fakeHardwareUUID copy]);
    }
    
    if ([key isEqualToString:@"board-id"]) {
        return CFBridgingRetain([spoofer.fakeBoardID copy]);
    }
    
    if ([key isEqualToString:@"chip-id"]) {
        NSString *chipID = spoofer.fakeChipID;
        unsigned int chipIdVal = 0;
        NSScanner *scanner = [NSScanner scannerWithString:chipID];
        [scanner scanHexInt:&chipIdVal];
        return CFBridgingRetain([NSData dataWithBytes:&chipIdVal length:sizeof(chipIdVal)]);
    }
    
    if (orig_IORegistryEntryCreateCFProperty) {
        return orig_IORegistryEntryCreateCFProperty(entry, property, allocator, options);
    }
    return NULL;
}

// ============================================================================
// Hook 实现：IDFA / IDFV
// ============================================================================

static IMP orig_advertisingIdentifier = NULL;
static IMP orig_identifierForVendor = NULL;

static id new_advertisingIdentifier(id self, SEL _cmd) {
    // 返回一个固定的伪造 IDFA
    return [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000001"];
}

static id new_identifierForVendor(id self, SEL _cmd) {
    DeviceSpoofer *spoofer = [DeviceSpoofer shared];
    // 基于当前伪造机型生成稳定的 IDFV（使用随机字符串，无需 MD5）
    NSString *vendorStr = [NSString stringWithFormat:@"%@-%@",
                           spoofer.fakeMachine,
                           [spoofer.fakeSerialNumber substringToIndex:MIN(8, spoofer.fakeSerialNumber.length)]];
    // 生成 8-4-4-4-12 格式的 UUID
    static NSString *hex = @"0123456789abcdef";
    NSMutableString *uuid = [NSMutableString string];
    int lengths[] = {8, 4, 4, 4, 12};
    for (int i = 0; i < 5; i++) {
        if (i > 0) [uuid appendString:@"-"];
        for (int j = 0; j < lengths[i]; j++) {
            [uuid appendFormat:@"%c", [hex characterAtIndex:arc4random_uniform(16)]];
        }
    }
    return [[NSUUID alloc] initWithUUIDString:uuid];
}

static void hookIDFA() {
    Class asManager = NSClassFromString(@"ASIdentifierManager");
    if (asManager) {
        SEL sel = @selector(advertisingIdentifier);
        Method method = class_getInstanceMethod(asManager, sel);
        if (method) {
            orig_advertisingIdentifier = method_getImplementation(method);
            method_setImplementation(method, (IMP)new_advertisingIdentifier);
        }
    }
    
    Class uiDevice = [UIDevice class];
    SEL sel2 = @selector(identifierForVendor);
    Method method2 = class_getInstanceMethod(uiDevice, sel2);
    if (method2) {
        orig_identifierForVendor = method_getImplementation(method2);
        method_setImplementation(method2, (IMP)new_identifierForVendor);
    }
    
    NSLog(@"[DeviceSpoofer] IDFA/IDFV hooks installed");
}

// ============================================================================
// 初始化函数
// ============================================================================

__attribute__((constructor))
static void initDeviceSpooferHooks() {
    // Hook sysctlbyname
    void *libSystem = dlopen(NULL, RTLD_LAZY);
    orig_sysctlbyname = (int (*)(const char *, void *, size_t *, void *, size_t))dlsym(libSystem, "sysctlbyname");
    if (orig_sysctlbyname) {
        MSHookFunction((void *)orig_sysctlbyname, (void *)hooked_sysctlbyname, (void **)&orig_sysctlbyname);
    }
    
    // Hook MGCopyAnswer
    void *libMobileGestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
    if (libMobileGestalt) {
        orig_MGCopyAnswer = (void* (*)(CFStringRef))dlsym(libMobileGestalt, "MGCopyAnswer");
        if (orig_MGCopyAnswer) {
            MSHookFunction((void *)orig_MGCopyAnswer, (void *)hooked_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
        }
    }
    
    // Hook IOKit
    void *ioKit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (ioKit) {
        orig_IORegistryEntryCreateCFProperty = (CFTypeRef (*)(mach_port_t, CFStringRef, CFAllocatorRef, uint32_t))
            dlsym(ioKit, "IORegistryEntryCreateCFProperty");
        if (orig_IORegistryEntryCreateCFProperty) {
            MSHookFunction((void *)orig_IORegistryEntryCreateCFProperty, 
                          (void *)hooked_IORegistryEntryCreateCFProperty, 
                          (void **)&orig_IORegistryEntryCreateCFProperty);
        }
    }
    
    // Hook IDFA/IDFV
    hookIDFA();
    
    // 初始化单例
    [DeviceSpoofer shared];
    
    NSLog(@"[DeviceSpoofer] All hooks installed successfully");
}
