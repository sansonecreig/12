#import "AdvancedMemAccess.h"
#import <mach/mach.h>

// Manually defining missing Mach VM types and functions (bypass SDK restriction)
typedef mach_vm_address_t vm_map_offset_t;
typedef mach_vm_size_t vm_map_size_t;

extern kern_return_t mach_vm_read_overwrite(
    vm_map_t target_task,
    mach_vm_address_t address,
    mach_vm_size_t size,
    mach_vm_address_t data,
    mach_vm_size_t *outsize
);

extern kern_return_t mach_vm_region(
    vm_map_t target_task,
    mach_vm_address_t *address,
    mach_vm_size_t *size,
    vm_region_flavor_t flavor,
    vm_region_info_t info,
    mach_msg_type_number_t *infoCnt,
    mach_port_t *object_name
);

extern kern_return_t mach_vm_protect(
    vm_map_t target_task,
    mach_vm_address_t address,
    mach_vm_size_t size,
    boolean_t set_maximum,
    vm_prot_t new_protection
);

extern kern_return_t mach_vm_write(
    vm_map_t target_task,
    mach_vm_address_t address,
    vm_offset_t data,
    mach_msg_type_number_t dataCnt
);

@interface AdvancedMemAccess () {
    dispatch_queue_t _accessQueue;
    mach_port_t _targetTask;
    pid_t _targetPID;
    MemAccessMode _mode;
}
@end

@implementation AdvancedMemAccess

+ (instancetype)sharedInstance {
    static AdvancedMemAccess *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ inst = [[AdvancedMemAccess alloc] init]; });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _accessQueue = dispatch_queue_create("com.mem.access", DISPATCH_QUEUE_SERIAL);
        _targetPID = getpid();
        _mode = MemAccessModeLocal;
        _targetTask = mach_task_self();
    }
    return self;
}

- (void)setMode:(MemAccessMode)mode pid:(pid_t)pid {
    dispatch_sync(_accessQueue, ^{
        if (_mode == MemAccessModeRemoteTask && _targetTask != MACH_PORT_NULL && _targetTask != mach_task_self()) {
            mach_port_deallocate(mach_task_self(), _targetTask);
        }
        _mode = mode;
        _targetPID = (mode == MemAccessModeLocal) ? getpid() : pid;
        if (mode == MemAccessModeRemoteTask && pid > 0) {
            kern_return_t kr = task_for_pid(mach_task_self(), pid, &_targetTask);
            if (kr != KERN_SUCCESS) {
                _mode = MemAccessModeLocal;
                _targetPID = getpid();
                _targetTask = mach_task_self();
            }
        } else {
            _targetTask = mach_task_self();
        }
    });
}

- (pid_t)currentPID {
    __block pid_t pid;
    dispatch_sync(_accessQueue, ^{ pid = _targetPID; });
    return pid;
}

- (mach_port_t)taskPort {
    __block mach_port_t port;
    dispatch_sync(_accessQueue, ^{ port = _targetTask; });
    return port;
}

- (BOOL)readBytes:(void *)buffer atAddress:(uint64_t)address size:(size_t)size {
    __block BOOL success = NO;
    dispatch_sync(_accessQueue, ^{
        kern_return_t kr = mach_vm_read_overwrite(_targetTask, (mach_vm_address_t)address, size, (mach_vm_address_t)buffer, (mach_vm_size_t *)&size);
        success = (kr == KERN_SUCCESS);
    });
    return success;
}

- (BOOL)writeBytes:(const void *)buffer atAddress:(uint64_t)address size:(size_t)size {
    __block BOOL success = NO;
    dispatch_sync(_accessQueue, ^{
        vm_prot_t originalProt = 0;
        mach_vm_address_t tmpAddr = address;
        mach_vm_size_t tmpSize = size;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
        kern_return_t kr = mach_vm_region(_targetTask, &tmpAddr, &tmpSize, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &infoCount, NULL);
        if (kr == KERN_SUCCESS) originalProt = info.protection;
        else originalProt = VM_PROT_READ|VM_PROT_EXECUTE;
        
        kr = mach_vm_protect(_targetTask, (mach_vm_address_t)address, size, FALSE, VM_PROT_READ|VM_PROT_WRITE|VM_PROT_COPY);
        if (kr == KERN_SUCCESS) {
            kr = mach_vm_write(_targetTask, (mach_vm_address_t)address, (vm_offset_t)buffer, (mach_msg_type_number_t)size);
            if (kr == KERN_SUCCESS) success = YES;
            mach_vm_protect(_targetTask, (mach_vm_address_t)address, size, FALSE, originalProt);
        }
    });
    return success;
}

- (NSData *)readRegionAtAddress:(uint64_t)address size:(size_t)size {
    if (size == 0) return nil;
    NSMutableData *data = [NSMutableData dataWithLength:size];
    if ([self readBytes:data.mutableBytes atAddress:address size:size]) return data;
    return nil;
}

- (void)reset {
    dispatch_sync(_accessQueue, ^{
        if (_targetTask != MACH_PORT_NULL && _targetTask != mach_task_self()) {
            mach_port_deallocate(mach_task_self(), _targetTask);
        }
        _targetTask = mach_task_self();
        _mode = MemAccessModeLocal;
        _targetPID = getpid();
    });
}

@end
