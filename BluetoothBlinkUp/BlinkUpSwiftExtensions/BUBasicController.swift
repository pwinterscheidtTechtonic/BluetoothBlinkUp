//
//  BUBasicController.swift
//  BlinkUpSwiftSDK
//
//  Created by Brett Park on 2015-04-27.
//  Copyright (c) 2015 Electric Imp Inc. All rights reserved.
//

import Foundation
import AVFoundation
import CoreGraphics
import OpenGLES
import QuartzCore
import Security
import SystemConfiguration
import BlinkUp

extension BUBasicController {
  
  /**
  Swift specific method for presenting the BlinkUp interface
  
  :param: animated       Animate the presentation of the controller
  :param: resignActive   Closure that is called when the BlinkUp interface reverts control
  :param: deviceResponse Closure that is called on success or failure of a device connection
  */
  public func presentInterfaceAnimated(_ animated: Bool, resignActive: @escaping (_ resignActiveResponse: ResignActiveResponse) -> (), deviceResponse: @escaping (_ deviceResponse: DeviceResponse) -> ()) {
    self.presentInterface(animated: animated, resignActive: BUBasicController.convertObjCResignActiveToSwift(resignActive), devicePollingDidComplete: BUBasicController.convertObjCDeviceResponseToSwift(deviceResponse))
  }
  
  /**
  Swift specific enumeration of results from the interface resigning active control
  
  - WillRespond:    The deviceResponse closure will be called
  - WillNotRespond: The deviceResponse closure will not be called
  - UserCancelled:  The user intentionally cancelled out of the interface
  - Error:          Reason for failure of a BlinkUp
  */
  public enum ResignActiveResponse {
    case willRespond
    case willNotRespond
    case userCancelled
    case error(NSError)
  }
  
  /**
  Swift specific enumeration of results from the device
  
  - Connected:     Information about the device if it connected successfully
  - DidNotConnect: No device information could be retrieved in the time allowed by the pollTimeout.
  - Error:         Reason the imp did not connect on failure
  */
  public enum DeviceResponse {
    case connected(BUDeviceInfo)
    case didNotConnect
    case error(NSError)
  }
  
  
  /**
  Swift Internal method for closure conversion
  */
  class internal func convertObjCResignActiveToSwift (_ resignActive: @escaping (_ resignResponse: ResignActiveResponse) -> ()) -> BUResignActiveBlock! {
    let resignActiveObjC: BUResignActiveBlock = { (willRespond, userDidCancel, error) -> Void in
      var response: ResignActiveResponse!
      switch (willRespond, userDidCancel, error) {
      case (_,_,let e) where e != nil:
        response = ResignActiveResponse.error(e! as NSError)
      case (_,true,_):
        response = ResignActiveResponse.userCancelled
      case (true, _, _):
        response = ResignActiveResponse.willRespond
      case (false, _, _):
        response = ResignActiveResponse.willNotRespond
      }
      
      resignActive(response)
    }
    
    return resignActiveObjC
  }
  
  /**
  Swift Internal method for closure conversion
  */
  class internal func convertObjCDeviceResponseToSwift (_ devicePollingDidComplete: @escaping (_ deviceResponse: DeviceResponse) -> ()) -> BUDevicePollingDidCompleteBlock! {
    let impeeDidConnectObjC: BUDevicePollingDidCompleteBlock = { (deviceInfo, timedOut, error) -> Void in
      var deviceResponse: DeviceResponse!
      switch (deviceInfo, timedOut, error) {
      case (_, _, let e) where e != nil:
        deviceResponse = DeviceResponse.error(error! as NSError)
      case (_, true, _) :
        deviceResponse = DeviceResponse.didNotConnect
      case (let data, _, _):
        deviceResponse = DeviceResponse.connected(data!)
      }
      devicePollingDidComplete(deviceResponse)
    }
    
    return impeeDidConnectObjC
  }
}
