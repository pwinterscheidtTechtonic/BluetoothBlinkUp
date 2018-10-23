
//  ViewController.swift
//  BluetoothBlinkUp
//
//  Created by Tony Smith on 12/14/17.
//
//  MIT License
//
//  Copyright 2017-18 Electric Imp
//
//  Version 1.0.3
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
    var availableNetworks: [[String]] = []
    var config: BUConfigId? = nil
    var connected: Bool = false
    var clearList: Bool = false
    var isSending: Bool = false
    var isClearing: Bool = false
    var harvey: String!
    var agentURL: String!
    var scanTimer: Timer!
    var cheatTimer: Timer!
    var pinTimer: Timer!
    var pinCount: Int = 0
    
    // Constants: App values
    let DEVICE_SCAN_TIMEOUT = 5.0
    let CANCEL_TIME = 3.0
    let PIN_COUNT_MAX = 10 // Equivalent to 30s (3s per call; 10 calls)

    // BLE service values
    let BLINKUP_SERVICE_UUID = "FADA47BE-C455-48C9-A5F2-AF7CF368D719"
    let BLINKUP_WIFIGET_CHARACTERISTIC_UUID = "57A9ED95-ADD5-4913-8494-57759B79A46C"
    let BLINKUP_ENROLSET_CHARACTERISTIC_UUID = "BD107D3E-4878-4F6D-AF3D-DA3B234FF584"
    let BLINKUP_PLANSET_CHARACTERISTIC_UUID = "A90AB0DC-7B5C-439A-9AB5-2107E0BD816E"
    let BLINKUP_SSIDSET_CHARACTERISTIC_UUID = "5EBA1956-32D3-47C6-81A6-A7E59F18DAC0"
    let BLINKUP_PWDSET_CHARACTERISTIC_UUID = "ED694AB9-4756-4528-AA3A-799A4FD11117"
    let BLINKUP_WIFITRIGGER_CHARACTERISTIC_UUID = "F299C342-8A8A-4544-AC42-08C841737B1B"
    let BLINKUP_WIFICLEAR_CHARACTERISTIC_UUID = "2BE5DDBA-3286-4D09-A652-F24FAA514AF5"
    

    // MARK: - View Lifecycle Functions

    override func viewDidLoad() {

        super.viewDidLoad()

        // Set up the 'show password' button within the password entry field
        let overlayButton: UIButton = UIButton.init(type: UIButton.ButtonType.custom)
        overlayButton.setImage(UIImage.init(named: "button_eye"), for: UIControl.State.normal)
        overlayButton.addTarget(self, action: #selector(self.showPassword(_:)), for: UIControl.Event.touchUpInside)
        overlayButton.frame = CGRect.init(x: 0, y: 6, width: 20, height: 16)

        // Assign the overlay button to a stored text field
        self.passwordField.leftView = overlayButton
        self.passwordField.leftViewMode = UITextField.ViewMode.always

        // Watch for app returning to foreground from the ImpDetailViewController
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.connectToDevice),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)

        initNetworks()
        connectToDevice()
    }
    
    @objc func connectToDevice() {
        
        // App is about to come back into view after the user previously
        // switched to a different app, so reset the UI - unless we're sending
        if !self.isSending {
            initUI()
        
            // Get the networks from the device
            if let aDevice: Device = self.device {
                // NOTE We need to set the objects' delegates to 'self' so that the correct delegate functions are called
                aDevice.peripheral.delegate = self
                self.bluetoothManager.delegate = self
                self.connected = aDevice.isConnected
                setNetworks(aDevice.networks)

                if !self.connected && aDevice.peripheral != nil {
                    //self.wifiPicker.isUserInteractionEnabled = false
                    self.blinkUpProgressBar.startAnimating()
                    self.bluetoothManager.connect(aDevice.peripheral, options: nil)
                    self.scanTimer = Timer.scheduledTimer(timeInterval: DEVICE_SCAN_TIMEOUT,
                                                          target: self,
                                                          selector: #selector(self.endConnectWithAlert),
                                                          userInfo: nil,
                                                          repeats: false)
                }
            }
        }
    }

    func setNetworks(_ networkList: String) {

        // Take a list of networks as atring and use it to populate the UI's picker view
        if networkList == "Z" || networkList.count == 0 { return }

        var nl: NSString = networkList as NSString
        let networks = nl.components(separatedBy: "\n\n")

        // Is there only one nearby network? Then check that it is not the
        // imp004m application signalling NO nearby networks
        if networks.count == 1 {
            if networks[0] == "!no_local_networks!" || networks[0] == "" {
                // Reset 'availableNetworks' and the UIPickerView
                initNetworks()

                // Tell the user
                self.sendLabel.text = "No nearby networks to connect to"
                
                // Disconnect if required
                return
            }
        }

        // We have at least one valid network name, so populate the picker
        self.availableNetworks.removeAll()

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
        self.wifiPicker.isUserInteractionEnabled = false
        self.wifiPicker.alpha = 1
        self.wifiPicker.isUserInteractionEnabled = true
    }

    @objc func endConnectWithAlert() {
        
        // This function is called when 'scanTimer' fires. This event indicates that
        // the device failed to connect for some reason - so report it to the user
        if let aDevice: Device = device {
            if aDevice.peripheral != nil {
                self.bluetoothManager.cancelPeripheralConnection(aDevice.peripheral)
                self.connected = false
                aDevice.isConnected = false
            }
            
            showDisconnectAlert("Could not connect to \"\(aDevice.name)\"", "Please go back to the devices list and re-select \"\(aDevice.name)\", if necessary performing a new scan")
        }
        
        self.isClearing = false
        self.isSending = false
        self.blinkUpProgressBar.stopAnimating()
    }
    
    func initUI() {

        // Initialise the UI
        self.blinkUpProgressBar.stopAnimating()
        self.passwordField.text = ""
        self.sendLabel.text = ""
    }

    func initNetworks() {

        // Initialize the UIPickerView which presents the network list
        // NOTE The actual network data is gathered in the background
        // ( see viewDidAppear() )

        // Add a placeholder network name
        self.availableNetworks.removeAll()
        self.availableNetworks.append(["None", "unlocked"])

        // Set the UI - disabling the picker
        self.wifiPicker.reloadAllComponents()
        self.wifiPicker.isUserInteractionEnabled = false
        self.wifiPicker.alpha = 0.5
        self.wifiPicker.isUserInteractionEnabled = true
    }

    @objc func goBack() {

        // Return to the device list - unless we are sending data ('isSending' is true),
        // in which case notify the user
        if self.isSending {
            showAlert("BlinkUp™ in Progress", "Please wait until all the BlinkUp information has been sent to the device")
            return
        }

        // If a device is connected, disconnect from it
        if self.connected {
            if let aDevice: Device = self.device {
                if aDevice.peripheral != nil && !aDevice.requiresPin {
                    self.bluetoothManager.cancelPeripheralConnection(aDevice.peripheral)
                    self.connected = false
                    aDevice.isConnected = false
                }
            }
        }

        // Stop listening for 'will enter foreground' notifications
        NotificationCenter.default.removeObserver(self)

        // Jump back to the list of devices
        self.navigationController!.popViewController(animated: true)
    }


    // MARK: - Action Functions
    // MARK: BlinkUp Functions

    @IBAction func doBlinkup(_ sender: Any) {

        // Already sending or connecting in order to clear? Then bail
        if self.isSending || self.isClearing { return }

        // Trigger the auto-cancel timer (for slow users)
        if self.cheatTimer != nil && self.cheatTimer.isValid {
            self.cheatTimer.fire()
        }

        // Do we have the data we need from the UI, ie. a password for a locked network?
        let index = self.wifiPicker.selectedRow(inComponent: 0)
        let network = self.availableNetworks[index]

        // If the network is locked, the user must enter a password
        if network[1] == "locked" && self.passwordField.text!.isEmpty {
            self.showAlert("This network requires a password", "You need to enter a password for a locked network.")
            return
        }

        // If there are no compatible networks around the device, we can't proceed
        if network[0] == "None" {
            self.showAlert("There are no networks to connect to", "")
            return
        }
        
        // The user has not entered an API key
        if self.harvey.count == 0 {
            //***ENABLE AFTER TESTING***
            //self.showAlert("BlinkUp™ Requires an API key", "Please go back to the device list, tap ‘Actions’ and select ‘Enter Your BlinkUp API Key’")
            //return
        }

        self.blinkUpProgressBar.startAnimating()
        
        if let aDevice = self.device {
            // Are we already connected to the device?
            if !self.connected || aDevice.peripheral.state != CBPeripheralState.connected {
                // App is not connected to the device, so connect now
                self.isSending = true
                self.bluetoothManager.connect(aDevice.peripheral, options: nil)
                // Pick up the action at didConnect(), which is called when the
                // iDevice has connected to the imp004m
                
                // Set up a timeout
                self.scanTimer = Timer.scheduledTimer(timeInterval: DEVICE_SCAN_TIMEOUT,
                                                      target: self,
                                                      selector: #selector(self.endConnectWithAlert),
                                                      userInfo: nil,
                                                      repeats: false)
            } else {
                // App is already connected to the peripheral so do the BlinkUp
                blinkupStageTwo()
            }
        }
    }

    func blinkupStageTwo() {

        // Use the BlinkUp SDK to retrieve an enrollment token and a plan ID from the user's API Key
        // You will need to be an Electric Imp customer with a BlinkUp API Key to make this work
        // If no API key is known to the app, it will just transmit WiFi data
        self.isSending = true
        if self.scanTimer != nil && self.scanTimer.isValid { self.scanTimer.invalidate() }
        
        // NOTE The progress indicator is already active at this point
        if self.connected {
            // We're good to proceed so begin BlinkUp
            sendLabel.text = "Sending BlinkUp™ data"

            if self.harvey.count == 0 {
                // The user HAS NOT set a BlinkUp API key, so just send across WiFi credentials,
                // ie. do not perform a full device enrolment too
                if let aDevice = self.device {
                    // Transmit the first part of the WiFi data
                    sendSSID(aDevice)

                    // Write the network password
                    sendPWD(aDevice)
                    
                    // Write to the characteristic that triggers a WiFi refresh on the device
                    sendResetTrigger(aDevice)
                    
                    // Finally, do the clean-up
                    completeBlinkUp()
                }
            } else {
                // The user HAS input a BlinkUp API key, so perform a full device activation,
                // ie. enrol the device and transmit WiFi credentials.
                // First, get a BUConfigID — this REQUIRES a BlinkUp API key
                let _ = BUConfigId.init(apiKey: self.harvey) { (_ config: BUConfigId.ConfigIdResponse) -> Void in
                    // 'config' is the response to the creation of the BUConfigID
                    // It has two possible values:
                    //    .activated (passes in the active BUConfigID)
                    //    .error     (passes in an NSError)
                    switch config {
                    case .activated(let activeConfig):
                        // Save the supplied BUconfigID for later
                        self.config = activeConfig

                        // Transmit the first part of the WiFi data
                        if let aDevice = self.device {
                            // Send the WiFi credentials
                            self.sendSSID(aDevice)
                            self.sendPWD(aDevice)
                            
                            // Send the Enrolment Data
                            self.sendEnrolData(aDevice, activeConfig)
                            
                            // Write to the characteristic that triggers a WiFi refresh on the device
                            self.sendResetTrigger(aDevice)
                            
                            // Finally, do the clean-up
                            self.completeActivation(aDevice)
                        }

                    case .error(let error):
                        // Could not create the BUConfigID - maybe the API is wroing/invalid?
                        NSLog("BUConfigId(init) error: \(error.localizedDescription)")

                        self.showAlert("BlinkUp™ Could Not Proceed", "Your BlinkUp API Key is not correct.\nPlease re-enter or clear it via the main Devices list on the previous screen (Actions > Enter API Key). An API key is only required for new device enrollment — updating WiFi details on an enrolled device does not require a BlinkUp API key.")

                        self.blinkUpProgressBar.stopAnimating()
                        self.isSending = false
                    }
                }
            }
        } else {
            // Should be connected at this point, but for some reason we're not so post a warning to the user
            self.isSending = false
            showAlert("Please Connect to a Device", "You must be connected to an imp-enabled device with Bluetooth in order to perform BlinkUp. Return to the Device List and re-select the device")
        }
    }

    func completeActivation(_ aDevice: Device) {
        // Having successfully sent WiFi data - dealing with PIN entry, if necessary,
        // we come here to send the enrollment data and poll for device enrollment

        // Update the UI
        self.sendLabel.text = "Waiting for device to enrol"

        // Begin polling the server for an indication that the device
        // has connected and been enrolled
        let poller = BUDevicePoller.init(configId: self.config!)
        poller.startPollingWithHandler({ (response) in
            switch(response) {
            // There are three possible outcomes:
            //  .responded — the poller returned data upon successful enrollment
            //  .error - an error occurred
            //  .timeout - the timeout tripped, ie. we lost contact with the server
            case .responded(let info):
                // The server indicates that the device has enrolled successfully, so we're done
                // Update the UI
                self.sendLabel.text = ""
                self.blinkUpProgressBar.stopAnimating()
                
                // Instantiate and show a webview containing the agent-served UI, if we have a URL for it
                if let url = info.agentURL?.absoluteString {
                    let storyboard = UIStoryboard.init(name:"Main", bundle:nil)
                    let awvc = storyboard.instantiateViewController(withIdentifier:"webview") as! AgentWebViewController
                    awvc.agentURL = url

                    // Set up the left-hand nav bar button with an icon and text
                    let button = UIButton(type: UIButton.ButtonType.system)
                    button.setImage(UIImage(named: "icon_back"), for: UIControl.State.normal)
                    button.setTitle("Back", for: UIControl.State.normal)
                    button.tintColor = UIColor.init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
                    button.sizeToFit()
                    button.addTarget(awvc, action: #selector(awvc.goBack), for: UIControl.Event.touchUpInside)
                    awvc.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
                    self.navigationController!.pushViewController(awvc, animated: true)
                } else {
                    // No agent URL available, so just present a generic dialog
                    self.showAlert("Device Enrolled", "Your device has connected to the Electric Imp impCloud™.")
                }

            case .error(let error):
                // Something went wrong, so dump the error and perform the timed out flow
                NSLog("poller.startPollingWithHandler() error: \(error.description)")
                fallthrough

            case .timedOut:
                // The server took too long to respond, so assume enrollment did not take place
                self.sendLabel.text = ""
                self.blinkUpProgressBar.stopAnimating()
                self.showAlert("Device Failed to Connect", "Your device has not enrolled in the Electric Imp impCloud™. Please try again.")
            }

            // Done sending, so cancel the connection (best practice to save battery power)
            // but only if the device is not protected by a PIN
            if let aDevice = self.device {
                if aDevice.peripheral != nil && !aDevice.requiresPin {
                    self.bluetoothManager.cancelPeripheralConnection(aDevice.peripheral)
                    self.connected = false
                    aDevice.isConnected = false
                }
            }
            
            // Mark that we're done
            self.isSending = false
        })
    }
    
    func completeBlinkUp() {
        
        // Perform clean-up after doing a WiFi-only BlinkUp
        // Auto-close the connection in CANCEL_TIME seconds' time,
        self.cheatTimer = Timer.scheduledTimer(withTimeInterval: self.CANCEL_TIME, repeats: false, block: { (_) in
            if let aDevice = self.device {
                // Cancel the connection (best practice to save battery power)
                // but only if the device is not protected by a PIN
                if aDevice.peripheral != nil && !aDevice.requiresPin {
                    self.bluetoothManager.cancelPeripheralConnection(aDevice.peripheral)
                    self.connected = false
                    aDevice.isConnected = false
                }
                
                // Mark that we're done
                self.isSending = false
                
                // Clean up the UI
                self.sendLabel.text = ""
                self.blinkUpProgressBar.stopAnimating()
                
                // Instantiate and show a webview containing the agent-served UI
                // TODO Incorporate a check to load the agent-served string and check that
                //      it is valid HTML before loading
                if (aDevice.agent.count > 0) {
                    let storyboard = UIStoryboard.init(name:"Main", bundle:nil)
                    let awvc = storyboard.instantiateViewController(withIdentifier:"webview") as! AgentWebViewController
                    awvc.agentURL = aDevice.agent
                    
                    // Set up the left-hand nav bar button with an icon and text
                    let button = UIButton(type: UIButton.ButtonType.system)
                    button.setImage(UIImage(named: "icon_back"), for: UIControl.State.normal)
                    button.setTitle("Back", for: UIControl.State.normal)
                    button.tintColor = UIColor.init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
                    button.sizeToFit()
                    button.addTarget(awvc, action: #selector(awvc.goBack), for: UIControl.Event.touchUpInside)
                    awvc.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
                    self.navigationController!.pushViewController(awvc, animated: true)
                } else {
                    // We don't have an agent URL, so show a generic dialog
                    self.showAlert("Device Connecting", "Your device has received WiFi credentials and is connecting to the Electric Imp impCloud™.")
                }
            }
        })
    }

    func sendSSID(_ device: Device) {
        
        // Transmit the user-selected SSID to the device
        let index = self.wifiPicker.selectedRow(inComponent: 0)
        let network = self.availableNetworks[index]
        let sdata:Data? = network[0].data(using: String.Encoding.utf8)

        // Work through the characteristic list for the service, to match them
        // to known UUIDs so we send the correct data to the device
        let a = device.characteristics[BLINKUP_SERVICE_UUID]!
        for i in 0..<a.count {
            let ch: CBCharacteristic? = a[i] as CBCharacteristic
            if ch != nil {
                if ch!.uuid.uuidString == BLINKUP_SSIDSET_CHARACTERISTIC_UUID {
                    if let s = sdata {
                        // At the first GATT write, iOS will handle pairing, if required
                        // If pairing succeeds, the following write will be made,
                        // and 'peripheral(_, didWriteValueFor, error)' called
                        device.peripheral.writeValue(s, for:ch!, type:CBCharacteristicWriteType.withResponse)
                        NSLog("Writing SSID characteristic \(ch!.uuid.uuidString)")
                    }
                }
            }
        }
    }

    func sendPWD(_ device: Device) {

        // Transmit the user-entered WiFi password to the device
        let pdata:Data? = self.passwordField.text!.data(using: String.Encoding.utf8)

        // Work through the characteristic list for the service, to match them
        // to known UUIDs so we send the correct data to the device
        let a = device.characteristics[BLINKUP_SERVICE_UUID]!
        for i in 0..<a.count {
            let ch: CBCharacteristic? = a[i] as CBCharacteristic
            if ch != nil {
                if ch!.uuid.uuidString == BLINKUP_PWDSET_CHARACTERISTIC_UUID {
                    if let p = pdata {
                        // At the first GATT write (or read) iOS will handle pairing.
                        // If the user hits cancel, we will not be allowed to write, but if pairing succeeds,
                        // the following write will be made, and 'peripheral(_, didWriteValueFor, error)' called
                        device.peripheral.writeValue(p, for:ch!, type:CBCharacteristicWriteType.withResponse)
                        NSLog("Writing password characteristic \(ch!.uuid.uuidString)")
                    }
                }
            }
        }
    }

    func sendEnrolData(_ device: Device, _ config: BUConfigId) {

        // Package up the enrolment data and send it to the device
        // NOTE This function only sends the data, it does not tell the device
        //      to update its setttings — use sendResetTrigger() for that
        let tdata:Data? = config.token.data(using: String.Encoding.utf8)
        let pdata:Data? = config.planId!.data(using: String.Encoding.utf8)
        NSLog("Sending token (\(config.token)) and plan ID (\(config.planId!))")

        // Work through the characteristic list for the service, to match them
        // to known UUIDs so we send the correct data to the device

        // These characteristic values can be written in any order
        let a = device.characteristics[BLINKUP_SERVICE_UUID]!
        for i in 0..<a.count {
            let ch: CBCharacteristic? = a[i] as CBCharacteristic;
            if ch != nil {
                if ch!.uuid.uuidString == BLINKUP_ENROLSET_CHARACTERISTIC_UUID {
                    if let s = tdata {
                        // At the first GATT write (or read) iOS will handle pairing.
                        // If the user hits cancel, we will not be allowed to write, but if pairing succeeds,
                        // the following write will be made, and 'peripheral(_, didWriteValueFor, error)' called
                        device.peripheral.writeValue(s, for:ch!, type:CBCharacteristicWriteType.withResponse)
                        NSLog("Writing enrol token characteristic \(ch!.uuid.uuidString)")
                    }
                }

                if ch!.uuid.uuidString == BLINKUP_PLANSET_CHARACTERISTIC_UUID {
                    if let s = pdata {
                        device.peripheral.writeValue(s, for:ch!, type:CBCharacteristicWriteType.withResponse)
                        NSLog("Writing plan ID characteristic \(ch!.uuid.uuidString)")
                    }
                }
            }
        }
    }

    func sendResetTrigger(_ device: Device) {

        // Writing to the BLINKUP_WIFITRIGGER characteristic causes the imp application
        // to reboot the device in order to enrol and/or re-connect using new WiFi credentials
        let a = device.characteristics[BLINKUP_SERVICE_UUID]!
        for i in 0..<a.count {
            let ch: CBCharacteristic? = a[i] as CBCharacteristic
            if ch != nil {
                if ch!.uuid.uuidString == BLINKUP_WIFITRIGGER_CHARACTERISTIC_UUID {
                    if let p = "reset".data(using: String.Encoding.utf8) {
                        // Set 'p' to be dummy data passed in the write operation.
                        // It will not be used by the imp application
                        device.peripheral.writeValue(p, for:ch!, type:CBCharacteristicWriteType.withResponse)
                        NSLog("Writing device-reset trigger characteristic \(ch!.uuid.uuidString)")
                    }
                }
            }
        }
    }

    // MARK: Clear WiFi Functions

    @IBAction func clearWiFi(_ sender: Any) {

        // Already sending or connecting in order to clear? Then bail
        if self.isSending || self.isClearing { return }

        // Trigger the auto-cancel timer (for slow users)
        if self.cheatTimer != nil && self.cheatTimer.isValid {
            self.cheatTimer.fire()
        }
        
        // Activate the activity indicator
        self.blinkUpProgressBar.startAnimating()

        // Are we already connected to the device?
        if let aDevice = self.device {
            // Are we already connected to the device?
            if !self.connected || aDevice.peripheral.state != CBPeripheralState.connected {
                // App is not connected to the device, so connect now
                self.isClearing = true
                self.bluetoothManager.connect(aDevice.peripheral, options: nil)
                // Pick up the action at didConnect(), which is called when the
                // iDevice has connected to the imp004m
                
                // Set up a timeout
                self.scanTimer = Timer.scheduledTimer(timeInterval: DEVICE_SCAN_TIMEOUT,
                                                      target: self,
                                                      selector: #selector(self.endConnectWithAlert),
                                                      userInfo: nil,
                                                      repeats: false)
            } else {
                // App is already connected to the peripheral so do the BlinkUp
                clearWiFiStageTwo()
            }
        }
    }

    func clearWiFiStageTwo() {

        self.isClearing = false
        self.isSending = true
        if self.scanTimer != nil && self.scanTimer.isValid { self.scanTimer.invalidate() }

        if let aDevice = self.device {
            // Work through the characteristic list for the BLINKUP service, to
            // match them to known UUIDs so we send the correct data to the device
            let a = aDevice.characteristics[BLINKUP_SERVICE_UUID]!
            for i in 0..<a.count {
                let ch: CBCharacteristic? = a[i] as CBCharacteristic
                if ch != nil {
                    if ch!.uuid.uuidString == BLINKUP_WIFICLEAR_CHARACTERISTIC_UUID {
                        if let s = "clear".data(using: String.Encoding.utf8) {
                            // At the first GATT write (or read) iOS will handle pairing. Whether
                            // pairing succeeds or not, or is not required,
                            // 'peripheral(_, didWriteValueFor, error)' will be called
                            NSLog("\(aDevice.peripheral.state == CBPeripheralState.disconnected ? " disconnected" : "connected")")
                            aDevice.peripheral.writeValue(s, for:ch!, type:CBCharacteristicWriteType.withResponse)
                            NSLog("Writing 'Clear WiFi' trigger")
                        }
                    }
                }
            }
            
            // Now perform clean-up
            clearWiFiComplete()
        }
    }
    
    func clearWiFiComplete() {
        
        // Tasks to perform once the imp's WiFi settings have been cleared
        
        // Clean up the UI
        self.sendLabel.text = ""
        self.blinkUpProgressBar.stopAnimating()
        self.isSending = false
        
        // Tell the user via an alert to expect the device to attempt to connect
        showAlert("imp WiFi Cleared", "Your imp’s WiFi credentials have been cleared")
        
        // Auto-close the connection in CANCEL_TIME seconds' time,
        // but only if the device has no Bluetooth LE PIN set.
        // Keep the connection open, otherwise
        self.cheatTimer = Timer.scheduledTimer(withTimeInterval: self.CANCEL_TIME, repeats: false, block: { (_) in
            if let aDevice = self.device {
                if aDevice.peripheral != nil && !aDevice.requiresPin {
                    self.bluetoothManager.cancelPeripheralConnection(aDevice.peripheral)
                    self.connected = false
                    aDevice.isConnected = false
                    NSLog("Closing connection")
                }
            }
        })
    }

    // MARK: - Utility Functions

    func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController.init(title: title,
                                           message: message,
                                           preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"),
                                      style: .`default`,
                                      handler: nil))
        self.present(alert,
                     animated: true,
                     completion: nil)
    }
    
    func showDisconnectAlert(_ title: String, _ message: String) {
        let alert = UIAlertController.init(title: title,
                                           message: message,
                                           preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"),
                                      style: .`default`,
                                      handler: nil))
        self.present(alert,
                     animated: true) {
                        self.initUI()
                        self.initNetworks()
                        self.clearList = true }
    }

    @objc @IBAction func showPassword(_ sender: Any) {

        // Show or hide the password characters by flipping this flag
        passwordField.isSecureTextEntry = !passwordField.isSecureTextEntry
    }

    func handleBTError(_ place: String, _ peripheral: CBPeripheral, _ error: Error) {
        
        // Generic error processing function
        // Log the error
        var deviceName: String = "Unknown"
        if let d = peripheral.name { deviceName = d }
        NSLog("\(place): \(error.localizedDescription) for device \(deviceName)")
        
        // Close the connection
        self.bluetoothManager.cancelPeripheralConnection(peripheral)
        self.connected = false
        
        if let aDevice: Device = self.device {
            aDevice.isConnected = false
        }
        
        // Update the UI to inform the user
        self.blinkUpProgressBar.stopAnimating()
        showAlert("Cannot Configure this Device", "This device is not offering a BlinkUp service")
    }
    
    // MARK: - CBManagerDelegate Functions

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        // The app has connected to the peripheral (eg. imp004m)
        // This is the result of calling bluetoothManager.connect()
        // Cancel timeout timer
        if self.scanTimer != nil && self.scanTimer.isValid { self.scanTimer.invalidate() }

        // Update app state
        self.connected = true

        // We may have connected mid-operation, so take a path relevant to
        // that operation
        if self.isSending {
            // We are are connecting after calling doBlinkUp()
            // so proceed to the next step
            blinkupStageTwo()
        } else if self.isClearing {
            // We are are connecting after calling clearWiFi()
            // so proceed to the next step
            clearWiFiStageTwo()
        } else {
            // Just a generic reconnection, eg. after the app returns to the foreground
            if let aDevice: Device = self.device {
                if aDevice.services.count == 0 {
                    // Get a list of services
                    peripheral.discoverServices(nil)
                } else {
                    if aDevice.characteristics.count == 0 {
                        // Get the characteristics from the services we know about
                        for i in 0..<aDevice.services.count {
                            let service: CBService = aDevice.services[i]
                            if service.uuid.uuidString == BLINKUP_SERVICE_UUID {
                                peripheral.discoverCharacteristics(nil, for: service)
                            }
                        }
                    } else {
                        // We have services and characteristics saved (which we should)
                        // so we'll be ready to read and write values
                        
                        // Get the SSID list in order to trigger a PIN entry request
                        if aDevice.requiresPin {
                            var gotBlinkUp: Bool = false
                            for i in 0..<aDevice.services.count {
                                let service: CBService = aDevice.services[i]
                                if service.uuid.uuidString == BLINKUP_SERVICE_UUID {
                                    let a = aDevice.characteristics[BLINKUP_SERVICE_UUID]!
                                    for j in 0..<a.count {
                                        let ch: CBCharacteristic? = a[j]
                                        if ch != nil {
                                            if ch!.uuid.uuidString == BLINKUP_WIFIGET_CHARACTERISTIC_UUID {
                                                aDevice.peripheral.readValue(for: ch!)
                                                gotBlinkUp = true
                                                break
                                            }
                                        }
                                    }
                                    
                                    if gotBlinkUp { break }
                                }
                            }
                            
                            if !gotBlinkUp {
                                endConnectWithAlert()
                            }
                        }
                        
                        self.blinkUpProgressBar.stopAnimating()
                    }
                }
            } else {
                // Got all we need, so just hide the activity indicator
                self.blinkUpProgressBar.stopAnimating()
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect: CBPeripheral, error: Error?) {

        var deviceName: String = "Unknown"
        if let d = didFailToConnect.name { deviceName = d }

        self.connected = false
        
        if let aDevice: Device = self.device {
            aDevice.isConnected = false
            deviceName = aDevice.name
        }
        
        if (error != nil) {
            NSLog("centralManager(didFailToConnect) error: \(error!.localizedDescription) for device \(deviceName)")
            showDisconnectAlert("Could not connect to \"\(deviceName)\"", "Please go back to the devices list and re-select \"\(deviceName)\", if necessary performing a new scan")
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnect: CBPeripheral, error: Error?) {

        var deviceName: String = "Unknown"
        if let d = didDisconnect.name { deviceName = d }
        
        self.connected = false
        
        if let aDevice: Device = self.device {
            aDevice.isConnected = false
            deviceName = aDevice.name
        }
        
        if (error != nil) {
            NSLog("centralManager(didDisconnect) error: \(error!.localizedDescription) for device \(deviceName)")
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        // NOP - Nothing to do here, but we need to include the stub to compile correctly
    }


    // MARK: - CBPeripheral Delegate functions

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {

        // The app has discovered services offered by the peripheral (ie. the imp)
        // This is the result of calling 'peripheral.discoverServices()'
        if error == nil {
            var gotBlinkUp: Bool = false
            if let services = peripheral.services {
                for i in 0..<services.count {
                    let service: CBService = services[i]
                    if service.uuid.uuidString == BLINKUP_SERVICE_UUID {
                        gotBlinkUp = true
                        break
                    }
                }
                
                if let aDevice: Device = self.device {
                    if !gotBlinkUp {
                        // Device is not serving the BLINKUP service corrrectly,
                        // so close the connection and warn the user
                        self.bluetoothManager.cancelPeripheralConnection(peripheral)
                        self.connected = false
                        aDevice.isConnected = false
                        
                        // Update the UI to inform the user
                        self.blinkUpProgressBar.stopAnimating()
                        showAlert("Cannot Configure This Device", "This device is not offering a BlinkUp service")
                    } else {
                        // Device supports BLINKUP, so get its characteristics
                        aDevice.services = services
                        for i in 0..<services.count {
                            let service: CBService = services[i]
                            peripheral.discoverCharacteristics(nil, for: service)
                        }
                    }
                }
            }
        } else {
            // Log the error
            handleBTError("didDiscoverServices()", peripheral, error!)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,  error: Error?) {

        // The app has discovered the characteristics offered by the peripheral (ie. the imp004m) for
        // specific service. This is the result of calling 'peripheral.discoverCharacteristics()'
        if error == nil {
            // Save the list of characteristics
            if let list = service.characteristics {
                if let aDevice: Device = self.device {
                    aDevice.characteristics[service.uuid.uuidString] = list
                }
            }
            
            self.blinkUpProgressBar.stopAnimating()
        } else {
            // Log the error
            handleBTError("didDiscoverCharacteristicsFor()", peripheral, error!)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        // We have successfully read the imp application's networks list characteristic, so use
        // the value of the characteristic (a comma-separated string of network names) to populate
        // the 'availableNetworks' array and thus the UI's UIPickerView
        if characteristic.uuid.uuidString == BLINKUP_WIFIGET_CHARACTERISTIC_UUID {
            if let data = characteristic.value {
                if data.count > 0 {
                    let networkList:String? = String.init(data: data, encoding: String.Encoding.utf8)
                    if networkList != nil {
                        // We have at least one valid network name, so populate the picker
                        setNetworks(networkList!)
                        
                        let nl: NSString = networkList! as NSString
                        let networks = nl.components(separatedBy: "\n\n")
                        if networks.count == 0 {
                            // Disconnect as there are no networks to connect to
                            self.bluetoothManager.cancelPeripheralConnection(peripheral)
                            self.connected = false
                            
                            if let aDevice: Device = self.device {
                                aDevice.isConnected = false
                            }
                            
                            self.blinkUpProgressBar.stopAnimating()
                        }
                    }
                } else {
                    // Access to the value has not yet been authorized by PIN, so
                    // attempt to read the value again in three seconds' time (by
                    // when the value might have neen unlocked, or blocked)
                    let a: [Any] = [peripheral, characteristic]
                    self.pinTimer = Timer.scheduledTimer(timeInterval: 3.0,
                                                         target: self,
                                                         selector: #selector(self.attemptRead),
                                                         userInfo: a,
                                                         repeats: false)
                }
            }
        } else {
            NSLog("peripheral(didUpdateValueFor) called for characteristic \(characteristic.uuid.uuidString)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {

        // This will be called when a value is written to the peripheral via GATT
        // The first time a write is made, iOS will manage the pairing. Only if the pairing
        // succeeds will this delegate method be called (because if pairing fails, no value
        // will be written the delegate will not be called).
        if error != nil {
            NSLog("peripheral(didWriteValueFor) error: \(error!.localizedDescription) for characteristic \(characteristic.uuid.uuidString)")
        } else {
            NSLog("peripheral(didWriteValueFor): wrote characteristic \(characteristic.uuid.uuidString)")
        }
    }

    @objc func attemptRead(_ timer: Timer) {

        // A callback triggered by 'pinTimer'. When it fires, get the current peripheral
        // and characteristic (saved to 'userInfo') and attempt to read the value again
        pinCount = pinCount + 1
        if pinCount < PIN_COUNT_MAX {
            // We are here less that PIN_COUNT_MAX times, so queue up another write
            // attempt of the appropriuate type
            var a: [Any] = timer.userInfo as! [Any]
            let p: CBPeripheral = a[0] as! CBPeripheral
            let c: CBCharacteristic = a[1] as! CBCharacteristic
            p.readValue(for: c)
        } else {
            // We have exceeded the time limit on attempts to write. We take this as a
            // proxy for the user failing to enter the correct PIN or having cancelled
            // the PIN entry operation (this is the only opportunity iOS allows us for this)
            pinCount = 0
            showAlert("Bluetooth PIN", "You have not entered a valid Bluetooth PIN.")
        }
    }


    // MARK: - UIPickerView Delegate and Data Source Functions

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


    // MARK: - UITextField Delegate Functions

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
