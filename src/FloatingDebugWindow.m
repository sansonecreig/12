#import "FloatingDebugWindow.h"
#import "DeviceSpoofer.h"
#import "MemoryViewer.h"

@interface FloatingDebugViewController : UIViewController @end
@implementation FloatingDebugViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;
}
@end

@interface FloatingDebugWindow ()
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIViewController *strongVC;
@property (nonatomic, strong) UIButton *floatingDot;
@end

@implementation FloatingDebugWindow

+ (instancetype)sharedWindow {
    static FloatingDebugWindow *win = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIWindowScene *scene = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if (s.activationState == UISceneActivationStateForegroundActive && [s isKindOfClass:[UIWindowScene class]]) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
        }
        win = [[FloatingDebugWindow alloc] initWithWindowScene:scene];
        win.windowLevel = UIWindowLevelStatusBar + 100;
        win.backgroundColor = [UIColor clearColor];
        win.hidden = NO;
        win.strongVC = [[FloatingDebugViewController alloc] init];
        win.rootViewController = win.strongVC;
        [win setupUI];
    });
    return win;
}

- (instancetype)initWithWindowScene:(UIWindowScene *)scene {
    self = [super initWithWindowScene:scene];
    if (self) self.userInteractionEnabled = YES;
    return self;
}

- (void)setupUI {
    _panel = [[UIView alloc] initWithFrame:CGRectMake(10, 100, 280, 350)];
    _panel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
    _panel.layer.cornerRadius = 12;
    _panel.layer.borderWidth = 1;
    _panel.layer.borderColor = [UIColor whiteColor].CGColor;
    _panel.userInteractionEnabled = YES;
    _panel.hidden = YES;
    [self addSubview:_panel];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 200, 30)];
    titleLabel.text = @"Matrix Aegis";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [_panel addSubview:titleLabel];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(240, 10, 30, 30);
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(hidePanel) forControlEvents:UIControlEventTouchUpInside];
    [_panel addSubview:closeBtn];
    
    NSArray *buttons = @[
        @{@"title": @"📱 设备切换", @"action": @"showDeviceSpooferMenu"},
        @{@"title": @"🔍 内存查看器", @"action": @"showMemoryViewer"},
        @{@"title": @"🔎 内存扫描", @"action": @"showScanDemo"}
    ];
    
    for (int i = 0; i < buttons.count; i++) {
        NSDictionary *btnInfo = buttons[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(10, 50 + i * 50, 260, 40);
        [btn setTitle:btnInfo[@"title"] forState:UIControlStateNormal];
        btn.backgroundColor = [UIColor darkGrayColor];
        btn.layer.cornerRadius = 8;
        [btn addTarget:self action:NSSelectorFromString(btnInfo[@"action"]) forControlEvents:UIControlEventTouchUpInside];
        [_panel addSubview:btn];
    }
    
    _floatingDot = [UIButton buttonWithType:UIButtonTypeCustom];
    _floatingDot.frame = CGRectMake(20, 120, 40, 40);
    _floatingDot.backgroundColor = [UIColor redColor];
    _floatingDot.layer.cornerRadius = 20;
    _floatingDot.alpha = 0.7;
    [_floatingDot addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panDot:)];
    [_floatingDot addGestureRecognizer:pan];
    [self addSubview:_floatingDot];
    
    UITapGestureRecognizer *doubleTwoFinger = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(togglePanel)];
    doubleTwoFinger.numberOfTouchesRequired = 2;
    doubleTwoFinger.numberOfTapsRequired = 2;
    [self addGestureRecognizer:doubleTwoFinger];
}

- (void)togglePanel {
    _panel.hidden = !_panel.hidden;
    if (!_panel.hidden) [self bringSubviewToFront:_panel];
}

- (void)hidePanel { _panel.hidden = YES; }

- (void)panDot:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self];
    gesture.view.center = CGPointMake(gesture.view.center.x + translation.x, gesture.view.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self];
}

- (void)showDeviceSpooferMenu {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"设备切换" message:@"选择目标设备型号" preferredStyle:UIAlertControllerStyleActionSheet];
    DeviceSpoofer *spoofer = [DeviceSpoofer shared];
    for (NSString *model in [spoofer allSupportedModels]) {
        NSString *name = [spoofer deviceInfoForModel:model][@"productName"] ?: model;
        [sheet addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [spoofer applySpoofingWithModel:model completion:^(BOOL reboot) {
                if (reboot) {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已切换" message:@"请重启App生效" preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
                }
            }];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (rootVC) [rootVC presentViewController:sheet animated:YES completion:nil];
}

- (void)showMemoryViewer { [MemoryViewer showViewerWithAddressPrompt]; }

- (void)showScanDemo {
    UIAlertController *demo = [UIAlertController alertControllerWithTitle:@"内存扫描" message:@"请使用双指双击呼出面板扩展功能" preferredStyle:UIAlertControllerStyleAlert];
    [demo addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:demo animated:YES completion:nil];
}

@end
