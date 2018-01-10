//
//  BUNetworkSelectController.swift
//  BlinkUpSwiftSDK
//
//  Created by Brett Park on 2015-04-27.
//  Copyright (c) 2015 Electric Imp Inc. All rights reserved.
//

import Security
import SystemConfiguration
import BlinkUp

extension BUNetworkSelectController {
  
  /**
  Swift enumeration of network selection response
  
  - UserDidCancel:   The user intentionally cancelled out of the interface
  - NetworkSelected: The user selected a network (or a clear action)
  */
  public enum InterfaceResponse {
    case userDidCancel
    case networkSelected(BUNetworkConfig)
  }
  
  /**
  Swift specfic method to gather network information from the user
  
  :param: animated         Animate the presentation
  :param: completionHander Executed immediatly after control is returned from the interface
  */
  public func presentInterfaceAnimated(_ animated:Bool, completionHander:@escaping (_ response:InterfaceResponse) -> ()) {    
    self.presentInterface(animated: animated) { (networkConfig:BUNetworkConfig?, userDidCancel:Bool) -> Void in
      var response: InterfaceResponse
      switch (networkConfig, userDidCancel) {
      case (_,true):
        response = InterfaceResponse.userDidCancel
      default:
        response = InterfaceResponse.networkSelected(networkConfig!)
      }
      completionHander(response)
    }
  }

  
}
