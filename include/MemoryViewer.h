#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MemoryViewer : NSObject
+ (void)showViewerForAddress:(uint64_t)address size:(NSUInteger)size;
+ (void)showViewerWithAddressPrompt;
@end
