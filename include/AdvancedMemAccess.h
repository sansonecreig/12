#import <Foundation/Foundation.h>
#import <mach/mach.h>

typedef NS_ENUM(NSUInteger, MemAccessMode) {
    MemAccessModeLocal,
    MemAccessModeRemoteTask
};

@interface AdvancedMemAccess : NSObject
+ (instancetype)sharedInstance;
- (void)setMode:(MemAccessMode)mode pid:(pid_t)pid;
- (pid_t)currentPID;
- (mach_port_t)taskPort;
- (BOOL)readBytes:(void *)buffer atAddress:(uint64_t)address size:(size_t)size;
- (BOOL)writeBytes:(const void *)buffer atAddress:(uint64_t)address size:(size_t)size;
- (NSData *)readRegionAtAddress:(uint64_t)address size:(size_t)size;
- (void)reset;
@end
