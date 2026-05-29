#import "AESCryptoManager.h"
#import <CommonCrypto/CommonCrypto.h>
#import <Security/Security.h>

static NSString *const kAESKeychainService = @"com.matrix.aes";
static NSString *const kAESKeychainAccount = @"masterKey";

@implementation AESCryptoManager

+ (NSData *)loadOrCreateKey {
    NSDictionary *query = @{(id)kSecClass: (id)kSecClassGenericPassword, (id)kSecAttrService: kAESKeychainService, (id)kSecAttrAccount: kAESKeychainAccount, (id)kSecReturnData: @YES};
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecSuccess) return (__bridge NSData *)result;
    
    NSMutableData *newKey = [NSMutableData dataWithLength:kCCKeySizeAES256];
    SecRandomCopyBytes(kSecRandomDefault, newKey.length, newKey.mutableBytes);
    NSDictionary *add = @{(id)kSecClass: (id)kSecClassGenericPassword, (id)kSecAttrService: kAESKeychainService, (id)kSecAttrAccount: kAESKeychainAccount, (id)kSecValueData: newKey};
    SecItemAdd((__bridge CFDictionaryRef)add, NULL);
    return newKey;
}

+ (NSData *)encryptData:(NSData *)plainData {
    if (!plainData) return nil;
    NSData *key = [self loadOrCreateKey];
    NSMutableData *iv = [NSMutableData dataWithLength:kCCBlockSizeAES128];
    SecRandomCopyBytes(kSecRandomDefault, iv.length, iv.mutableBytes);
    
    size_t bufferSize = plainData.length + kCCBlockSizeAES128;
    NSMutableData *buffer = [NSMutableData dataWithLength:bufferSize];
    size_t numBytesEncrypted = 0;
    
    CCCryptorStatus status = CCCrypt(kCCEncrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
                                      key.bytes, key.length, iv.bytes,
                                      plainData.bytes, plainData.length,
                                      buffer.mutableBytes, bufferSize, &numBytesEncrypted);
    
    if (status == kCCSuccess) {
        [buffer setLength:numBytesEncrypted];
        NSMutableData *result = [NSMutableData dataWithData:iv];
        [result appendData:buffer];
        return result;
    }
    return nil;
}

+ (NSData *)decryptData:(NSData *)cipherData {
    if (!cipherData || cipherData.length < kCCBlockSizeAES128) return nil;
    NSData *key = [self loadOrCreateKey];
    
    NSData *iv = [cipherData subdataWithRange:NSMakeRange(0, kCCBlockSizeAES128)];
    NSData *encrypted = [cipherData subdataWithRange:NSMakeRange(kCCBlockSizeAES128, cipherData.length - kCCBlockSizeAES128)];
    
    size_t bufferSize = encrypted.length + kCCBlockSizeAES128;
    NSMutableData *buffer = [NSMutableData dataWithLength:bufferSize];
    size_t numBytesDecrypted = 0;
    
    CCCryptorStatus status = CCCrypt(kCCDecrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
                                      key.bytes, key.length, iv.bytes,
                                      encrypted.bytes, encrypted.length,
                                      buffer.mutableBytes, bufferSize, &numBytesDecrypted);
    
    if (status == kCCSuccess) {
        [buffer setLength:numBytesDecrypted];
        return buffer;
    }
    return nil;
}

+ (void)rotateKey {
    NSDictionary *query = @{(id)kSecClass: (id)kSecClassGenericPassword, (id)kSecAttrService: kAESKeychainService, (id)kSecAttrAccount: kAESKeychainAccount};
    SecItemDelete((__bridge CFDictionaryRef)query);
    [self loadOrCreateKey];
}

@end
