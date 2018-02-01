/*
 
 TSKPublicKeyAlgorithm.h
 TrustKit
 
 Copyright 2015 The TrustKit Project Authors
 Licensed under the MIT license, see associated LICENSE file for terms.
 See AUTHORS file for the list of project authors.
 
 */

#ifndef BUPublicKeyAlgorithm_h
#define BUPublicKeyAlgorithm_h

#import <Foundation/Foundation.h>

// The internal enum we use for public key algorithms; not to be confused with the exported TSKSupportedAlgorithm
typedef NS_ENUM(NSInteger, BUPublicKeyAlgorithm)
{
    // Some assumptions are made about this specific ordering in public_key_utils.m
    BUPublicKeyAlgorithmRsa2048 = 0,
    BUPublicKeyAlgorithmRsa4096 = 1,
    BUPublicKeyAlgorithmEcDsaSecp256r1 = 2,
    BUPublicKeyAlgorithmEcDsaSecp384r1 = 3,
    
    BUPublicKeyAlgorithmLast = BUPublicKeyAlgorithmEcDsaSecp384r1
};

#endif /* TSKPublicKeyAlgorithm_h */
