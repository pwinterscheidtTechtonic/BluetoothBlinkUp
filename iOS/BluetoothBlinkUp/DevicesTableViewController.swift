
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
import Security


class DevicesTableViewController: UITableViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    @IBOutlet weak var devicesTable: UITableView!
    @IBOutlet weak var infoGesture: UILongPressGestureRecognizer!

    var bluetoothManager: CBCentralManager!
    var devices: [Device] = []
    var ddvc: DeviceDetailViewController!
    var keyEntryController: UIAlertController!
    var alert: UIAlertController? = nil
    var harvey: String = ""
    var keyWindowUp: Bool = false
    var scanTimer: Timer!
    var scanning: Bool = false
    var gotBluetooth: Bool = false

    // Constants
    let DEVICE_SCAN_TIMEOUT = 15.0

    
    // MARK: - View lifecycle functions

    override func viewDidLoad() {

        super.viewDidLoad()

        // Set up the table's selection persistence
        self.clearsSelectionOnViewWillAppear = false

        // Initialise object properties
        self.ddvc = nil

        // Instantiate the CoreBluetooth manager
        self.bluetoothManager = CBCentralManager.init(delegate: self, queue: nil, options: nil)

        // Set up the Navigation Bar with an Edit button
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "Actions", style: UIBarButtonItemStyle.plain, target: self, action: #selector(self.showActions))
        self.navigationItem.rightBarButtonItem!.tintColor = UIColor.white

        // Set up the Navigation Bar with a pro
        self.navigationItem.title = "Devices"

        // Watch for app returning to foreground from the ImpDetailViewController
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.viewWillAppear),
                                               name: NSNotification.Name.UIApplicationWillEnterForeground,
                                               object: nil)

        // Watch for app going to background with ImpDetailViewController active
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.closeUp),
                                               name: NSNotification.Name.UIApplicationWillResignActive,
                                               object: nil)

        // Add a long-press gesture to the UITableView to pop up the Info panel
        infoGesture.addTarget(self, action: #selector(showInfo))
        devicesTable.addGestureRecognizer(infoGesture)
        
        // Initialize the device list
        initTable()

        // Set up the refresh control - the searching indicator
        self.refreshControl = UIRefreshControl.init()
        self.refreshControl!.backgroundColor = UIColor.init(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        self.refreshControl!.tintColor = UIColor.black
        self.refreshControl!.attributedTitle = NSAttributedString.init(string: "Searching for Bluetooth-enabled imps...", attributes: [ NSAttributedStringKey.foregroundColor : UIColor.black ])
        self.refreshControl!.addTarget(self, action: #selector(self.startScan), for: UIControlEvents.valueChanged)
    }

    override func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)

        // Load the user's API key from the Keychain
        if let key = getHarvey() {
            self.harvey = key
        } else {
            // There is no saved API key so get one by presenting
            // the key request panel
            // UPDATE 1/24/18 Make it optional, ie. not run at startup
            // getRawkey()
        }

        if self.ddvc != nil { self.ddvc = nil }
    }


    // MARK: - Device scanning functions

    @objc func startScan() {

        if self.gotBluetooth {
            // Begin scanning if we are not scanning already
            if !self.scanning {
                // Clear the current list of discovered devices and redraw the table
                devices.removeAll()
                devicesTable.reloadData()

                // Start scanning for the imp004m GATT server by using its key GATT service UUID
                let s:CBUUID = CBUUID(string: "FADA47BE-C455-48C9-A5F2-AF7CF368D719")
                self.bluetoothManager.delegate = self
                self.bluetoothManager.scanForPeripherals(withServices:[s], options:nil)
                self.scanning = true

                // Set up a timer to cancel the scan automatically after DEVICE_SCAN_TIMEOUT seconds
                self.scanTimer = Timer.scheduledTimer(timeInterval: DEVICE_SCAN_TIMEOUT, target: self, selector: #selector(self.endScanWithAlert), userInfo: nil, repeats: false)
            } else {
                // We're already scanning so just cancel the scan
                endScan(false)
            }
        } else {
            if self.refreshControl!.isRefreshing {
                self.refreshControl!.endRefreshing()
                self.devicesTable.reloadData()
            }
            showAlert("Bluetooth LE Disabled", "Please ensure the Bluetooth is powered up on your iPhone")
        }
    }

    @objc func endScanWithAlert() {

        endScan(true)
    }

    func endScan(_ showAnAlert: Bool) {

        // Only proceed to cancel the scan if a scan is taking place
        if self.scanning {
            // Deal with the timer - it will still be running if we are cancelling manualluy
            if self.scanTimer.isValid {
                self.scanTimer.invalidate()
            }

            // Cancel the scan
            self.scanning = false
            self.bluetoothManager.stopScan()

            // Warn the user
            if devices.count == 0 && showAnAlert {
                showAlert("No Bluetooth-enabled imp Devices Found", "")
                initTable()
            }

            // Hide the refresh control
            self.refreshControl!.endRefreshing()
        }
    }
    
    func initTable() {
        
        // Add an instruction line to the table.
        // This used deviceID = NO to indicte its type to the app, eg. to prevent the
        // row being selected. This line will be clear when the user scans for devices
        let text: Device = Device()
        text.name = "Pull down to search for Bluetooth-enabled imps"
        text.devID = "NO"
        devices.append(text)
        devicesTable.reloadData()
    }

    @objc func closeUp() {

        // The app is going into the background so cancel any scan taking place
        endScan(false)

        // Remove the API key input window if it's visible
        if keyWindowUp {
            keyEntryController.removeFromParentViewController()
        }

        // Cancel any open connections to devices that we may have
        if devices.count > 0 {
            for i in 0..<devices.count {
                let aDevice: Device = devices[i]
                if aDevice.devID != "NO" {
                    self.bluetoothManager.cancelPeripheralConnection(aDevice.peripheral)
                }
            }
        }
    }


    // MARK: - Utility functions

    @objc func showActions() {

        let actionMenu = UIAlertController.init(title: "Select an Action from the List Below", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        var action: UIAlertAction!

        // Add the 'start scan' or 'cancel scan' action button
        if self.scanning {
            // We're currently scanning, so present the Cancel Scan option
            action = UIAlertAction.init(title: "Cancel Scan", style: UIAlertActionStyle.default) { (alertAction) in
                self.endScan(true)
            }
        } else {
            // We are not scanning, so present the Start Scan button
            action = UIAlertAction.init(title: "Start Scan", style: UIAlertActionStyle.default) { (alertAction) in
                self.refreshControl!.beginRefreshing()
                self.startScan()
            }
        }

        actionMenu.addAction(action)

        // Construct and add the other buttons
        action = UIAlertAction.init(title: "Show App Info", style: UIAlertActionStyle.default) { (alertAction) in
            self.showInfo()
        }

        actionMenu.addAction(action)

        action = UIAlertAction.init(title: "Visit the Electric Imp Store", style: UIAlertActionStyle.default) { (alertAction) in
            self.goToShop()
        }

        actionMenu.addAction(action)

        action = UIAlertAction.init(title: "Enter Your BlinkUp™ API Key", style: UIAlertActionStyle.default) { (alertAction) in
            self.getRawkey()
        }

        actionMenu.addAction(action)

        action = UIAlertAction.init(title: "Cancel", style: UIAlertActionStyle.cancel, handler:nil)

        actionMenu.addAction(action)

        self.present(actionMenu, animated: true, completion: nil)
    }

    @objc func showInfo() {

        devicesTable.removeGestureRecognizer(infoGesture)
        let alert = UIAlertController.init(title: "App\nInformation", message: "This sample app can be used to activate Bluetooth-enabled Electric Imp devices, such as the imp004m. Tap ‘Scan’ to find local devices (these must be running the accompanying Squirrel device code) and then select a device to set its WiFi credentials. The selected device will automatically provide a list of compatible networks — just select one from the list and enter its password (or leave the field blank if it has no password). Tap ‘Send BlinkUp’ to configure the device. The app will inform you when the device has successfully connected to the Electric Imp impCloud™", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true) {
            self.devicesTable.addGestureRecognizer(self.infoGesture)
        }
    }

    @objc func goToShop() {

        // Open the EI shop in Safari
        let uiapp = UIApplication.shared
        let url: URL = URL.init(string: "https://store.electricimp.com/")!
        uiapp.open(url, options: [:], completionHandler: nil)
    }

    func showAlert(_ title: String, _ message: String) {
        self.alert = UIAlertController.init(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        self.alert!.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .`default`, handler: nil))
        self.present(self.alert!, animated: true) {
            self.alert = nil
        }
    }

    func getDevice(_ peripheral: CBPeripheral) -> Device? {

        // Return the Device object for the specified peripheral - or nil

        if devices.count == 0 { return nil }

        for i in 0..<devices.count {
            let aDevice: Device = devices[i]
            if aDevice.peripheral == peripheral { return aDevice }
        }

        return nil
    }


    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {

        // There is only one section in the device list table
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        // Return the number of devices discovered so far
        return devices.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let aDevice: Device = devices[indexPath.row]

        if aDevice.devID == "NO" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "devicetabledevicecellalt", for: indexPath)
            cell.textLabel?.text = aDevice.name
            return cell
        } else {
            // Dequeue a cell and populate it with the data we have on the discovered device
            let cell = tableView.dequeueReusableCell(withIdentifier: "devicetabledevicecell", for: indexPath)
            cell.textLabel?.text = aDevice.name
            cell.detailTextLabel?.text = aDevice.devID + (aDevice.type.count > 0 ? " (\(aDevice.type))" : "")
            if aDevice.type != "" {
                cell.imageView?.image = UIImage.init(named: aDevice.type)
            } else {
                cell.imageView?.image = nil
            }
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        // Get the device details and check for the initial instruction row
        let aDevice: Device = devices[indexPath.row]
        if aDevice.devID == "NO" {
            tableView.deselectRow(at: indexPath, animated: false)
            return
        }

        // Check for an API key - we can't proceed without one
        // UPDATE 24/1/18 - Don't check for an API key
        if self.harvey.count == 0 {
            // Ask the user to enter a key
            // getRawkey()
            // return
        }

        // Now that a device has been selected, stop any scan currently taking place.
        // We do this in case the user taps on a device mid-scan
        endScan(false)

        // Instantiate the device detail view controller
        if ddvc == nil {
            let storyboard = UIStoryboard.init(name:"Main", bundle:nil)
            self.ddvc = storyboard.instantiateViewController(withIdentifier:"devicedetailview") as! DeviceDetailViewController
            self.ddvc.bluetoothManager = self.bluetoothManager
            self.ddvc.navigationItem.title = aDevice.devID
            self.ddvc.harvey = self.harvey

            // Set up the left-hand nav bar button with an icon and text
            let button = UIButton(type: UIButtonType.system)
            button.setImage(UIImage(named: "icon_back"), for: UIControlState.normal)
            button.setTitle("Devices", for: UIControlState.normal)
            button.tintColor = UIColor.init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            button.sizeToFit()
            button.addTarget(self.ddvc, action: #selector(self.ddvc.goBack), for: UIControlEvents.touchUpInside)
            self.ddvc.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
        }

        // Set DeviceDetailViewController's current device
        self.ddvc.device = aDevice

        // Present the device detail view controller
        self.navigationController!.pushViewController(self.ddvc, animated: true)
    }


    // MARK: - CBManagerDelegate Functions

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        // This delegate method is called when the app discovers other Bluetooth devices. Since we are only
        // scanning for devices offering a service with UUID FADA47BE-C455-48C9-A5F2-AF7CF368D719, this should
        // only be called by the device's Squirrel application

        let device: Device = Device()

        if let name = peripheral.name {
            device.name = name
        } else {
            device.name = "Unknown"
        }

        // Connect to the peripheral immediately to get extra data, ie. device ID
        peripheral.delegate = self
        self.bluetoothManager.connect(peripheral, options: nil)

        // Add the discovered device to the table
        device.peripheral = peripheral
        devices.append(device)
        devicesTable.reloadData()
        //self.refreshControl!.endRefreshing()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        // The app has connected to the peripheral (eg. imp004m)
        // This is the result of calling bluetoothManager.connect()

        if let aDevice: Device = getDevice(peripheral) {
            aDevice.isConnected = true
        }

        peripheral.discoverServices(nil)
        // Pick up the action at 'peripheral.didDiscoverServices()'
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {

        // The app has disconnected from a peripheral
        if let aDevice: Device = getDevice(peripheral) {
            aDevice.isConnected = false
        }

        if (error != nil) {
            print("\(error!.localizedDescription)")
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {

        // This is called to inform us whether Bluetooth LE is available on the device
        // If won't available if powered down, or not authorized

        let cbm = central as CBManager
        if cbm.state != CBManagerState.poweredOn {
            self.showAlert("Bluetooth LE Disabled", "Please ensure that Bluetooth is powered up on your iPhone")
            self.gotBluetooth = false
        } else {
            self.gotBluetooth = true
        }
    }


    // MARK: - CBPeripheral Delegate functions

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {

        // The app has discovered services offered by the peripheral (ie. the imp004m).
        // This is the result of calling 'peripheral.discoverServices()'
        if error == nil {
            var got: Bool = false
            if let services = peripheral.services {
                for i in 0..<services.count {
                    let service: CBService = services[i]
                    if service.uuid.uuidString == "180A" {
                        // The device is offering the 'device info' service, so ask for a list of the all (hence 'nil') of the service's characteristics.
                        // This asynchronous call will be picked up by 'peripheral.didDiscoverCharacteristicsFor()'
                        peripheral.discoverCharacteristics(nil, for: service)
                        got = true
                        break
                    }
                }

                if !got {
                    // Device is not serving the device info
                    if let aDevice: Device = getDevice(peripheral) {
                        aDevice.devID = "Unknown"
                        devicesTable.reloadData()
                        self.bluetoothManager.cancelPeripheralConnection(peripheral)
                    }
                }
            }
        } else {
            // Log the error
            print("\(error!.localizedDescription)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,  error: Error?) {
        
        // The app has discovered the characteristics offered by the peripheral (ie. the imp004m) for
        // specific service. This is the result of calling 'peripheral.discoverCharacteristics()'
        if error == nil {
            // Run through the list of peripheral characteristics to see if it contains
            // the imp004m application's networks list characteristic by looking for the
            // characteristics's known UUID
            var got: Bool = false
            if let list = service.characteristics {
                if let aDevice: Device = getDevice(peripheral) {
                    aDevice.characteristics = list
                }

                for i in 0..<list.count {
                    let ch:CBCharacteristic? = list[i]
                    if ch != nil {
                        if ch!.uuid.uuidString == "2A25" {
                            // The peripheral DOES contain the expected characteristic,
                            // so read the characteristics value. When it has been read,
                            // 'peripheral.didUpdateValueFor()' will be called
                            peripheral.readValue(for: ch!)
                            got = true
                            break
                        }
                    }
                }

                if !got {
                    // Device is not serving the device info ID characteristic
                    if let aDevice: Device = getDevice(peripheral) {
                        aDevice.devID = "Unknown"
                        devicesTable.reloadData()
                        self.bluetoothManager.cancelPeripheralConnection(peripheral)
                    }
                }
            }
        } else {
            // Log the error
            print("\(error!.localizedDescription)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        // We have successfully read the imp004m application's device ID characteristic's value
        if characteristic.uuid.uuidString == "2A25" {
            if let data = characteristic.value {
                if let aDevice = getDevice(peripheral) {
                    // Add the device ID to the device record
                    aDevice.devID = String.init(data: data, encoding: String.Encoding.utf8)!
                    devicesTable.reloadData()

                    for i in 0..<aDevice.characteristics.count {
                        let ch:CBCharacteristic? = aDevice.characteristics[i]
                        if ch != nil {
                            if ch!.uuid.uuidString == "2A24" {
                                // The peripheral DOES contain the expected characteristic,
                                // so read the characteristics value. When it has been read,
                                // 'peripheral.didUpdateValueFor()' will be called
                                peripheral.readValue(for: ch!)
                                break
                            }
                        }
                    }
                }
            }
        } else {
            if let data = characteristic.value {
                if let aDevice = getDevice(peripheral) {
                    // Add the device ID to the device record
                    aDevice.type = String.init(data: data, encoding: String.Encoding.utf8)!
                    devicesTable.reloadData()

                    // Disconnect now we have the data
                    self.bluetoothManager.cancelPeripheralConnection(peripheral)
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {

        // This will be called when a value is written to the peripheral via GATT
        // The first time a write is made, iOS will manage the pairing. Only if the pairing
        // succeeds will this delegate method be called (because if pairing fails, no value
        // will be written the delegate will not be called).
        if error != nil {
            NSLog("Whoops")
            return;
        } else {
            NSLog("Written")


        }
    }


    // MARK: - Keychain Functions

    func getHarvey() -> String? {

        // Attempt to get the user's BlinkUp API Key from the iOS keychain
        var key: String?

        do {
            let pw = KeychainItem(service: "com.ei.BluetoothBlinkUp", account: "com.ei.sample.ble", accessGroup: nil)
            key = try pw.readPassword()
        } catch {
            key = nil
        }

        return key
    }

    func setHarvey(_ key: String) {

        // Attempt to save the user's BlinkUp API Key to the iOS keychain
        do {
            let pw = KeychainItem(service: "com.ei.BluetoothBlinkUp", account: "com.ei.sample.ble", accessGroup: nil)
            try pw.savePassword(key)
        } catch {
            print("Key save failure")
        }
    }

    func getRawkey() {

        // Show an alert requesting the user's BlinkUp API Key - which will be stored in the keychain
        keyEntryController = UIAlertController.init(title: "Please Enter Your\nBlinkUp API Key", message: "BlinkUp API Keys are available to\nElectric Imp customers only\nLeave the field blank to clear your key", preferredStyle: UIAlertControllerStyle.alert)
        keyEntryController.addTextField(configurationHandler: { (textField) in
            textField.isSecureTextEntry = true
        })

        keyEntryController.addAction(UIAlertAction.init(title: "Submit", style: UIAlertActionStyle.default, handler: { (alertAction) in
            // When the user taps 'Submit', we get the text field contents and pass
            // it to 'setHarvey()' to save it in the keychain
            if let fields = self.keyEntryController.textFields {
                let field = fields[0]
                if let key = field.text {
                    if key.count > 0 {
                        self.harvey = key
                        self.setHarvey(self.harvey)
                        print("Key saved")
                    } else {
                        if self.harvey.count > 0 {
                            let pw = KeychainItem(service: "com.ei.BluetoothBlinkUp", account: "com.ei.sample.ble", accessGroup: nil)
                            do {
                                try pw.deleteItem()
                                self.harvey = ""
                                print("Key Deleted")
                            } catch {
                                print("Key Not Deleted")
                            }
                        }
                    }
                }
            }
        }))

        keyEntryController.addAction(UIAlertAction.init(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        keyWindowUp = true
        self.present(keyEntryController, animated: true, completion: { () in
            self.keyWindowUp = true
        })
    }

}
