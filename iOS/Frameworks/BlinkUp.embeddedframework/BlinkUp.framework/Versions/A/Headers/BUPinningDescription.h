//
//  BUPinningDescription.h
//  BlinkUp
//
//  Created by Brett Park on 2018-01-28.
//  Copyright © 2018 Electric Imp, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BUPinningSPKIData;

/**
 The pinning description describes valid SPKI data for a hostname and its subdomains
 */
@interface BUPinningDescription : NSObject

/**
 The hostname of the server you are connecting to
 */
@property (nonatomic,readwrite,strong) NSString * hostname;

/**
 Any subdomains you also want the pin to apply to. A "*" can be used as a wildcard.
 */
@property (nonatomic,readwrite,strong) NSArray<NSString *> * subdomains;

/**
 The valid pins for the host
 */
@property (nonatomic,readwrite,strong) NSArray<BUPinningSPKIData *> * pins;

-(instancetype) initWithHostname:(NSString *) hostname;


/**
 The default pinning descriptions for electricimp.com

 @return The default pinnings to use
 */
+(NSArray<BUPinningDescription *> *) electricImpDefaults;
@end
