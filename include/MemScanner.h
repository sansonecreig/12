#import <Foundation/Foundation.h>
#import "AdvancedMemAccess.h"

typedef NS_ENUM(NSUInteger, ScanValueType) {
    ScanTypeUInt8, ScanTypeUInt16, ScanTypeUInt32, ScanTypeUInt64,
    ScanTypeInt8, ScanTypeInt16, ScanTypeInt32, ScanTypeInt64,
    ScanTypeFloat, ScanTypeDouble
};

typedef NS_ENUM(NSUInteger, ScanComparison) {
    ScanCompEqual, ScanCompNotEqual, ScanCompGreater, ScanCompLess
};

@interface MemScanner : NSObject
+ (instancetype)sharedScanner;
- (void)cancelCurrentScan;
- (void)searchValue:(NSString *)valueStr type:(ScanValueType)type comparison:(ScanComparison)comp completion:(void(^)(NSArray<NSNumber *> *results, NSError *error))completion;
- (void)refineSearchWithValue:(NSString *)valueStr type:(ScanValueType)type comparison:(ScanComparison)comp completion:(void(^)(NSArray<NSNumber *> *results, NSError *error))completion;
- (void)clearResults;
- (BOOL)modifyAddress:(uint64_t)address value:(NSString *)valueStr type:(ScanValueType)type;
- (void)reset;
@end
