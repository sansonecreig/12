#import <Foundation/Foundation.h>

@interface AESCryptoManager : NSObject
+ (NSData *)encryptData:(NSData *)plainData;
+ (NSData *)decryptData:(NSData *)cipherData;
+ (void)rotateKey;
@end
