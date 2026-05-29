#import "MemoryViewer.h"
#import "AdvancedMemAccess.h"

@interface MemoryViewerViewController : UIViewController
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, assign) NSUInteger size;
@property (nonatomic, strong) UITextView *hexTextView;
@end

@implementation MemoryViewerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.95];
    
    UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:@"Memory Viewer"];
    navItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(dismiss)];
    navItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
    navBar.items = @[navItem];
    [self.view addSubview:navBar];
    
    _hexTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 54, self.view.bounds.size.width - 20, self.view.bounds.size.height - 64)];
    _hexTextView.backgroundColor = [UIColor blackColor];
    _hexTextView.textColor = [UIColor greenColor];
    _hexTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    _hexTextView.editable = NO;
    [self.view addSubview:_hexTextView];
    
    [self refresh];
}

- (void)dismiss { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)refresh {
    NSMutableString *output = [NSMutableString string];
    AdvancedMemAccess *mem = [AdvancedMemAccess sharedInstance];
    uint8_t buffer[16];
    
    for (NSUInteger offset = 0; offset < _size; offset += 16) {
        uint64_t currentAddr = _address + offset;
        NSUInteger bytesToRead = MIN(16, _size - offset);
        
        if ([mem readBytes:buffer atAddress:currentAddr size:bytesToRead]) {
            [output appendFormat:@"0x%08llX: ", currentAddr];
            for (NSUInteger i = 0; i < bytesToRead; i++) [output appendFormat:@"%02X ", buffer[i]];
            for (NSUInteger i = bytesToRead; i < 16; i++) [output appendString:@"   "];
            [output appendString:@" | "];
            for (NSUInteger i = 0; i < bytesToRead; i++) {
                char c = isprint(buffer[i]) ? buffer[i] : '.';
                [output appendFormat:@"%c", c];
            }
            [output appendString:@"\n"];
        } else {
            [output appendFormat:@"0x%08llX: <read failed>\n", currentAddr];
            break;
        }
    }
    _hexTextView.text = output;
}

@end

@implementation MemoryViewer

+ (void)showViewerForAddress:(uint64_t)address size:(NSUInteger)size {
    MemoryViewerViewController *vc = [[MemoryViewerViewController alloc] init];
    vc.address = address;
    vc.size = size;
    UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    [topVC presentViewController:vc animated:YES completion:nil];
}

+ (void)showViewerWithAddressPrompt {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Memory Viewer" message:@"Enter address (hex) and size (decimal)" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Address (e.g. 0x100000)";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Size in bytes";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"View" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *addrStr = alert.textFields[0].text;
        NSString *sizeStr = alert.textFields[1].text;
        uint64_t addr = strtoull(addrStr.UTF8String, NULL, 0);
        NSUInteger size = (NSUInteger)[sizeStr integerValue];
        if (size > 0 && size < 1024*1024) {
            [self showViewerForAddress:addr size:size];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

@end
