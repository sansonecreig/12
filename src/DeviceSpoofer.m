#import "DeviceSpoofer.h"
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AdSupport/AdSupport.h>
#import <notify.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>
#import "fishhook.h"

// ========== 辅助函数 ==========
static NSString* randomString(int length) {
    static NSString *letters = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *random = [NSMutableString stringWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [random appendFormat:@"%c", [letters characterAtIndex:arc4random_uniform((uint32_t)letters.length)]];
    }
    return random;
}

static NSString* generateRandomSerialNumber(NSString *model) {
    return [NSString stringWithFormat:@"C39%@", randomString(9)];
}
static NSString* generateRandomMLBSerial() { return randomString(12); }
static NSString* generateRandomUUID() { return [[NSUUID UUID] UUIDString]; }

// ========== 数据清理函数 ==========

// 清除 UserDefaults
static void cleanUserDefaults() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *dict = [defaults dictionaryRepresentation];
    for (NSString *key in dict) {
        if ([key hasPrefix:@"Fake"] || [key hasPrefix:@"Matrix"] || [key isEqualToString:@"ShadowDomainKey"]) continue;
        [defaults removeObjectForKey:key];
    }
    [defaults synchronize];
}

// 清除 Keychain（包括同步标记）
static void cleanKeychainDirectly() {
    NSArray *secClasses = @[(id)kSecClassGenericPassword, (id)kSecClassCertificate, (id)kSecClassIdentity, (id)kSecClassKey];
    for (id secClass in secClasses) {
        NSDictionary *query = @{
            (id)kSecClass: secClass,
            (id)kSecMatchLimit: (id)kSecMatchLimitAll,
            (id)kSecAttrSynchronizable: (id)kSecAttrSynchronizableAny
        };
        SecItemDelete((__bridge CFDictionaryRef)query);
    }
}

// 清除 WebKit 数据
static void cleanWebKitData() {
    NSSet *types = [NSSet setWithArray:@[
        WKWebsiteDataTypeCookies, WKWebsiteDataTypeLocalStorage, WKWebsiteDataTypeIndexedDBDatabases,
        WKWebsiteDataTypeWebSQLDatabases, WKWebsiteDataTypeSessionStorage
    ]];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:types modifiedSince:[NSDate distantPast] completionHandler:^{}];
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in cookieStorage.cookies) [cookieStorage deleteCookie:cookie];
}

// 终极暴力清除：删除沙盒内所有数据
static void nukeSandboxData() {
    NSString *home = NSHomeDirectory();
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirs = @[@"Documents", @"Library", @"tmp"];
    for (NSString *dir in dirs) {
        NSString *path = [home stringByAppendingPathComponent:dir];
        if ([fm fileExistsAtPath:path]) {
            [fm removeItemAtPath:path error:nil];
            [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
}

// 清除剪贴板
static void cleanPasteboard() {
    [[UIPasteboard generalPasteboard] setItems:@[]];
    UIPasteboard *pb = [UIPasteboard pasteboardWithName:@"com.apple.UIKit.pasteboard" create:NO];
    if (pb) [pb setItems:@[]];
}

// 清除推送令牌
static void cleanPushToken() {
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(unregisterForRemoteNotifications)]) {
        [[UIApplication sharedApplication] unregisterForRemoteNotifications];
    }
}

// 一键终极清理
static void nukeEverything() {
    nukeSandboxData();
    cleanUserDefaults();
    cleanKeychainDirectly();
    cleanWebKitData();
    cleanPasteboard();
    cleanPushToken();
    NSLog(@"[DeviceSpoofer] Nuke everything completed");
}

// ========== DeviceSpoofer 类 ==========
@interface DeviceSpoofer ()
@property (nonatomic, strong) NSDictionary *deviceDB;
@property (nonatomic, copy) NSString *selectedModel;
@property (nonatomic, copy) NSString *fakeSerialNumber;
@property (nonatomic, copy) NSString *fakeMLBSerial;
@property (nonatomic, copy) NSString *fakeHardwareUUID;
@property (nonatomic, copy) NSString *shadowSuffix;
@end

@implementation DeviceSpoofer

+ (instancetype)shared {
    static DeviceSpoofer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[DeviceSpoofer alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _deviceDB = [self buildDeviceDatabase];
        _selectedModel = [self currentRealModel];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        _fakeSerialNumber = [defaults stringForKey:@"FakeSerialNumber"] ?: generateRandomSerialNumber(_selectedModel);
        _fakeMLBSerial = [defaults stringForKey:@"FakeMLBSerial"] ?: generateRandomMLBSerial();
        _fakeHardwareUUID = [defaults stringForKey:@"FakeHardwareUUID"] ?: generateRandomUUID();
        _shadowSuffix = [defaults stringForKey:@"ShadowDomainKey"] ?: [NSString stringWithFormat:@"_NEBULA_%@", randomString(8)];
        [self saveFakeValues];
        [self installHooks];
    }
    return self;
}

- (void)saveFakeValues {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:_fakeSerialNumber forKey:@"FakeSerialNumber"];
    [defaults setObject:_fakeMLBSerial forKey:@"FakeMLBSerial"];
    [defaults setObject:_fakeHardwareUUID forKey:@"FakeHardwareUUID"];
    [defaults setObject:_shadowSuffix forKey:@"ShadowDomainKey"];
    [defaults synchronize];
}

- (NSString *)currentRealModel {
    size_t size; sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size); sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *model = [NSString stringWithUTF8String:machine]; free(machine);
    return model;
}

- (NSDictionary *)buildDeviceDatabase {
    // ========== 完整设备数据库 ==========
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

- (NSDictionary *)deviceInfoForModel:(NSString *)model { return _deviceDB[model]; }
- (NSArray<NSString *> *)allSupportedModels { return [_deviceDB allKeys]; }

- (void)applySpoofingWithModel:(NSString *)model completion:(void(^)(BOOL needsReboot))completion {
    if (!_deviceDB[model]) { if (completion) completion(NO); return; }
    _selectedModel = model;
    _fakeSerialNumber = generateRandomSerialNumber(model);
    _fakeMLBSerial = generateRandomMLBSerial();
    _fakeHardwareUUID = generateRandomUUID();
    _shadowSuffix = [NSString stringWithFormat:@"_NEBULA_%@", randomString(8)];
    [self saveFakeValues];
    
    // 终极清理所有残留数据
    nukeEverything();
    
    // 发送通知，刷新Hook中的缓存
    notify_post("com.matrix.device.spoofing.changed");
    
    if (completion) completion(YES);
}

- (void)resetKeychainShadowDomain {
    _shadowSuffix = [NSString stringWithFormat:@"_NEBULA_%@", randomString(8)];
    [[NSUserDefaults standardUserDefaults] setObject:_shadowSuffix forKey:@"ShadowDomainKey"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)fakeMachine { return _selectedModel; }
- (NSString *)fakeProductType { return _selectedModel; }
- (NSString *)fakeBoardID { return _deviceDB[_selectedModel][@"boardID"] ?: @"j123ap"; }
- (uint64_t)fakeMemory { return [_deviceDB[_selectedModel][@"memory"] unsignedLongLongValue]; }
- (NSInteger)fakeCPUCount { return [_deviceDB[_selectedModel][@"cpuCount"] integerValue]; }
- (NSString *)fakeSerialNumber { return _fakeSerialNumber; }
- (NSString *)fakeMLBSerial { return _fakeMLBSerial; }
- (NSString *)fakeHardwareUUID { return _fakeHardwareUUID; }

// ========== 原始函数指针 ==========
static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static CFTypeRef (*orig_IORegistryEntryCreateCFProperty)(mach_port_t, CFStringRef, CFAllocatorRef, uint32_t);
static void* (*orig_MGCopyAnswer)(CFStringRef);

// ========== sysctl Hook ==========
static int custom_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (ret != 0 || namelen < 2 || name[0] != CTL_HW) return ret;
    
    DeviceSpoofer *spoofer = [DeviceSpoofer shared];
    if (name[1] == HW_MACHINE || name[1] == HW_MODEL) {
        NSString *fake = [spoofer fakeMachine];
        size_t fakeLen = fake.length + 1;
        if (oldlenp && oldp && *oldlenp >= fakeLen) {
            memset(oldp, 0, *oldlenp);
            strcpy(oldp, fake.UTF8String);
            *oldlenp = fakeLen;
        } else if (oldlenp) *oldlenp = fakeLen;
    } else if (name[1] == HW_MEMSIZE) {
        uint64_t fakeMem = [spoofer fakeMemory];
        if (oldlenp && oldp && *oldlenp >= sizeof(uint64_t)) {
            memcpy(oldp, &fakeMem, sizeof(uint64_t));
            *oldlenp = sizeof(uint64_t);
        }
    } else if (name[1] == HW_NCPU || name[1] == 3 || name[1] == 7) {
        int fakeCpu = (int)[spoofer fakeCPUCount];
        if (oldlenp && oldp && *oldlenp >= sizeof(int)) {
            memcpy(oldp, &fakeCpu, sizeof(int));
            *oldlenp = sizeof(int);
        }
    }
    return ret;
}

// ========== IOKit Hook ==========
static CFTypeRef custom_IORegistryEntryCreateCFProperty(mach_port_t entry, CFStringRef property, CFAllocatorRef allocator, uint32_t options) {
    NSString *key = (__bridge NSString *)property;
    DeviceSpoofer *spoofer = [DeviceSpoofer shared];
    if ([key isEqualToString:@"board-id"]) {
        return CFBridgingRetain([spoofer fakeBoardID]);
    }
    if ([key isEqualToString:@"chip-id"]) {
        NSDictionary *info = [spoofer deviceInfoForModel:[spoofer fakeMachine]];
        NSString *chipID = info[@"chipID"];
        unsigned int val = 0;
        [[NSScanner scannerWithString:chipID] scanHexInt:&val];
        return CFBridgingRetain([NSData dataWithBytes:&val length:sizeof(val)]);
    }
    if ([key isEqualToString:@"IOPlatformSerialNumber"]) {
        return CFBridgingRetain([spoofer fakeSerialNumber]);
    }
    if ([key isEqualToString:@"IOPlatformUUID"]) {
        return CFBridgingRetain([spoofer fakeHardwareUUID]);
    }
    return orig_IORegistryEntryCreateCFProperty(entry, property, allocator, options);
}

// ========== MGCopyAnswer Hook ==========
static void* custom_MGCopyAnswer(CFStringRef property) {
    NSString *key = (__bridge NSString *)property;
    DeviceSpoofer *spoofer = [DeviceSpoofer shared];
    if ([key isEqualToString:@"SerialNumber"]) return (__bridge void *)[spoofer fakeSerialNumber];
    if ([key isEqualToString:@"MLBSerialNumber"]) return (__bridge void *)[spoofer fakeMLBSerial];
    if ([key isEqualToString:@"UniqueDeviceID"] || [key isEqualToString:@"UniqueChipID"])
        return (__bridge void *)[spoofer fakeSerialNumber];
    if ([key isEqualToString:@"IOPlatformUUID"] || [key isEqualToString:@"HardwareUUID"])
        return (__bridge void *)[spoofer fakeHardwareUUID];
    if ([key isEqualToString:@"ProductType"] || [key isEqualToString:@"hw.machine"])
        return (__bridge void *)[spoofer fakeMachine];
    if ([key isEqualToString:@"DeviceColor"]) return (__bridge void *)[NSString stringWithFormat:@"%d", arc4random_uniform(10)];
    if ([key isEqualToString:@"DeviceClass"]) {
        return (__bridge void *)([[spoofer fakeMachine] hasPrefix:@"iPhone"] ? @"iPhone" : @"iPad");
    }
    return orig_MGCopyAnswer ? orig_MGCopyAnswer(property) : NULL;
}

// ========== IDFA / IDFV Hook（使用 imp_implementationWithBlock） ==========
static void hookIDFA() {
    Class asManager = NSClassFromString(@"ASIdentifierManager");
    if (asManager) {
        SEL sel = @selector(advertisingIdentifier);
        Method m = class_getInstanceMethod(asManager, sel);
        IMP newImp = imp_implementationWithBlock(^id(id self) { return [NSUUID UUID]; });
        if (m) method_setImplementation(m, newImp);
        else class_addMethod(asManager, sel, newImp, "@@:");
    }
    Class uiDevice = [UIDevice class];
    SEL sel2 = @selector(identifierForVendor);
    Method m2 = class_getInstanceMethod(uiDevice, sel2);
    IMP newImp2 = imp_implementationWithBlock(^id(id self) { return [NSUUID UUID]; });
    if (m2) method_setImplementation(m2, newImp2);
    else class_addMethod(uiDevice, sel2, newImp2, "@@:");
}

// ========== 安装所有 Hook（使用 fishhook） ==========
- (void)installHooks {
    // 1. sysctl
    struct rebinding sysctl_bind = {"sysctl", (void *)custom_sysctl, (void **)&orig_sysctl};
    rebind_symbols(&sysctl_bind, 1);
    
    // 2. IOKit
    void *ioKit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (ioKit) {
        orig_IORegistryEntryCreateCFProperty = (CFTypeRef (*)(mach_port_t, CFStringRef, CFAllocatorRef, uint32_t))dlsym(ioKit, "IORegistryEntryCreateCFProperty");
        struct rebinding io_bind = {"IORegistryEntryCreateCFProperty", (void *)custom_IORegistryEntryCreateCFProperty, (void **)&orig_IORegistryEntryCreateCFProperty};
        rebind_symbols(&io_bind, 1);
        dlclose(ioKit);
    }
    
    // 3. MGCopyAnswer
    void *lib = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
    if (lib) {
        orig_MGCopyAnswer = (void* (*)(CFStringRef))dlsym(lib, "MGCopyAnswer");
        struct rebinding mg_bind = {"MGCopyAnswer", (void *)custom_MGCopyAnswer, (void **)&orig_MGCopyAnswer};
        rebind_symbols(&mg_bind, 1);
        dlclose(lib);
    }
    
    // 4. IDFA / IDFV
    hookIDFA();
}
@end
