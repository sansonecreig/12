#import "DeviceSpoofer.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/utsname.h>

static DeviceSpoofer *sharedInstance = nil;

@interface DeviceSpoofer ()
@property (nonatomic, strong) NSString *spoofedModel;
@property (nonatomic, strong) NSDictionary *deviceDatabase;
@property (nonatomic, assign) BOOL hooksInstalled;
@end

@implementation DeviceSpoofer

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadDeviceDatabase];
        self.hooksInstalled = NO;
        // 不再在 init 中安装 Hook，改为延迟到 startHooking 调用
    }
    return self;
}

// 延迟 Hook 安装方法 - 在主线程延迟 0.5 秒后执行，避免 dyld 崩溃
- (void)startHooking {
    if (self.hooksInstalled) {
        return;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self installHooks];
        self.hooksInstalled = YES;
    });
}

- (void)installHooks {
    // Hook uname 系统调用
    static struct utsname originalUtsname;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        uname(&originalUtsname);
    });
    
    // 使用 fishhook 或 substitute 进行 Hook
    // 这里使用 method swizzling 作为示例
    
    // Hook NSProcessInfo
    Class processInfoClass = [NSProcessInfo class];
    Method originalMethod = class_getInstanceMethod(processInfoClass, @selector(machine));
    Method swizzledMethod = class_getInstanceMethod([self class], @selector(spoofedMachine));
    method_exchangeImplementations(originalMethod, swizzledMethod);
    
    // Hook UIDevice
    Class deviceClass = [UIDevice class];
    Method origModelMethod = class_getInstanceMethod(deviceClass, @selector(model));
    Method swizzledModelMethod = class_getInstanceMethod([self class], @selector(spoofedModel));
    method_exchangeImplementations(origModelMethod, swizzledModelMethod);
    
    // Hook sysctl
    // 这里需要使用 fishhook 或类似的库来 Hook C 函数
}

- (NSString *)spoofedMachine {
    if (self.spoofedModel) {
        return self.spoofedModel;
    }
    return [self spoofedMachine]; // 调用原方法
}

- (NSString *)spoofedModel {
    if (self.spoofedModel) {
        NSDictionary *info = [self deviceInfoForModel:self.spoofedModel];
        NSString *productName = info[@"productName"];
        if (productName) {
            return productName;
        }
    }
    return [self spoofedModel]; // 调用原方法
}

- (void)loadDeviceDatabase {
    // 加载设备数据库
    NSString *path = [[NSBundle mainBundle] pathForResource:@"DeviceDatabase" ofType:@"plist"];
    if (path) {
        self.deviceDatabase = [NSDictionary dictionaryWithContentsOfFile:path];
    } else {
        // 内置默认数据
        self.deviceDatabase = @{
            @"iPhone15,2": @{@"productName": @"iPhone 14 Pro", @"cpu": @"A16"},
            @"iPhone15,3": @{@"productName": @"iPhone 14 Pro Max", @"cpu": @"A16"},
            @"iPhone14,7": @{@"productName": @"iPhone 14", @"cpu": @"A15"},
            @"iPhone14,8": @{@"productName": @"iPhone 14 Plus", @"cpu": @"A15"},
            @"iPhone14,2": @{@"productName": @"iPhone 13 Pro", @"cpu": @"A15"},
            @"iPhone14,3": @{@"productName": @"iPhone 13 Pro Max", @"cpu": @"A15"},
            @"iPhone14,4": @{@"productName": @"iPhone 13 mini", @"cpu": @"A15"},
            @"iPhone14,5": @{@"productName": @"iPhone 13", @"cpu": @"A15"},
            @"iPhone13,1": @{@"productName": @"iPhone 12 mini", @"cpu": @"A14"},
            @"iPhone13,2": @{@"productName": @"iPhone 12", @"cpu": @"A14"},
            @"iPhone13,3": @{@"productName": @"iPhone 12 Pro", @"cpu": @"A14"},
            @"iPhone13,4": @{@"productName": @"iPhone 12 Pro Max", @"cpu": @"A14"},
            @"iPad13,4": @{@"productName": @"iPad Pro 11-inch (3rd gen)", @"cpu": @"M1"},
            @"iPad13,5": @{@"productName": @"iPad Pro 11-inch (3rd gen)", @"cpu": @"M1"},
            @"iPad13,6": @{@"productName": @"iPad Pro 12.9-inch (5th gen)", @"cpu": @"M1"},
            @"iPad13,7": @{@"productName": @"iPad Pro 12.9-inch (5th gen)", @"cpu": @"M1"},
            @"iPad13,8": @{@"productName": @"iPad Pro 12.9-inch (5th gen)", @"cpu": @"M1"},
            @"iPad13,9": @{@"productName": @"iPad Pro 12.9-inch (5th gen)", @"cpu": @"M1"},
            @"iPad13,10": @{@"productName": @"iPad Pro 12.9-inch (5th gen)", @"cpu": @"M1"},
            @"iPad13,11": @{@"productName": @"iPad Pro 12.9-inch (5th gen)", @"cpu": @"M1"},
            @"iPad14,1": @{@"productName": @"iPad mini (6th gen)", @"cpu": @"A15"},
            @"iPad14,2": @{@"productName": @"iPad mini (6th gen)", @"cpu": @"A15"},
        };
    }
}

- (NSArray *)allSupportedModels {
    return [self.deviceDatabase allKeys];
}

- (NSDictionary *)deviceInfoForModel:(NSString *)model {
    return self.deviceDatabase[model];
}

- (void)applySpoofingWithModel:(NSString *)model completion:(SpoofingCompletion)completion {
    self.spoofedModel = model;
    
    // 保存到 UserDefaults
    [[NSUserDefaults standardUserDefaults] setObject:model forKey:@"SpoofedDeviceModel"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 清除 Keychain（洗机）
    [self clearKeychain];
    
    if (completion) {
        completion(YES); // 需要重启
    }
}

- (void)clearKeychain {
    NSArray *secItemClasses = @[
        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecClassInternetPassword,
        (__bridge id)kSecClassCertificate,
        (__bridge id)kSecClassKey,
        (__bridge id)kSecClassIdentity
    ];
    
    for (id secItemClass in secItemClasses) {
        NSDictionary *spec = @{(__bridge id)kSecClass: secItemClass};
        SecItemDelete((__bridge CFDictionaryRef)spec);
    }
}

@end
