/******************************************************************************
 * - Copyright Electric Imp, Inc. 2015. All rights reserved.
 * - License: All Rights Reserved
 *
 * Global header for the BlinkUp SDK
 *
 */

// SDK v19.7.1

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/*!
 *  @brief SDK Version number as double
 */
static double BlinkUpVersionNumber = 19.0701;

/*!
 *  @brief SDK version number as string
 */
static NSString *const BlinkUpVersionString = @"19.7.1";

#import <BlinkUp/BUSDKFeatures.h>
#import <BlinkUp/BUBasicController.h>
#import <BlinkUp/BUConfigId.h>
#import <BlinkUp/BUDeviceInfo.h>
#import <BlinkUp/BUDevicePoller.h>
#import <BlinkUp/BUErrors.h>
#import <BlinkUp/BUErrorStringParameters.h>
#import <BlinkUp/BUFlashController.h>
#import <BlinkUp/BUFlashStringParameters.h>
#import <BlinkUp/BUNetworkManager.h>
#import <BlinkUp/BUNetworkSelectController.h>
#import <BlinkUp/BUNetworkSelectStringParameters.h>
#import <BlinkUp/BUSDKFeatures.h>
#import <BlinkUp/BUNetworkAddressing.h>
#import <BlinkUp/BUStaticAddressing.h>
#import <BlinkUp/BUDHCPAddressing.h>
#import <BlinkUp/BUNetworkProxy.h>
#import <BlinkUp/BUHelper.h>
#import <BlinkUp/BUPublicKeyAlgorithm.h>
#import <BlinkUp/BUPinningDescription.h>
#import <BlinkUp/BUPinningSPKIData.h>
