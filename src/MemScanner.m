#import "MemScanner.h"
#include <stdatomic.h>
#import <mach/mach.h>
#import <os/lock.h>

#define SCAN_PAGE_SIZE (1024 * 1024)

// Manually bypass the SDK block for mach_vm_region
typedef mach_vm_address_t vm_map_offset_t;
typedef mach_vm_size_t vm_map_size_t;

extern kern_return_t mach_vm_region(
    vm_map_t target_task,
    mach_vm_address_t *address,
    mach_vm_size_t *size,
    vm_region_flavor_t flavor,
    vm_region_info_t info,
    mach_msg_type_number_t *infoCnt,
    mach_port_t *object_name
);

@interface MemScanner () {
    dispatch_queue_t _scanQueue;
    NSMutableArray<NSNumber *> *_lastResults;
    os_unfair_lock _resultsLock;
    atomic_bool _shouldCancel;
}
@end

static size_t sizeOfType(ScanValueType type) {
    switch (type) {
        case ScanTypeUInt8: case ScanTypeInt8: return 1;
        case ScanTypeUInt16: case ScanTypeInt16: return 2;
        case ScanTypeUInt32: case ScanTypeInt32: case ScanTypeFloat: return 4;
        case ScanTypeUInt64: case ScanTypeInt64: case ScanTypeDouble: return 8;
    }
}

@implementation MemScanner

+ (instancetype)sharedScanner {
    static MemScanner *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ inst = [[MemScanner alloc] init]; });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _scanQueue = dispatch_queue_create("com.scan.queue", DISPATCH_QUEUE_SERIAL);
        _resultsLock = OS_UNFAIR_LOCK_INIT;
        atomic_store(&_shouldCancel, false);
    }
    return self;
}

- (void)cancelCurrentScan { atomic_store(&_shouldCancel, true); }
- (void)clearResults {
    os_unfair_lock_lock(&_resultsLock);
    _lastResults = nil;
    os_unfair_lock_unlock(&_resultsLock);
}
- (void)reset { [self cancelCurrentScan]; [self clearResults]; }

- (BOOL)modifyAddress:(uint64_t)address value:(NSString *)valueStr type:(ScanValueType)type {
    NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
    NSNumber *num = [fmt numberFromString:valueStr];
    if (!num) return NO;
    
    size_t valSize = sizeOfType(type);
    void *newVal = malloc(valSize);
    switch (type) {
        case ScanTypeUInt8: *(uint8_t *)newVal = num.unsignedCharValue; break;
        case ScanTypeUInt32: *(uint32_t *)newVal = num.unsignedIntValue; break;
        case ScanTypeUInt64: *(uint64_t *)newVal = num.unsignedLongLongValue; break;
        case ScanTypeFloat: *(float *)newVal = num.floatValue; break;
        case ScanTypeDouble: *(double *)newVal = num.doubleValue; break;
        default: free(newVal); return NO;
    }
    BOOL success = [[AdvancedMemAccess sharedInstance] writeBytes:newVal atAddress:address size:valSize];
    free(newVal);
    return success;
}

- (void)searchValue:(NSString *)valueStr type:(ScanValueType)type comparison:(ScanComparison)comp completion:(void(^)(NSArray<NSNumber *> *, NSError *))completion {
    [self performSearchWithValue:valueStr type:type comparison:comp addressList:nil completion:completion];
}

- (void)refineSearchWithValue:(NSString *)valueStr type:(ScanValueType)type comparison:(ScanComparison)comp completion:(void(^)(NSArray<NSNumber *> *, NSError *))completion {
    os_unfair_lock_lock(&_resultsLock);
    NSArray *prev = _lastResults;
    os_unfair_lock_unlock(&_resultsLock);
    if (!prev) [self searchValue:valueStr type:type comparison:comp completion:completion];
    else [self performSearchWithValue:valueStr type:type comparison:comp addressList:prev completion:completion];
}

- (void)performSearchWithValue:(NSString *)valueStr type:(ScanValueType)type comparison:(ScanComparison)comp addressList:(NSArray<NSNumber *> *)previousAddresses completion:(void(^)(NSArray<NSNumber *> *, NSError *))completion {
    dispatch_async(_scanQueue, ^{
        atomic_store(&self->_shouldCancel, false);
        NSMutableArray *results = [NSMutableArray array];
        AdvancedMemAccess *mem = [AdvancedMemAccess sharedInstance];
        
        if (previousAddresses == nil) {
            mach_vm_address_t addr = 0;
            mach_vm_size_t size = 0;
            vm_region_basic_info_data_64_t info;
            mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
            
            while (1) {
                if (atomic_load(&self->_shouldCancel)) break;
                mach_port_t task = [mem taskPort];
                kern_return_t kr = mach_vm_region(task, &addr, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &infoCount, NULL);
                if (kr != KERN_SUCCESS) break;
                
                if ((info.protection & VM_PROT_READ) && size > 0) {
                    size_t readSize = MIN(size, SCAN_PAGE_SIZE);
                    NSData *pageData = [mem readRegionAtAddress:addr size:readSize];
                    if (pageData) {
                        [results addObject:@(addr)];
                    }
                }
                addr += size;
            }
        } else {
            for (NSNumber *addrNum in previousAddresses) {
                if (atomic_load(&self->_shouldCancel)) break;
                [results addObject:addrNum];
            }
        }
        
        if (!atomic_load(&self->_shouldCancel)) {
            os_unfair_lock_lock(&self->_resultsLock);
            self->_lastResults = [results copy];
            os_unfair_lock_unlock(&self->_resultsLock);
        }
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(results, nil); });
    });
}

@end
