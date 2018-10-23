
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
import Security


class DevicesTableViewController: UITableViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    @IBOutlet weak var devicesTable: UITableView!
    @IBOutlet weak var infoGesture: UILongPressGestureRecognizer!

    var bluetoothManager: CBCentralManager!
    var devices: [Device] = []
    var ddvc: DeviceDetailViewController? = nil
    var keyEntryController: UIAlertController!
    var alert: UIAlertController? = nil
    var harvey: String = ""
    var keyWindowUp: Bool = false
    var scanTimer: Timer!
    var pinTimer: Timer!
    var scanning: Bool = false
    var gotBluetooth: Bool = false
    var pinCount: Int = 0

    // Constants
    // Constants: Device State
    let DEVICE_SCAN_TIMEOUT      = 32.0
    let PERIPHERAL_STATE_UNKNOWN = -1
    let PERIPHERAL_STATE_INITIAL = 0
    let PERIPHERAL_STATE_GETTING = 1
    let PERIPHERAL_STATE_GOT     = 2
    let PIN_COUNT_MAX            = 12
    
    // Constants: BLE Services
    let BLINKUP_SERVICE_UUID                   = "FADA47BE-C455-48C9-A5F2-AF7CF368D719"
    let BLINKUP_WIFIGET_CHARACTERISTIC_UUID    = "57A9ED95-ADD5-4913-8494-57759B79A46C"
    let DEVICE_INFO_SERVICE_UUID               = "180A"
    let DEVICE_INFO_MODEL_CHARACTERISTIC_UUID  = "2A24"
    let DEVICE_INFO_SERIAL_CHARACTERISTIC_UUID = "2A25"
    let DEVICE_INFO_AGENT_CHARACTERISTIC_UUID  = "2A23"
    let DEVICE_INFO_MANUF_CHARACTERISTIC_UUID  = "2A29"


    // MARK: - View Lifecycle Functions

    override func viewDidLoad() {

        super.viewDidLoad()

        // Set up the table's selection persistence
        self.clearsSelectionOnViewWillAppear = false

        // Initialise object properties
        self.ddvc = nil

        // Instantiate the CoreBluetooth manager
        self.bluetoothManager = CBCentralManager.init(delegate: self, queue: nil, options: nil)

        // Set up the Navigation Bar with an Edit button
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "Actions",
                                                                      style: UIBarButtonItem.Style.plain,
                                                                      target: self,
                                                                      action: #selector(self.showActions))
        self.navigationItem.rightBarButtonItem!.tintColor = UIColor.white

        // Set up the Navigation Bar with a pro
        self.navigationItem.title = "Devices"

        // Watch for app returning to foreground
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.viewWillAppear),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)

        // Watch for app going to background with DeviceDetailViewController active
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.closeUp),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        
        // Watch for a Quick Action-triggered notification to start a scan
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.actionScan),
                                               name: NSNotification.Name(rawValue: "com.bps.bluetoothblinkup.startscan"),
                                               object: nil)

        // Add a long-press gesture to the UITableView to pop up the Info panel
        self.infoGesture.addTarget(self, action: #selector(showInfo))
        self.devicesTable.addGestureRecognizer(infoGesture)
        
        // Set up the refresh control - the searching indicator
        self.refreshControl = UIRefreshControl.init()
        self.refreshControl!.backgroundColor = UIColor.init(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        self.refreshControl!.tintColor = UIColor.black
        self.refreshControl!.attributedTitle = NSAttributedString.init(string: "Searching for Bluetooth-enabled imps...",
                                                                       attributes: [ NSAttributedString.Key.foregroundColor : UIColor.black ])
        self.refreshControl!.addTarget(self,
                                       action: #selector(self.startScan),
                                       for: UIControl.Event.valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)

        if self.ddvc != nil {
            // Coming back from the Device Detail View Controller
            if self.ddvc!.clearList {
                // We could not connect at some point, so clear the device
                // list to prepare for a new scan
                initTable()
                self.devicesTable.reloadData();
            }
            
            // Zap the Device Detail View Controller
            self.ddvc = nil
        } else {
            // Coming back from the background, or starting up
            if self.refreshControl!.isRefreshing { self.refreshControl!.endRefreshing() }
            
            // Clear the list of devices
            initTable()
            self.devicesTable.reloadData();
        }
    }

    override func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)

        // Load the user's API key from the Keychain
        if let key = getHarvey() {
            self.harvey = key
        } else {
            // There is no saved API key so get one by presenting the key request panel
            // ***ENABLE AFTER TESTING***
            // getRawkey()
        }
    }


    // MARK: - Device Scanning Functions

    @objc func actionScan() {

        // Scan entry point for menu actions and Home Page Quick Actions
        self.startScan()
    }

    @objc func startScan() {

        if self.gotBluetooth {
            // Begin scanning if we are not scanning already
            if !self.scanning {
                self.refreshControl!.beginRefreshing()
                
                // Clear the current list of discovered devices and redraw the table
                self.devices.removeAll()
                self.devicesTable.reloadData()

                // Start scanning for the imp004m GATT server by using its key GATT service UUID
                let s:CBUUID = CBUUID(string: BLINKUP_SERVICE_UUID)
                self.bluetoothManager.delegate = self
                self.bluetoothManager.scanForPeripherals(withServices:[s], options:nil)
                self.scanning = true

                // Set up a timer to cancel the scan automatically after DEVICE_SCAN_TIMEOUT seconds
                self.scanTimer = Timer.scheduledTimer(timeInterval: self.DEVICE_SCAN_TIMEOUT,
                                                      target: self,
                                                      selector: #selector(self.endScanWithAlert),
                                                      userInfo: nil,
                                                      repeats: false)
            } else {
                // We're already scanning so just cancel the scan
                endScan(false)
            }
        } else {
            // No BLE so disable the scan if one's in progress
            endScan(false)
            
            // Warn the user there's no Bluetooth
            showAlert("Bluetooth LE Disabled", "Please ensure the Bluetooth is powered up on your iPhone")
        }
    }

    @objc func endScanWithAlert() {

        // End the device scan and present a warning dialog if
        // there were no devices found
        endScan(true)
    }

    func endScan(_ showAnAlert: Bool) {

        // Only proceed to cancel the scan if a scan is taking place
        if self.scanning {
            // Deal with the timer - it will still be running if we are cancelling manualluy
            if self.scanTimer != nil && self.scanTimer.isValid { self.scanTimer.invalidate() }
            if self.pinTimer != nil && self.pinTimer.isValid { self.pinTimer.invalidate() }

            // Cancel the scan
            self.scanning = false
            self.bluetoothManager.stopScan()

            // Hide the refresh control
            self.refreshControl!.endRefreshing()
            
            // Clear any discovereed devices from list that were not authorized by PIN
            if self.devices.count > 0 {
                var index = 0
                repeat {
                    let aDevice: Device = self.devices[index]
                    if aDevice.state != PERIPHERAL_STATE_GOT {
                        self.bluetoothManager.cancelPeripheralConnection(aDevice.peripheral)
                        self.devices.remove(at: index)
                    } else {
                        index = index + 1
                    }
                } while index < self.devices.count && self.devices.count != 0
            }
            
            // Warn the user
            if self.devices.count == 0 && showAnAlert {
                showAlert("No Bluetooth-enabled imp Devices Found", "")
                initTable()
            } else {
                self.devicesTable.reloadData()
            }
        }
    }
    
    func initTable() {
        
        // Add an instruction line to the table.
        // This used deviceID = NONE to indicte its type to the app, eg. to prevent the
        // row being selected. This line will be clear when the user scans for devices
        let text: Device = Device()
        text.name = "Pull down to search for Bluetooth-enabled imps"
        text.devID = "NONE"
        self.devices.removeAll()
        self.devices.append(text)
        self.devicesTable.reloadData()
    }

    @objc func closeUp() {

        // The app is going into the background so cancel any scan taking place
        endScan(false)

        // Remove the API key input window if it's visible
        if keyWindowUp { keyEntryController.removeFromParent() }

        // Cancel any open connections to devices that we may have
        if self.devices.count > 0 {
            for i in 0..<self.devices.count {
                let aDevice: Device = self.devices[i]
                if aDevice.devID != "TBD" && aDevice.peripheral != nil {
                    self.bluetoothManager.cancelPeripheralConnection(aDevice.peripheral)
                }
            }
        }
    }


    // MARK: - UI Functions

    @objc func showActions() {

        let actionMenu = UIAlertController.init(title: "Select an Action from the List Below", message: nil, preferredStyle: UIAlertController.Style.actionSheet)
        var action: UIAlertAction!

        // Add the 'start scan' or 'cancel scan' action button
        if self.scanning {
            // We're currently scanning, so present the Cancel Scan option
            action = UIAlertAction.init(title: "Cancel Scan", style: UIAlertAction.Style.default) { (alertAction) in
                self.endScan(true)
            }
        } else {
            // We are not scanning, so present the Start Scan button
            action = UIAlertAction.init(title: "Start Scan", style: UIAlertAction.Style.default) { (alertAction) in
                self.actionScan()
            }
        }

        actionMenu.addAction(action)

        // Construct and add the other buttons
        action = UIAlertAction.init(title: "Show App Info", style: UIAlertAction.Style.default) { (alertAction) in
            self.showInfo()
        }

        actionMenu.addAction(action)

        action = UIAlertAction.init(title: "Visit the Electric Imp Store", style: UIAlertAction.Style.default) { (alertAction) in
            self.goToShop()
        }

        actionMenu.addAction(action)

        action = UIAlertAction.init(title: "Enter Your BlinkUp™ API Key", style: UIAlertAction.Style.default) { (alertAction) in
            self.getRawkey()
        }

        actionMenu.addAction(action)

        action = UIAlertAction.init(title: "Cancel", style: UIAlertAction.Style.cancel, handler:nil)

        actionMenu.addAction(action)

        self.present(actionMenu, animated: true, completion: nil)
    }

    @objc func showInfo() {

        self.devicesTable.removeGestureRecognizer(self.infoGesture)
        let alert = UIAlertController.init(title: "App\nInformation", message: "This sample app can be used to activate Bluetooth-enabled Electric Imp devices, such as the imp004m. Tap ‘Scan’ to find local devices (these must be running the accompanying Squirrel device code) and then select a device to set its WiFi credentials. The selected device will automatically provide a list of compatible networks — just select one from the list and enter its password (or leave the field blank if it has no password). Tap ‘Send BlinkUp’ to configure the device. The app will inform you when the device has successfully connected to the Electric Imp impCloud™", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"),
                                      style: UIAlertAction.Style.default,
                                      handler: nil))
        self.present(alert, animated: true) {
            self.devicesTable.addGestureRecognizer(self.infoGesture)
        }
    }

    @objc func goToShop() {

        // Open the EI shop in Safari
        let uiapp = UIApplication.shared
        let url: URL = URL.init(string: "https://store.electricimp.com/")!
        uiapp.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
    }

    
    // MARK: - Utility Functions

    func showAlert(_ title: String, _ message: String) {
        
        // Generic alert creation routine
        
        // Make sure we're not already presenting - if so update the text
        if let currentAlert = self.presentedViewController as? UIAlertController {
            currentAlert.message = message
            currentAlert.title = title
            return
        }
        
        // Display a new alert
        self.alert = UIAlertController.init(title: title,
                                            message: message,
                                            preferredStyle: UIAlertController.Style.alert)
        self.alert!.addAction(UIAlertAction(title: "OK",
                                            style: UIAlertAction.Style.default,
                                            handler: nil))
        
        self.present(self.alert!, animated: true, completion: nil)
    }
    
    func getDevice(_ peripheral: CBPeripheral) -> Device? {

        // Return the Device object for the specified peripheral - or nil
        if self.devices.count == 0 { return nil }

        for i in 0..<self.devices.count {
            let aDevice: Device = self.devices[i]
            if aDevice.peripheral == peripheral { return aDevice }
        }

        return nil
    }


    // MARK: - TableView Data Source Delegate Functions

    override func numberOfSections(in tableView: UITableView) -> Int {

        // There is only one section in the device list table
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        // Return the number of devices discovered so far
        return self.devices.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        // Return a standard size for now
        return 52;
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let aDevice: Device = self.devices[indexPath.row]

        if aDevice.devID == "NONE" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "devicetabledevicecellalt", for: indexPath)
            cell.textLabel?.text = aDevice.name
            return cell
        } else {
            // Dequeue a cell and populate it with the data we have on the discovered device
            let cell = tableView.dequeueReusableCell(withIdentifier: "devicetabledevicecellloading", for: indexPath) as! LoadingTableViewCell
            cell.myTitle?.text = aDevice.name
            cell.myImage?.image = aDevice.type.count > 0 ? UIImage.init(named: aDevice.type) : UIImage.init(named: "unknown")
            
            if aDevice.devID == "TBD" {
                cell.mySubtitle?.text = "Retrieving... enter the device PIN if requested"
                cell.progressIndicator.startAnimating()
            } else {
                cell.mySubtitle?.text = aDevice.devID + (aDevice.type.count > 0 ? " (\(aDevice.type))" : "Unknown")
                cell.progressIndicator.stopAnimating()
            }
            
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        // Get the device details and check for the initial instruction row
        let aDevice: Device = self.devices[indexPath.row]

        // Does the device use a PIN? If not, close the connection to save energy
        // NOTE We could close the connection in either case, but we don't in the case
        //      of secure connections to save re-requesting the PIN in the next phase
        //      (see DeviceDetailViewController.swift)
        if !aDevice.requiresPin && aDevice.peripheral != nil {
            self.bluetoothManager.cancelPeripheralConnection(aDevice.peripheral)
            aDevice.isConnected = false
        }

        // Don't allow the device to be selected if it's still being discovered
        if aDevice.devID == "TBD" {
            tableView.deselectRow(at: indexPath, animated: false)
            return
        }

        // Check for an API key - we can't proceed without one
        if self.harvey.count == 0 {
            // Ask the user to enter a key
            // ***ENABLE AFTER TESTING***
            //getRawkey()
            //return
        }

        // Now that a device has been selected, stop any scan currently taking place.
        // We do this in case the user taps on a device mid-scan
        endScan(false)

        // Instantiate the device detail view controller
        if ddvc == nil {
            let storyboard = UIStoryboard.init(name:"Main", bundle:nil)
            let adc = storyboard.instantiateViewController(withIdentifier:"devicedetailview") as! DeviceDetailViewController
            self.ddvc = adc
            self.ddvc!.bluetoothManager = self.bluetoothManager
            self.ddvc!.navigationItem.title = aDevice.devID
            self.ddvc!.harvey = self.harvey
            self.ddvc!.agentURL = aDevice.agent
            self.ddvc!.connected = aDevice.isConnected

            // Set up the left-hand nav bar button with an icon and text
            let button = UIButton(type: UIButton.ButtonType.system)
            button.setImage(UIImage(named: "icon_back"), for: UIControl.State.normal)
            button.setTitle("Devices", for: UIControl.State.normal)
            button.tintColor = UIColor.init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            button.sizeToFit()
            button.addTarget(self.ddvc, action: #selector(self.ddvc!.goBack), for: UIControl.Event.touchUpInside)
            self.ddvc!.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
        }

        // Set DeviceDetailViewController's current device
        self.ddvc!.device = aDevice

        // Present the device detail view controller
        self.navigationController!.pushViewController(self.ddvc!, animated: true)
    }


    // MARK: - CBManagerDelegate Functions

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        // This delegate method is called when the app discovers other Bluetooth devices. Since we are only
        // scanning for devices offering a service with UUID FADA47BE-C455-48C9-A5F2-AF7CF368D719, this should
        // only be called by the device's Squirrel application

        let device: Device = Device()
        device.name = peripheral.name != nil ? peripheral.name! : "Unknown"
        
        // Connect to the peripheral immediately to get extra data, ie. device ID
        peripheral.delegate = self
        self.bluetoothManager.connect(peripheral, options: nil)

        // Add the discovered device to the table
        device.peripheral = peripheral
        self.devices.append(device)
        self.devicesTable.reloadData()
        
        // Pick up the action at 'centralManager.didConnect()'
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        // The app has connected to the peripheral (eg. imp004m)
        // This is the result of calling bluetoothManager.connect()

        if let aDevice: Device = getDevice(peripheral) {
            aDevice.isConnected = true
        }

        // Get a list of services
        peripheral.discoverServices(nil)
        
        // Pick up the asynchronous action at 'peripheral(didDiscoverServices)'
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        // The app has disconnected from a peripheral
        if let aDevice: Device = getDevice(peripheral) {
            aDevice.isConnected = false
        }
        
        if (error != nil) {
            NSLog("centralManager(didFailToConnect) error: \(error!.localizedDescription)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {

        // The app has disconnected from a peripheral
        if let aDevice: Device = getDevice(peripheral) {
            aDevice.isConnected = false
        }

        if (error != nil) {
            NSLog("centralManager(didDisconnectPeripheral) error: \(error!.localizedDescription)")
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {

        // This is called to inform us whether Bluetooth LE is available on the device
        // It won't available if powered down, or access is not authorized for the app
        let cbm = central as CBManager
        if cbm.state != CBManagerState.poweredOn {
            self.showAlert("Bluetooth LE Disabled", "Please ensure that Bluetooth is powered up on your iPhone")
            self.gotBluetooth = false
        } else {
            self.gotBluetooth = true
        }
    }


    // MARK: - CBPeripheral Delegate Functions

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {

        // The app has discovered services offered by the peripheral (ie. the imp004m).
        // This is the result of calling 'peripheral.discoverServices()'
        if error == nil {
            var gotBlinkUp: Bool = false
            if let services = peripheral.services {
                if let aDevice = getDevice(peripheral) {
                    aDevice.services = services
                    NSLog("\(aDevice.name): \(services.count) services discovered")
                    
                    for i in 0..<services.count {
                        let service: CBService = services[i]
                        if service.uuid.uuidString == BLINKUP_SERVICE_UUID {
                            // The device is offering the BLINKUP service, so we're good to continue
                            gotBlinkUp = true
                            break
                        }
                    }

                    if !gotBlinkUp {
                        // Device is not serving the device info so disonnect from it...
                        self.bluetoothManager.cancelPeripheralConnection(peripheral)

                        // ...and remove it from the table
                        if let i = self.devices.firstIndex(of: aDevice) {
                            self.devices.remove(at: i)
                            self.devicesTable.reloadData()
                        }
                    } else {
                        // We know the device is offering the BLINKUP service, so now go and get
                        // some device info via the DEVICE_INFO service.
                        for i in 0..<services.count {
                            let service: CBService = services[i]
                            if service.uuid.uuidString == DEVICE_INFO_SERVICE_UUID {
                                // The device is offering the DEVICE_INFO service, so ask for a list of the all (hence 'nil')
                                // of the service's characteristics. This asynchronous call will be picked up by
                                // 'peripheral(didDiscoverCharacteristicsFor)'
                                peripheral.discoverCharacteristics(nil, for: service)
                            }

                            if service.uuid.uuidString == BLINKUP_SERVICE_UUID {
                                // While we're at it get all the BLINKUP service's characteristics
                                peripheral.discoverCharacteristics(nil, for: service)
                            }
                        }
                    }
                }
            }
        } else {
            // Log the error
            NSLog("peripheral(didDiscoverServices) error: \(error!.localizedDescription)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,  error: Error?) {
        
        // The app has discovered the characteristics offered by the peripheral (ie. the imp004m) for
        // specific service. This is the result of calling 'peripheral.discoverCharacteristics()'
        if error == nil {
            // Store the discovered characteristics in a dictionary
            if let list = service.characteristics {
                if let aDevice: Device = getDevice(peripheral) {
                    // Store a reference to the service's characteristics:
                    // within a dictionary whose keys are service UUIDs as strings, and
                    // whose values are arrays for CBCharacteristic objects
                    aDevice.characteristics[service.uuid.uuidString] = list
                    NSLog("\(aDevice.name): service \(service.uuid.uuidString) has \(list.count) characteristics")
                }
                
                // Now request the device serial number (proxy for the imp's device ID)
                if service.uuid.uuidString == DEVICE_INFO_SERVICE_UUID {
                    for i in 0..<list.count {
                        let ch:CBCharacteristic? = list[i]
                        if ch != nil {
                            if ch!.uuid.uuidString == DEVICE_INFO_SERIAL_CHARACTERISTIC_UUID {
                                // The peripheral DOES contain the expected characteristic,
                                // so read the characteristic's value. When it has been read,
                                // 'peripheral.didUpdateValueFor()' will be called
                                // NOTE Trying to read the value may cause a PIN entry request to be
                                //      made by iOS if BLE security is set by the imp to mode 3 or 4
                                peripheral.readValue(for: ch!)
                                break
                            }
                        }
                    }
                }
            }
        } else {
            // Log the error
            NSLog("peripheral(didDiscoverCharacteristicsFor) error: \(error!.localizedDescription)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        if (error != nil) {
            NSLog("peripheral(didUpdateValueFor) error: \(error!.localizedDescription)")
        }
        
        // We have attempted to read the imp004m application's device ID characteristic's value
        // This is the first characteristic we ask for, so it will trigger the PIN request
        // ie. we only need monitor PIN-ing for this characteristic
        if characteristic.uuid.uuidString == DEVICE_INFO_SERIAL_CHARACTERISTIC_UUID {
            if let data = characteristic.value {
                if data.count > 0 {
                    // We have successfully received data from the device
                    if let aDevice = getDevice(peripheral) {
                        // Add the received device ID to the device record
                        aDevice.devID = String.init(data: data, encoding: String.Encoding.utf8)!
                        aDevice.state = PERIPHERAL_STATE_GOT
                        self.devicesTable.reloadData()

                        // Now get the rest of the characteristics that we're interested in at this point
                        // First, get the DEVICE_INFO > MODEL_TYPE and DEVICE_INFO > AGENT_URL characteristics
                        var a = aDevice.characteristics[DEVICE_INFO_SERVICE_UUID]!
                        for i in 0..<a.count {
                            let cb:CBCharacteristic = a[i]
                            if cb.uuid.uuidString == DEVICE_INFO_MODEL_CHARACTERISTIC_UUID || cb.uuid.uuidString == DEVICE_INFO_AGENT_CHARACTERISTIC_UUID {
                                peripheral.readValue(for: cb)
                            }
                        }

                        // Next, get the BLINKUP > WIFI_LIST characteristic
                        a = aDevice.characteristics[BLINKUP_SERVICE_UUID]!
                        for i in 0..<a.count {
                            let cb:CBCharacteristic = a[i]
                            if cb.uuid.uuidString == BLINKUP_WIFIGET_CHARACTERISTIC_UUID {
                                peripheral.readValue(for: cb)
                                break
                            }
                        }
                    }
                } else {
                    // Access to the value has not yet been authorized by PIN, so
                    // attempt to read the value again in three seconds' time (by
                    // when the value might have neen unlocked, or blocked)
                    if let aDevice = getDevice(peripheral) {
                        aDevice.requiresPin = true
                        let a: [Any] = [peripheral, characteristic]
                        if self.pinTimer == nil || !self.pinTimer.isValid {
                            self.pinTimer = Timer.scheduledTimer(timeInterval: 1.0,
                                                                 target: self,
                                                                 selector: #selector(self.attemptRead),
                                                                 userInfo: a,
                                                                 repeats: false)
                        }
                    }
                }
            }
        } else if characteristic.uuid.uuidString == DEVICE_INFO_MODEL_CHARACTERISTIC_UUID {
            if let data = characteristic.value {
                if data.count > 0 {
                    if let aDevice = getDevice(peripheral) {
                        // Add the imp model type to the device record
                        aDevice.type = String.init(data: data, encoding: String.Encoding.utf8)!
                        self.devicesTable.reloadData()
                    }
                } else {
                    peripheral.readValue(for: characteristic)
                }
            }
        } else if characteristic.uuid.uuidString == DEVICE_INFO_AGENT_CHARACTERISTIC_UUID {
            if let data = characteristic.value {
                if data.count > 0 {
                    if let aDevice = getDevice(peripheral) {
                        // Add the imp agent URL to the device record
                        aDevice.agent = String.init(data: data, encoding: String.Encoding.utf8)!
                        if aDevice.agent == "null" { aDevice.agent = "" }
                    }
                } else {
                    peripheral.readValue(for: characteristic)
                }
            }
        } else if characteristic.uuid.uuidString == BLINKUP_WIFIGET_CHARACTERISTIC_UUID {
            if let data = characteristic.value {
                if data.count > 0 {
                    if let networkList:String = String.init(data: data, encoding: String.Encoding.utf8) {
                        if let aDevice = getDevice(peripheral) {
                            // Add the scanned network list to the device record
                            aDevice.networks = networkList
                        }
                    }
                } else {
                    peripheral.readValue(for: characteristic)
                }
            }
        }
    }

    @objc func attemptRead(_ timer: Timer) {
        
        // A callback triggered by 'pinTimer'. When it fires, get the current peripheral
        // and characteristic (saved to 'userInfo') and attempt to read the value again
        var a: [Any] = timer.userInfo as! [Any]
        let p: CBPeripheral = a[0] as! CBPeripheral
        
        pinCount = pinCount + 1
        if pinCount < PIN_COUNT_MAX {
            let c: CBCharacteristic = a[1] as! CBCharacteristic
            p.readValue(for: c)
        } else {
            pinCount = 0
            showAlert("Bluetooth LE PIN", "Please enter a valid Bluetooth LE PIN code")
            self.endScan(false)
            initTable()
            if let aDevice = getDevice(p) {
                self.bluetoothManager.cancelPeripheralConnection(p)
                aDevice.isConnected = false
            }
        }
    }
    
    
    // MARK: - Keychain Functions

    func getHarvey() -> String? {

        // Attempt to get the user's BlinkUp API Key from the iOS keychain
        var key: String?

        do {
            let pw = KeychainItem(service: "com.ei.BluetoothBlinkUp",
                                  account: "com.ei.sample.ble",
                                  accessGroup: nil)
            key = try pw.readPassword()
        } catch {
            key = nil
        }

        return key
    }

    func setHarvey(_ key: String) {

        // Attempt to save the user's BlinkUp API Key to the iOS keychain
        do {
            let pw = KeychainItem(service: "com.ei.BluetoothBlinkUp",
                                  account: "com.ei.sample.ble",
                                  accessGroup: nil)
            try pw.savePassword(key)
        } catch {
            NSLog("Key save failure")
        }
    }

    func getRawkey() {

        // Show an alert requesting the user's BlinkUp API Key - which will be stored in the keychain
        keyEntryController = UIAlertController.init(title: "Please Enter Your\nBlinkUp API Key",
                                                    message: "BlinkUp API Keys are available to\nElectric Imp customers only.\nLeave the field blank to remove your key from this app.",
                                                    preferredStyle: UIAlertController.Style.alert)

        keyEntryController.addTextField(configurationHandler: { (textField) in
            textField.isSecureTextEntry = true
            textField.placeholder = "BlinkUp API key"
        })

        keyEntryController.addAction(UIAlertAction.init(title: "Submit",
                                                        style: UIAlertAction.Style.default,
                                                        handler: { (alertAction) in
            // When the user taps 'Submit', we get the text field contents and pass
            // it to 'setHarvey()' to save it in the keychain
            if let fields = self.keyEntryController.textFields {
                let field = fields[0]
                if let key = field.text {
                    if key.count > 0 {
                        self.harvey = key
                        self.setHarvey(self.harvey)
                        NSLog("Key saved")
                    } else {
                        if self.harvey.count > 0 {
                            let pw = KeychainItem(service: "com.ei.BluetoothBlinkUp",
                                                  account: "com.ei.sample.ble",
                                                  accessGroup: nil)
                            do {
                                try pw.deleteItem()
                                self.harvey = ""
                                NSLog("Key Deleted")
                            } catch {
                                NSLog("Key Deleted")
                            }
                        }
                    }
                }
            }
        }))

        keyEntryController.addAction(UIAlertAction.init(title: "Cancel",
                                                        style: UIAlertAction.Style.cancel,
                                                        handler: nil))
        keyWindowUp = true
        self.present(keyEntryController,
                     animated: true,
                     completion: { () in
                        self.keyWindowUp = true })
    }
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
