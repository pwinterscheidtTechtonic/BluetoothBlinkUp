//
//  BUPinningSPKIData.h
//  BlinkUp
//
//  Created by Brett Park on 2018-01-28.
//  Copyright © 2018 Electric Imp, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


/**
 Information about the SPKI data for pinning
 */
@interface BUPinningSPKIData : NSObject

/**
 The pin in either base64 or hex format
 */
@property (nonnull, nonatomic, strong) NSString * pin;

/**
 Bool indicating if the pin is in base 64 format
 */
@property (assign) BOOL isBase64;

/**
 Bool indication if the pin is in hex format
 */
@property (assign) BOOL isHexString;

/**
 The supported Public Key Algorithms for the certificate
 */
@property (nonnull, nonatomic, strong) NSArray<NSNumber *> *supportedAlgorithms; // = @[@(0)];

/**
 Create the SPKI pin data from a hex string

 @param pin The pin in hex format
 @param pubKeyAlg An array of BUPublicKeyAlgorithm values
 @return The SPKI pin data
 */
- (instancetype _Nonnull )initWithHexString:(NSString *_Nonnull) pin algorithms: (NSArray<NSNumber *> *_Nonnull) pubKeyAlg;

/**
 Create the SPKI pin data from a base 64 string
 
 @param pin The pin in base 64 format
 @param pubKeyAlg An array of BUPublicKeyAlgorithm values
 @return The SPKI pin data
 */
- (instancetype _Nonnull )initWithBase64:(NSString *_Nonnull) pin algorithms: (NSArray<NSNumber *> *_Nonnull) pubKeyAlg;


/**
 The pin as a data object (translate both base64 and hex)

 @return NSData of the pin
 */
-(NSData *_Nonnull) pinAsData;
@end
