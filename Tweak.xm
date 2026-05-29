#import "DeviceSpoofer.h"
#import "NetworkInterceptor.h"

@interface FloatingWindow : UIWindow
+ (instancetype)shared;
- (void)showDeviceMenu;
@end

@implementation FloatingWindow {
    UIButton *_dot;
    UIView *_panel;
}

+ (instancetype)shared {
    static FloatingWindow *win = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        win = [[FloatingWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        win.windowLevel = UIWindowLevelAlert + 1;
        win.backgroundColor = [UIColor clearColor];
        win.hidden = NO;
        win.rootViewController = [[UIViewController alloc] init];
        [win setupUI];
    });
    return win;
}

- (void)setupUI {
    _dot = [UIButton buttonWithType:UIButtonTypeCustom];
    _dot.frame = CGRectMake(20, 120, 44, 44);
    _dot.backgroundColor = [UIColor redColor];
    _dot.layer.cornerRadius = 22;
    _dot.alpha = 0.7;
    [_dot addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panDot:)];
    [_dot addGestureRecognizer:pan];
    [self addSubview:_dot];
    
    _panel = [[UIView alloc] initWithFrame:CGRectMake(10, 100, 260, 150)];
    _panel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
    _panel.layer.cornerRadius = 12;
    _panel.layer.borderWidth = 1;
    _panel.layer.borderColor = [UIColor whiteColor].CGColor;
    _panel.hidden = YES;
    [self addSubview:_panel];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 200, 30)];
    title.text = @"Matrix Aegis Lite";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:16];
    [_panel addSubview:title];
    
    UIButton *spoofBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    spoofBtn.frame = CGRectMake(10, 50, 240, 40);
    [spoofBtn setTitle:@"📱 切换设备型号" forState:UIControlStateNormal];
    spoofBtn.backgroundColor = [UIColor darkGrayColor];
    spoofBtn.layer.cornerRadius = 8;
    [spoofBtn addTarget:self action:@selector(showDeviceMenu) forControlEvents:UIControlEventTouchUpInside];
    [_panel addSubview:spoofBtn];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(220, 10, 30, 30);
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(hidePanel) forControlEvents:UIControlEventTouchUpInside];
    [_panel addSubview:closeBtn];
    
    UITapGestureRecognizer *doubleTwo = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(togglePanel)];
    doubleTwo.numberOfTouchesRequired = 2;
    doubleTwo.numberOfTapsRequired = 2;
    [self addGestureRecognizer:doubleTwo];
}

- (void)togglePanel {
    _panel.hidden = !_panel.hidden;
    if (!_panel.hidden) [self bringSubviewToFront:_panel];
}

- (void)hidePanel { _panel.hidden = YES; }

- (void)panDot:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self];
    g.view.center = CGPointMake(g.view.center.x + t.x, g.view.center.y + t.y);
    [g setTranslation:CGPointZero inView:self];
}

- (void)showDeviceMenu {
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
                                                                   message:@"切换后自动洗机，需手动滑掉App冷启动"
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
                    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
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
                        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
                    }
                }];
            }];
            [sheet addAction:action];
        }
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = self;
        sheet.popoverPresentationController.sourceRect = self.bounds;
    }
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (root) [root presentViewController:sheet animated:YES completion:nil];
}

@end

static void appDidFinishLaunching(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FloatingWindow shared] setHidden:NO];
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
