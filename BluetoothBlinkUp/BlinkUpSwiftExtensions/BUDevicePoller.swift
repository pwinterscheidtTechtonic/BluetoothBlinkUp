//
//  DevicePoller.swift
//  BlinkUpSwiftSDK
//
//  Created by Brett Park on 2015-01-20.
//  Copyright (c) 2015 Electric Imp. All rights reserved.
//

import Foundation
import BlinkUp

extension BUDevicePoller {
  
  /**
  Swift specific implementation for polling to see if a device connected
  
  :param: responseHandler Closure that is called on success or failure of a BlinkUp attempt
  */
  public func startPollingWithHandler(_ responseHandler: @escaping (_ response:PollerResponse) -> ()) {
    self.startPolling { (deviceInfo, timedOut, error) -> Void in
      var response :PollerResponse
      switch(deviceInfo, timedOut, error) {
      case (_,_, let e) where e != nil:
        response = PollerResponse.error(e! as NSError)
      case(_,true,_):
        response = PollerResponse.timedOut
      default:
        response = PollerResponse.responded(deviceInfo!)
      }
      responseHandler(response)
    }
  }
  
  /**
  Swift specific enumeration of possible poller responses
  
  - Responded: The device connected. Contains information about the device.
  - TimedOut:  The poller timed out while waiting to hear from the device
  - Error:     Reason the imp did not connect (if known)
  */
  public enum PollerResponse {
    case responded(BUDeviceInfo)
    case timedOut
    case error(NSError)
  }
}
