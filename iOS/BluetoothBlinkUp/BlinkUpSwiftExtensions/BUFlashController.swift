//
//  BUFlashController.swift
//  BlinkUpSwiftSDK
//
//  Created by Brett Park on 2015-04-27.
//  Copyright (c) 2015 Electric Imp Inc. All rights reserved.
//

import AVFoundation
import CoreGraphics
import OpenGLES
import QuartzCore
import BlinkUp

extension BUFlashController {
  /**
  Swift enumeration of flash results
  
  - CompletedWithoutPoller: The flash completed but a poller was not created.
  This is often due to non-configuration flash types such as clearing
  - CompletedWithPoller:    The flash completed and a poller has been created
  - Error:                  An error has occured during the flash process
  */
  public enum FlashResponse {
    case completedWithoutPoller
    case completedWithPoller(BUDevicePoller)
    case error(NSError)
  }
  
  /**
  Swift specific method for performing a BlinkUp
  
  :param: networkConfig he WifiConfig, WpsConfig, or ClearConfig that is to
    be performed.
  :param: configId      The single use configId for this flashing session. This
    can be nil in the case of clearing a device
  :param: animated      Should the presentation be animated
  :param: resignActive  Closure that is executed when the BlinkUp screen is
    dismissed and control is returned to the presenting screen
  */
  public func presentFlashWithNetworkConfig (_ networkConfig: BUNetworkConfig, configId:BUConfigId?, animated:Bool, resignActive :@escaping (_ flashResponse: FlashResponse) -> () )
  {
    self.presentFlash(with: networkConfig, configId: configId, animated: animated) { (willRespond, poller, error) -> Void in
      var response :FlashResponse
      switch(willRespond, poller, error) {
      case(_,_,let e) where e != nil:
        response = FlashResponse.error(e! as NSError)
      case(false, _, _):
        response = FlashResponse.completedWithoutPoller
      default:
        response = FlashResponse.completedWithPoller(poller!)
      }
      
      resignActive(response)
    }
  }
}
