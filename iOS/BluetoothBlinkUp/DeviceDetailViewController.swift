
//  ViewController.swift
//  BluetoothBlinkUp
//
//  Created by Tony Smith on 12/14/17.
//
//  MIT License
//
//  Copyright 2017-18 Electric Imp
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



import UIKit
import CoreBluetooth
import BlinkUp


class DeviceDetailViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {

    // UI Outlets
    @IBOutlet weak var sendLabel: UILabel!
    @IBOutlet weak var blinkUpProgressBar: UIActivityIndicatorView!
    @IBOutlet weak var wifiPicker: UIPickerView!
    @IBOutlet weak var passwordField: UITextField!

    // Properties
    var bluetoothManager: CBCentralManager!
    var device: Device? = nil
    var characteristics: [CBCharacteristic]? = nil
    var availableNetworks: [ [String] ] = []
    var config: BUConfigId? = nil
    var connected: Bool = false
    var blinking: Bool = false
    var harvey: String!

    override func viewDidLoad() {

        super.viewDidLoad()

        // Set up the 'show password' button within the password entry field
        let overlayButton: UIButton = UIButton.init(type: UIButtonType.custom)
        overlayButton.setImage(UIImage.init(named: "button_eye"), for: UIControlState.normal)
        overlayButton.addTarget(self, action: #selector(self.showPassword(_:)), for: UIControlEvents.touchUpInside)
        overlayButton.frame = CGRect.init(x: 0, y: 6, width: 20, height: 16)

        // Assign the overlay button to a stored text field
        self.passwordField.leftView = overlayButton
        self.passwordField.leftViewMode = UITextFieldViewMode.always

        // Start watching for the app re-activating
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(appWillEnterForeground), name: NSNotification.Name.init("appwillenterforeground"), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)
        initUI()
        initNetworks()
    }

    override func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)

        // Get the networks from the device
        if let aDevice: Device = device {
            // NOTE We need to set the objects' delegates to 'self' so that the correct delegate functions are called
            aDevice.peripheral.delegate = self
            self.bluetoothManager.delegate = self
            self.bluetoothManager.connect(aDevice.peripheral, options: nil)
        }
    }

    @objc func appWillEnterForeground() {

        // App is about to come back into view after the user previously
        // switched to a different app, so reset the UI - unless we're blinking
        if !self.blinking {
            if self.connected {
                if let aDevice: Device = self.device {
                    self.bluetoothManager.cancelPeripheralConnection(aDevice.peripheral)
                    self.connected = false
                }
            }

            initUI()
            initNetworks()
        }
    }

    func initUI() {

        // Initialise the UI
        self.blinkUpProgressBar.stopAnimating()
        self.sendLabel.text = ""
    }

    func initNetworks() {

        // Add a placeholder network name
        self.availableNetworks.removeAll()
        self.availableNetworks.append(["None", "unlocked"])

        // Set the UI - disabling the picker
        wifiPicker.reloadAllComponents()
        wifiPicker.isUserInteractionEnabled = false
        wifiPicker.alpha = 0.5
    }

    @objc func goBack() {

        // Stop listening for 'will enter foreground' notifications
        NotificationCenter.default.removeObserver(self)

        if self.connected {
            if let aDevice: Device = self.device {
                self.bluetoothManager.cancelPeripheralConnection(aDevice.peripheral)
                self.connected = false
            }
        }

        // Jump back to the list of devices
        self.navigationController!.popViewController(animated: true)
    }

    @IBAction func doBlinkup(_ sender: Any) {

        // Do we have the data we need, ie. a password for a locked network?
        let index = self.wifiPicker.selectedRow(inComponent: 0)
        let network = self.availableNetworks[index]

        if network[1] == "locked" && self.passwordField.text!.isEmpty {
            self.showAlert("This network requires a password", "You need to enter a password for a locked network.")
            return
        }

        if network[0] == "None" {
            self.showAlert("There are no networks to connect to", "")
            return
        }



        self.blinkUpProgressBar.startAnimating()

        if !self.connected {
            // App is not connected to the peripheral
            if let aDevice = self.device {
                self.blinking = true

                self.bluetoothManager.connect(aDevice.peripheral, options: nil)
                // Pick up the action at didConnect(), which is called when the
                // iDevice has connected to the imp004m
            }
        } else {
            // App is already connected to the peripheral
            if !self.blinking {
                // App is not performing BlinkUp, so start it now
                blinkupStageTwo()
            }
        }
    }

    func blinkupStageTwo() {

        // Use the BlinkUp SDK to retrieve an enrollment token and a plan ID from the user's API Key
        // You will need to be an Electric Imp customer with a BlinkUp API Key to make this work

        if self.connected {
            // We're good to proceed so begin BlinkUp
            sendLabel.text = "Sending BlinkUp data"
            
            // Get a BUConfigID
            let _ = BUConfigId.init(apiKey: self.harvey) { (_ config: BUConfigId.ConfigIdResponse) -> Void in
                // 'config' is the response to the creation of the BUConfigID
                // It has two possible values:
                //    .activated (passes in the active BUConfigID)
                //    .error     (passes in an NSError)
                switch config {
                case .activated(let activeConfig):
                    self.sendLabel.text = "Sending BlinkUp..."
                    self.config = activeConfig

                    if let aDevice = self.device {
                        // Get the data for the current network and prep for sending
                        let index = self.wifiPicker.selectedRow(inComponent: 0)
                        let network = self.availableNetworks[index]
                        let sdata:Data? = network[0].data(using: String.Encoding.utf8)
                        let pdata:Data? = self.passwordField.text!.data(using: String.Encoding.utf8)
                        let tdata:Data? = activeConfig.token.data(using: String.Encoding.utf8)
                        let idata:Data? = activeConfig.planId!.data(using: String.Encoding.utf8)

                        // Work through the characteristic list for the service,
                        // to match them to known UUIDs so we send the correct data to the imp004m
                        // First the SSID
                        if let list = self.characteristics {
                            for i in 0..<list.count {
                                let ch:CBCharacteristic? = list[i]
                                if ch != nil {
                                    if ch!.uuid.uuidString == "5EBA1956-32D3-47C6-81A6-A7E59F18DAC0" {
                                        if let s = sdata {
                                            // At the first GATT write (or read) iOS will handle pairing.
                                            // If the user hits cancel, we will not be allowed to write, but if pairing succeeds,
                                            // the following write will be made, and 'peripheral(_, didWriteValueFor, error)' called
                                            aDevice.peripheral.writeValue(s, for:ch!, type:CBCharacteristicWriteType.withResponse)
                                        }
                                        break
                                    }
                                }
                            }

                            // Send the network password
                            for i in 0..<list.count {
                                let ch:CBCharacteristic? = list[i];

                                if ch != nil {
                                    if ch!.uuid.uuidString == "ED694AB9-4756-4528-AA3A-799A4FD11117" {
                                        if let s = pdata {
                                            aDevice.peripheral.writeValue(s, for:ch!, type:CBCharacteristicWriteType.withResponse)
                                        }
                                        break
                                    }
                                }
                            }

                            // Now the token
                            for i in 0..<list.count {
                                let ch:CBCharacteristic? = list[i];

                                if ch != nil {
                                    if ch!.uuid.uuidString == "BD107D3E-4878-4F6D-AF3D-DA3B234FF584" {
                                        if let s = tdata {
                                            aDevice.peripheral.writeValue(s, for:ch!, type:CBCharacteristicWriteType.withResponse)
                                        }
                                        break
                                    }
                                }
                            }

                            // Now the planid
                            for i in 0..<list.count {
                                let ch:CBCharacteristic? = list[i];

                                if ch != nil {
                                    if ch!.uuid.uuidString == "A90AB0DC-7B5C-439A-9AB5-2107E0BD816E" {
                                        if let s = idata {
                                            aDevice.peripheral.writeValue(s, for:ch!, type:CBCharacteristicWriteType.withResponse)
                                        }
                                        break
                                    }
                                }
                            }

                            // And finally the characteristic that triggers the WiFi refresh on the imp004m
                            for i in 0..<list.count {
                                let ch:CBCharacteristic? = list[i];

                                if ch != nil {
                                    if ch!.uuid.uuidString == "F299C342-8A8A-4544-AC42-08C841737B1B" {
                                        if let s = sdata {
                                            aDevice.peripheral.writeValue(s, for:ch!, type:CBCharacteristicWriteType.withResponse)
                                        }
                                        break
                                    }
                                }
                            }
                        }

                        // Update the UI
                        self.sendLabel.text = "Waiting for device to enrol"
                        self.blinking = false

                        // Begin polling the server for an indication that the device
                        // has connected and been enrolled
                        let poller = BUDevicePoller.init(configId: activeConfig)
                        poller.startPollingWithHandler({ (response) in
                            switch(response) {
                            case .responded(let info):
                                // The server indicates that the device has enrolled successfully, so we're done
                                let na: String = "N/A"
                                let actionMenu = UIAlertController.init(title: "Device \(info.deviceId ?? na)\nHas Connected", message: "Your device has enrolled into the Electric Imp impCloud™. It is accessible at\n\(info.agentURL?.absoluteString ?? na)", preferredStyle: UIAlertControllerStyle.actionSheet)
                                var action: UIAlertAction = UIAlertAction.init(title: "Copy URL", style: UIAlertActionStyle.default) { (alertAction) in
                                        if let us = info.agentURL?.absoluteString {
                                            let pb: UIPasteboard = UIPasteboard.general
                                            pb.setValue(us, forPasteboardType: "public.text")
                                        }
                                    }
                                actionMenu.addAction(action)
                                action = UIAlertAction.init(title: "OK", style: UIAlertActionStyle.cancel, handler:nil)
                                actionMenu.addAction(action)
                                self.present(actionMenu, animated: true, completion: nil)
                                self.sendLabel.text = ""
                                self.blinkUpProgressBar.stopAnimating()
                            case .error(let error):
                                // Something went wrong, so dump the error and perform the timed out flow
                                NSLog(error.description)
                                fallthrough
                            case .timedOut:
                                // The server took too long to respond, so assume enrollment did not take place
                                self.showAlert("Device Failed to Connect", "Your device has not enrolled in the impCloud")
                                self.sendLabel.text = ""
                                self.blinkUpProgressBar.stopAnimating()
                            }

                            // Done blinking, so cancel the connection (best practice to save battery power)
                            if let aDevice = self.device {
                                self.bluetoothManager.cancelPeripheralConnection(aDevice.peripheral)
                                self.connected = false
                            }
                        })
                    }

                    // We exit here, but will pick up writing in blinkupStageTwo() called from within
                    // the above delegate function in respomse to a successful pairing and write

                case .error(let error):
                    // Could not create the BUConfigID - maybe the API is wroing/invalid?
                    NSLog("%@", error.description)
                    self.showAlert("BlinkUp Failed", "Is your API Key correct? Please re-enter it via the Devices list\n(Actions > Enter API Key)")
                    self.blinkUpProgressBar.stopAnimating()
                }
            }
        } else {
            showAlert("Connect to a Device", "You must be connected to an imp004m device in order to perform BlinkUp")
        }
    }

    @objc @IBAction func showPassword(_ sender: Any) {

        passwordField.isSecureTextEntry = !passwordField.isSecureTextEntry
    }

    // MARK: Utility Functions

    func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController.init(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .`default`, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    // MARK: CBManagerDelegate Functions

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        // The app has connected to the peripheral (eg. imp004m)
        // This is the result of calling bluetoothManager.connect()

        // Set the connected peripheral instance's delegate to this code
        peripheral.delegate = self

        // Update app state
        self.connected = true

        // Ask the peripheral for a list of all (hence 'nil') its services
        if self.blinking {
            // Re-connecting after starting BlinkUp
            blinkupStageTwo()
        } else {
            peripheral.discoverServices(nil)
            // Pick up the action at 'peripheral.didDiscoverServices()'
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect: CBPeripheral, error: Error?) {

        self.connected = false

        if (error != nil) {
            NSLog("\(error!.localizedDescription)")
        }
        
        // Device failed to connect for some reason, so report it to the user
        // and suggest a remedy
        if let aDevice: Device = self.device {
            showAlert("Cannot connect to device \(aDevice.name)", "Go back to the device list and re-scan or select another device")
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnect: CBPeripheral, error: Error?) {

        self.connected = false

        if (error != nil) {
            NSLog("\(error!.localizedDescription)")
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // NOP
    }

    // MARK: CBPeripheral Delegate functions

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {

        // The app has discovered services offered by the peripheral (ie. the imp004m).
        // This is the result of calling 'peripheral.discoverServices()'
        if error == nil {
            var got: Bool = false
            if let services = peripheral.services {
                for i in 0..<services.count {
                    let service: CBService = services[i]
                    if service.uuid.uuidString == "FADA47BE-C455-48C9-A5F2-AF7CF368D719" {
                        // Ask the peripheral for a list of the all (hence 'nil') of the service's characteristics.
                        // This asynchronous call will be picked up by 'peripheral.didDiscoverCharacteristicsFor()'
                        peripheral.discoverCharacteristics(nil, for: service)
                        got = true
                        break
                    }
                }

                if !got {
                    // Device is not serving corrrectly, so cancel the connection and warn the user
                    self.bluetoothManager.cancelPeripheralConnection(peripheral)
                    showAlert("Cannot Configure This Device", "This devices is not offering a BlinkUp service")
                }
            }
        } else {
            // Log the error
            NSLog("\(error!.localizedDescription)")

            // Update the UI to inform the user
            self.blinkUpProgressBar.stopAnimating()
            self.connected = false
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,  error: Error?) {

        // The app has discovered the characteristics offered by the peripheral (ie. the imp004m) for
        // specific service. This is the result of calling 'peripheral.discoverCharacteristics()'
        if error == nil {
            // Save the list of characteristics
            self.characteristics = service.characteristics

            // Run through the list of peripheral characteristics to see if it contains
            // the imp004m application's networks list characteristic by looking for the
            // characteristics's known UUID
            if let list = self.characteristics {
                for i in 0..<list.count {
                    let ch:CBCharacteristic? = list[i]
                    if ch != nil {
                        if ch!.uuid.uuidString == "57A9ED95-ADD5-4913-8494-57759B79A46C" {
                            // The peripheral DOES contain the expected characteristic,
                            // so read the characteristics value. When it has been read,
                            // 'peripheral.didUpdateValueFor()' will be called
                            if let aDevice = self.device { aDevice.peripheral.readValue(for: ch!) }
                            break
                        }
                    }
                }
            }
        } else {
            // Log the error
            NSLog("\(error!.localizedDescription)")

            // Update the UI to inform the user
            self.blinkUpProgressBar.stopAnimating()
            self.connected = false
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        // We have successfully read the imp004m application's networks list characteristic, so use
        // the value of the characteristic (a comma-separated string of network names) to populate
        // the 'availableNetworks' array and thus the UI's UIPickerView
        if let data = characteristic.value {
            let networkList:String? = String.init(data: data, encoding: String.Encoding.utf8)
            if networkList != nil {
                // Convert to NSString from Swift's String so we can create an
                // array from the comma-separated network names in the string
                var nl: NSString = networkList! as NSString
                let networks = nl.components(separatedBy: "\n\n")

                // Is there only one nearby network? Then check that it is not the
                // imp004m application signalling NO nearby networks
                if networks.count == 1 {
                    if networks[0] == "!no_local_networks!" || networks[0] == "" {
                        // Reset 'availableNetworks' and the UIPickerView
                        initNetworks()

                        // Hide the progress indicator
                        self.sendLabel.text = "No nearby networks to connect to"
                        self.bluetoothManager.cancelPeripheralConnection(peripheral)
                        self.blinkUpProgressBar.stopAnimating()
                        return
                    }
                }

                // We have at least one valid network name, so populate the picker
                availableNetworks.removeAll()

                for i in 0..<networks.count {
                    nl = networks[i] as NSString
                    let parts = nl.components(separatedBy: "\n")
                    var network: [String] = []
                    network.append(parts[0].isEmpty ? "[Hidden]" : parts[0])
                    network.append(parts[1])
                    self.availableNetworks.append(network)
                }

                // Update the UIPickerView
                self.wifiPicker.reloadAllComponents()
                self.wifiPicker.isUserInteractionEnabled = true
                wifiPicker.alpha = 1
            }
        }

        // Hide the progress indicator
        self.bluetoothManager.cancelPeripheralConnection(peripheral)
        self.connected = false
        self.blinkUpProgressBar.stopAnimating()
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {

        // This will be called when a value is written to the peripheral via GATT
        // The first time a write is made, iOS will manage the pairing. Only if the pairing
        // succeeds will this delegate method be called (because if pairing fails, no value
        // will be written the delegate will not be called).

        if error != nil {
            NSLog("Whoops")
            return;
        }
    }

    // MARK: UIPickerView Delegate and Data Source Functions

    func numberOfComponents(in pickerView: UIPickerView) -> Int {

        // There is only one component in this picker
        return 1;
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {

        // Return the number of entries in the 'availableNetworks' array
        return self.availableNetworks.count;
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {

        return 28
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {

        // Return the element from 'availableNetworks' whose index matches 'row'
        let network = self.availableNetworks[row]

        let rowView = UIView(frame: CGRect.init(x: 0, y: 0, width: pickerView.bounds.width, height: 28))

        let rowLabel = UILabel(frame: CGRect.init(x: 20, y: 2, width: pickerView.bounds.width - 60, height: 26))
        rowLabel.lineBreakMode = NSLineBreakMode.byTruncatingTail
        rowLabel.text = network[0]

        let rowImageView = UIImageView(frame: CGRect.init(x: pickerView.bounds.width - 40, y: 4, width: 20, height: 20))
        if network[1] == "locked" { rowImageView.image = UIImage(named:"lock") }

        rowView.addSubview(rowLabel)
        rowView.addSubview(rowImageView)

        return rowView
    }

// MARK: UITextField Delegate Functions

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {

        for item in self.view.subviews {
            let view = item as UIView
            if view.isKind(of: UITextField.self) { view.resignFirstResponder() }
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        textField.resignFirstResponder()
        return true
    }

}
