#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "DeviceSpoofer.h"
#import "NetworkInterceptor.h"

static UIView *panel = nil;
static BOOL panelVisible = NO;

static void togglePanel();
static void showDeviceMenu();

// 创建设备选择菜单
static void showDeviceMenu() {
    DeviceSpoofer *spoofer = [DeviceSpoofer shared];
    NSArray *allModels = [spoofer allSupportedModels];
    NSMutableArray *iphones = [NSMutableArray array];
    NSMutableArray *ipads = [NSMutableArray array];
    for (NSString *m in allModels) {
        if ([m hasPrefix:@"iPhone"]) [iphones addObject:m];
        else [ipads addObject:m];
    }
    [iphones sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [a compare:b options:NSNumericSearch];
    }];
    [ipads sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [a compare:b options:NSNumericSearch];
    }];
    
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Matrix 拓扑中枢"
                                                                   message:@"切换后自动洗机(重置Keychain)，需手动滑掉App冷启动"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *iphoneTitle = [UIAlertAction actionWithTitle:@"——— iPhone ———" style:UIAlertActionStyleDestructive handler:nil];
    iphoneTitle.enabled = NO;
    [sheet addAction:iphoneTitle];
    for (NSString *model in iphones) {
        NSString *name = [spoofer deviceInfoForModel:model][@"productName"];
        if (!name) name = model;
        UIAlertAction *action = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [spoofer applySpoofingWithModel:model completion:^(BOOL needsReboot) {
                if (needsReboot) {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"需要冷启动"
                                                                                   message:@"请手动从后台滑掉当前App并重新打开。"
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
                    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
                    [root presentViewController:alert animated:YES completion:nil];
                }
            }];
        }];
        [sheet addAction:action];
    }
    if (ipads.count) {
        UIAlertAction *ipadTitle = [UIAlertAction actionWithTitle:@"——— iPad ———" style:UIAlertActionStyleDestructive handler:nil];
        ipadTitle.enabled = NO;
        [sheet addAction:ipadTitle];
        for (NSString *model in ipads) {
            NSString *name = [spoofer deviceInfoForModel:model][@"productName"];
            if (!name) name = model;
            UIAlertAction *action = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [spoofer applySpoofingWithModel:model completion:^(BOOL needsReboot) {
                    if (needsReboot) {
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"需要冷启动"
                                                                                       message:@"请手动从后台滑掉当前App并重新打开。"
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
                        UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
                        [root presentViewController:alert animated:YES completion:nil];
                    }
                }];
            }];
            [sheet addAction:action];
        }
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (root) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            sheet.popoverPresentationController.sourceView = root.view;
            sheet.popoverPresentationController.sourceRect = CGRectMake(root.view.bounds.size.width/2, root.view.bounds.size.height/2, 1, 1);
        }
        [root presentViewController:sheet animated:YES completion:nil];
    }
}

// 显示/隐藏面板
static void togglePanel() {
    if (!panel) return;
    panelVisible = !panelVisible;
    panel.hidden = !panelVisible;
    if (panelVisible) {
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (keyWindow && panel.superview != keyWindow) {
            [panel removeFromSuperview];
            [keyWindow addSubview:panel];
        }
        [panel.superview bringSubviewToFront:panel];
    }
}

// 构建面板
static void buildPanel() {
    if (panel) [panel removeFromSuperview];
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return;
    
    panel = [[UIView alloc] initWithFrame:CGRectMake(10, 100, 260, 150)];
    panel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
    panel.layer.cornerRadius = 12;
    panel.layer.borderWidth = 1;
    panel.layer.borderColor = [UIColor whiteColor].CGColor;
    panel.hidden = YES;
    [keyWindow addSubview:panel];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 200, 30)];
    title.text = @"Matrix Aegis Lite";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:16];
    [panel addSubview:title];
    
    // 按钮事件处理对象
    static NSObject *btnTarget = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        btnTarget = [[NSObject alloc] init];
        class_addMethod([btnTarget class], @selector(showMenu), imp_implementationWithBlock(^(id self) { 
            showDeviceMenu(); 
        }), "v@:");
        class_addMethod([btnTarget class], @selector(closePanel), imp_implementationWithBlock(^(id self) { 
            togglePanel(); 
        }), "v@:");
    });
    
    UIButton *spoofBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    spoofBtn.frame = CGRectMake(10, 50, 240, 40);
    [spoofBtn setTitle:@"📱 切换设备型号" forState:UIControlStateNormal];
    spoofBtn.backgroundColor = [UIColor darkGrayColor];
    spoofBtn.layer.cornerRadius = 8;
    [spoofBtn addTarget:btnTarget action:@selector(showMenu) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:spoofBtn];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(220, 10, 30, 30);
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [closeBtn addTarget:btnTarget action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:closeBtn];
}

// 添加全局手势
static void addGlobalGesture() {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return;
    
    // 移除已有双指双击手势
    for (UIGestureRecognizer *g in keyWindow.gestureRecognizers) {
        if ([g isKindOfClass:[UITapGestureRecognizer class]]) {
            UITapGestureRecognizer *tap = (UITapGestureRecognizer *)g;
            if (tap.numberOfTouchesRequired == 2 && tap.numberOfTapsRequired == 2) {
                [keyWindow removeGestureRecognizer:g];
            }
        }
    }
    
    // 创建手势目标对象
    static NSObject *gestureTarget = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gestureTarget = [[NSObject alloc] init];
        class_addMethod([gestureTarget class], @selector(handleDoubleTwo), imp_implementationWithBlock(^(id self) {
            togglePanel();
        }), "v@:");
    });
    
    UITapGestureRecognizer *doubleTwo = [[UITapGestureRecognizer alloc] initWithTarget:gestureTarget action:@selector(handleDoubleTwo)];
    doubleTwo.numberOfTouchesRequired = 2;
    doubleTwo.numberOfTapsRequired = 2;
    [keyWindow addGestureRecognizer:doubleTwo];
}

static void appDidFinishLaunching(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        buildPanel();
        addGlobalGesture();
    });
}

%ctor {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [DeviceSpoofer shared];
    });
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL,
                                    appDidFinishLaunching,
                                    (CFStringRef)UIApplicationDidFinishLaunchingNotification,
                                    NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
