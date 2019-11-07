
//  Device.swift
//  BluetoothBlinkUp
//
//  Created by Tony Smith on 12/14/17.
//
//  MIT License
//
//  Copyright 2017-19 Electric Imp
//
//  Version 1.3.0
//
//  SPDX-License-Identifier: MIT
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
//  OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
//  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.



import Foundation
import CoreBluetooth


class Device: NSObject {

    // This is a simple class that's use to record the details of a discovered
    // imp-based device. We use a class rather than an enum so that we
    // can access it by reference rather than the item itself

    var name: String = ""
    var type: String = ""
    var agent: String = ""
    var devID: String = "TBD"
    var version: String = ""
    var peripheral: CBPeripheral!
    var characteristics: [CBCharacteristic] = []
    var isConnected: Bool = false

}
