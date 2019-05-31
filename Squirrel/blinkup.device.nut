//  ------------------------------------------------------------------------------
//  File: blinkup.device.nut
//
//  Version: 1.1.3
//
//  Copyright 2017-19 Electric Imp
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
//  ------------------------------------------------------------------------------

#require "bt_firmware.lib.nut:1.0.0"

const BTLE_BLINKUP_WIFI_SCAN_INTERVAL = 120;

class BTLEBlinkUp {

    static VERSION = "2.0.1";

    // Public instance properties
    ble = null;
    agentURL = null;

    // Private instance properties
    _uuids = null;
    _blinkup = null;
    _incoming = null;
    _incomingCB = null;
    _networks = null;
    _pin_LPO_IN = null;
    _pin_BT_REG_ON = null;
    _uart = null;
    _blinking = false;
    _scanning = false;

    // ********** CONSTRUCTOR **********

    constructor(uuids = null, lpoPin = null, regonPin = null, uart = null) {
        // Apply the BlinkUp service's UUIDs, or the defaults if none are provided
        if (uuids == null || typeof uuids != "table" || uuids.len() != 8) throw "BTLEBlinkUp requires service UUIDs to be provided as an 8-key table";
        if (!_checkUUIDs(uuids)) throw "BTLEBlinkUp requires the service UUID table to contain specific key names";
        _uuids = uuids;

        // Set the BLE radio pins, either to the passed in values, or the defaults
        // Defaults to the imp004m Breakout Board
        _pin_LPO_IN = lpoPin != null ? lpoPin : hardware.pinE;
        _pin_BT_REG_ON = regonPin != null ? regonPin : hardware.pinJ;
        _uart = uart != null ? uart : hardware.uartFGJH;

        // Initialize the radio
        _init();
    }

    // ********** PUBLIC FUNCTIONS **********

    function listenForBlinkUp(advert = null, callback = null) {
        // This is a convenience method for serving BlinkUp. It assumes that you have already specified
        // the required level of security, using setSecurity(). It uses default values for advertising
        // min. and max. interval values, and serves only the BlinkUp and Device Information services
        serve();
        onConnect(callback);
        advertise(advert);
    }

    function setSecurity(mode = 1, pin = "000000") {
        // Specify the Bluetooth LE security mode (and PIN) as per bluetooth.setsecurity()
        // It will default to no security (mode 1) in case of error
        // NOTE This needs to be run separately from listenForBlinkUp()

        if (ble == null) {
            server.error("BTLEBlinkUp.setSecurity() - Bluetooth LE not initialized");
            return 1;
        }

        // Check that a valid mode has been provided
        if (mode != 1 && mode != 3 && mode != 4) {
            server.error("BTLEBlinkUp.setSecurity() - undefined security mode selected");
            ble.setsecurity(1);
            return 1;
        }

        // Check that a PIN has been provided for modes 3 and 4
        if (pin == null && mode > 1) {
            server.error("BTLEBlinkUp.setSecurity() - security modes 3 and 4 require a PIN");
            ble.setsecurity(1);
            return 1;
        }

        // Parameter 'pin' should be a string or an integer and no more than six digits
        if (typeof pin == "string") {
            if (pin.len() > 6) {
                server.error("BTLEBlinkUp.setSecurity() - security PIN cannot be more than six characters");
                ble.setsecurity(1);
                return 1;
            }

            try {
                pin = pin.tointeger();
            } catch (err) {
                server.error("BTLEBlinkUp.setSecurity() - security PIN must contain only decimal numeric characters");
                ble.setsecurity(1);
                return 1;
            }
        } else if (typeof pin == "integer") {
            if (pin < 0 || pin > 999999) {
                server.error("BTLEBlinkUp.setSecurity() - security PIN must contain 1 to 6 digits");
                ble.setsecurity(1);
                return 1;
            }
        } else {
            server.error("BTLEBlinkUp.setSecurity() - security PIN must be a string or integer");
            ble.setsecurity(1);
            return 1;
        }

        if (mode == 1) {
            // Ignore the pin as it's not needed
            ble.setsecurity(1);
        } else {
            ble.setsecurity(mode, pin);
        }

        return mode;
    }

    function setAgentURL(url = "") {
        // Set the host device's agent's URL
        // This is included in the device info service data
        agentURL = typeof url == "string" ? url : "";
        return agentURL;
    }

    function serve(otherServices = null) {
        // Set up the Bluetooth GATT server
        // This always adds the BlinkUp service and standard Device Info service
        // The parameter 'otherServices' takes an array of one or more services which you would like
        // the device to provides in addition to BlinkUp and the standard Device Info service
        if (ble == null) {
            server.error("BTLEBlinkUp.serve() - Bluetooth LE not initialized");
            return;
        }

        // Define the BlinkUp service
        local service = {};
        service.uuid <- _uuids.blinkup_service_uuid;
        service.chars <- [];

        // Define the SSID setter characteristic
        local chrx = {};
        chrx.uuid <- _uuids.ssid_setter_uuid;
        chrx.flags <- 0x08;
        chrx.write <- function(conn, v) {
            _blinkup.ssid = v.tostring();
            _blinkup.updated = true;
            server.log("WiFi SSID set");
            return 0x0000;
        }.bindenv(this);
        service.chars.append(chrx);

        // Define the password setter characteristic
        chrx = {};
        chrx.uuid <- _uuids.password_setter_uuid;
        chrx.write <- function(conn, v) {
            _blinkup.pwd = v.tostring();
            _blinkup.updated = true;
            server.log("WiFi password set");
            return 0x0000;
        }.bindenv(this);
        service.chars.append(chrx);

        // Define the Plan ID setter characteristic
        chrx = {};
        chrx.uuid <- _uuids.planid_setter_uuid;
        chrx.write <- function(conn, v) {
            _blinkup.planid = v.tostring();
            _blinkup.updated = true;
            server.log("Plan ID set");
            return 0x0000;
        }.bindenv(this);
        service.chars.append(chrx);

        // Define the Enrollment Token setter characteristic
        chrx = {};
        chrx.uuid <- _uuids.token_setter_uuid;
        chrx.write <- function(conn, v) {
            _blinkup.token = v.tostring();
            _blinkup.updated = true;
            server.log("Enrolment Token set");
            return 0x0000;
        }.bindenv(this);
        service.chars.append(chrx);

        // Define a dummy setter characteristic to trigger the imp restart
        chrx = {};
        chrx.uuid <- _uuids.blinkup_trigger_uuid;
        chrx.write <- function(conn, v) {
            if (_blinkup.updated) {
                server.log("Device Activation triggered");
                _blinkup.update();
                return 0x0000;
            } else {
                return 0x1000;
            }
        }.bindenv(this);
        service.chars.append(chrx);

        // Define a dummy setter characteristic to trigger WiFi clearance
        chrx = {};
        chrx.uuid <- _uuids.wifi_clear_trigger_uuid;
        chrx.write <- function(conn, v) {
            server.log("Device WiFi clearance triggered");
            _blinkup.clear();
            return 0x0000;
        }.bindenv(this);
        service.chars.append(chrx);

        // Define the getter characteristic that serves the list of nearby WLANs
        chrx = {};
        chrx.uuid <- _uuids.wifi_getter_uuid;
        chrx.read <- function(conn) {
            // There's no http.jsonencode() on the device so stringify the key data
            // Networks are stored as "ssid[newline]open/secure[newline][newline]"
            // NOTE set _blinking to true so we don't asynchronously update the list
            // of networks while also using it here
            server.log("Sending WLAN list to app");
            local ns = "";
            _blinking = true;
            for (local i = 0 ; i < _networks.len() ; i++) {
                local network = _networks[i];
                ns = ns + network["ssid"] + "\n";
                ns = ns + (network["open"] ? "unlocked" : "locked") + "\n\n";
            }
            _blinking = false;

            // Remove the final two newlines
            ns = ns.slice(0, ns.len() - 2);
            return ns;
        }.bindenv(this);
        service.chars.append(chrx);

        // Offer the service we have just defined
        local services = [];
        services.append(service);

        // Device information service
        service = { "uuid": 0x180A,
                    "chars": [
                      { "uuid": 0x2A29, "value": "Electric Imp" },                          // manufacturer name
                      { "uuid": 0x2A25, "value": hardware.getdeviceid() },                  // serial number (device ID)
                      { "uuid": 0x2A24, "value": imp.info().type },                         // model number (imp type)
                      { "uuid": 0x2A23, "value": (agentURL != null ? agentURL : "TBD") },   // system ID (agent ID)
                      { "uuid": 0x2A26, "value": imp.getsoftwareversion() }]                // firmware version
                    };

        services.append(service);
        if (otherServices != null) {
            if (typeof otherServices == "array") {
                services.extend(otherServices);
            } else if (typeof otherServices == "table") {
                services.append(otherServices);
            }
        }
        ble.servegatt(services);
    }

    function advertise(advert = null, min = 100, max = 100) {
        // Begin advertising the device
        // NOTE If no argument is passed in to 'advert', the library will
        // build one of its own based on the BlinkUp service, but this will
        // leave the device unnamed
        if (ble == null) {
            server.error("BTLEBlinkUp.advertise() - Bluetooth LE not initialized");
            return;
        }

        // Check the 'min' and 'max' values
        if (min < 0 || min > 100) min = 100;
        if (max < 0 || max > 100) max = 100;
        if (min > max) {
          // Swap 'min' and 'max' around if 'min' is bigger than 'max'
          local a = max;
          max = min;
          min = a;
        }

        // Advertise the supplied advert then exit
        if (advert != null) {
            ble.startadvertise(advert, min, max);
            return;
        }

        // Otherwise build the advert packed based on the service UUID
        // NOTE We need to reverse the octet order for transmission
        local ss = _uuids.blinkup_service_uuid;
        local ns = imp.info().type;
        local ab = blob(ss.len() / 2 + ns.len() + 4);
        ab.seek(0, 'b');

        // Write in the BlinkUp service UUID:
        // Byte 0 - The data length
        ab.writen(ss.len() / 2 + 1, 'b');
        // Byte 1 - The data type flag (0x07)
        ab.writen(7, 'b');
        // Bytes 2+ — The UUID in little endian
        local maxs = ss.len() - 2;
        for (local i = 0 ; i < maxs + 2 ; i = i + 2) {
            local bs = ss.slice(maxs - i, maxs - i + 2)
            ab.writen(_hexStringToInt(bs), 'b');
        }

        // Write in the device name
        // Byte 0 - The length
        ab.writen(ns.len() + 1, 'b');
        // Byte 1 - The data type flag (0x09)
        ab.writen(9, 'b');
        // Bytes 2+ - The imp type as its name
        foreach (ch in ns) {
            ab.writen(ch, 'b');
        }

        ble.startadvertise(ab, min, max);
    }

    function onConnect(cb = null) {
        // Register the host app's connection/disconnection notification callback.
        // This callback takes a single parameter: a table which contains some or all
        // of the following keys:
        //   conn — the connection's imp API BluetoothConnection instance
        //   address - the connection's address
        //   security - the security mode of the connection (1, 3 or 4)
        //   state - the state of the connection: "connnected" or "disconnected"

        // Check for a valid Bluetooth instance
        if (ble == null) {
            server.error("BTLEBlinkUp.onConnect() - Bluetooth LE not initialized");
            return;
        }

        // Check for a valid connection/disconnection notification callback
        if (cb == null || typeof cb != "function") {
            server.error("BTLEBlinkUp.onConnect() requires a non-null callback");
            return;
        }

        // Store the host app's callback...
        _incomingCB = cb;

        // ...which will be triggered by the library's own
        // connection callback, _connectHandler()
        ble.onconnect(_connectHandler.bindenv(this));
    }

    // ********** PRIVATE FUNCTIONS - DO NOT CALL **********

    function _init() {
        // Boot up the Bluetooth radio: set up the power lines via GPIO
        // NOTE These require a suitably connected module - we can't check for that here
        _pin_LPO_IN.configure(DIGITAL_OUT, 0);
        _pin_BT_REG_ON.configure(DIGITAL_OUT, 1);

        // Scan for WiFi networks around the device
        local now = hardware.millis();
        _scan(false);

        // Set up the incoming data structure which includes a function to trigger
        // that handles the application of the received data
        _blinkup = {};
        _blinkup.ssid <- "";
        _blinkup.pwd <- "";
        _blinkup.planid <- "";
        _blinkup.token <- "";
        _blinkup.updated <- false;
        _blinkup.update <- function() {
            // Apply the received data
            // TODO check for errors
            // Close the existing connection to the mobile app
            if (_incoming != null) _incoming.close();
            _blinking = true;

            // Disconnect from the server
            server.flush(10);
            server.disconnect();

            // Apply the new WiFi details
            imp.setwificonfiguration(_blinkup.ssid, _blinkup.pwd);

            if (_blinkup.planid != "" && _blinkup.token != "") {
                // Only write the plan ID and enrollment token if they have been set
                // NOTE This is to support WiFi-only BlinkUp
                imp.setenroltokens(_blinkup.planid, _blinkup.token);
            }

            // Inform the host app about activation - it may use this, eg. to
            // write a 'has activated' signature to the SPI flash
            local data = { "activated": true };
            _incomingCB(data);

            // Reboot the imp upon idle
            // (to allow writes to flash time to take place, etc.)
            imp.onidle(function() {
                imp.reset();
            }.bindenv(this));
        }.bindenv(this);
        _blinkup.clear <- function() {
            // Close the existing connection to the mobile app
            if (_incoming != null) _incoming.close();

            // Clear the WiFi settings ONLY - this will affect the next
            // disconnection/connection cycle, not the current connection
            imp.clearconfiguration(CONFIG_WIFI);
        }.bindenv(this);

        // We need to wait 0.01s for the BLE radio to boot, so see how
        // long the set-up took before sleeping (which may not be needed)
        now = hardware.millis() - now;
        if (now < 10) imp.sleep((10 - now) / 1000);

        try {
            // Instantiate Bluetooth LE
            ble = hardware.bluetooth.open(_uart, BT_FIRMWARE.CYW_43438);
        } catch (err) {
            throw "BLE failed to initialize (error: " + err + ")";
        }
    }

    function _connectHandler(conn) {
        // This is the library's own handler for incoming connections.
        // It calls the host app as required upon connection
        if (_incomingCB == null) return;

        // Save the connecting device's BluetoothConnection instance
        _incoming = conn;

        // Register the library's own onclose handler
        conn.onclose(_closeHandler.bindenv(this));

        // Package up the connection data for return to the host app
        local data = { "conn":     conn,
                       "address":  conn.address(),
                       "security": conn.security(),
                       "state":    "connected" };

        // Call the host app's onconnect handler
        _incomingCB(data);
    }

    function _closeHandler() {
        // This is the library's own handler for broken connections.
        // It calls the host app as required upon disconnection.
        // NOTE This will never be called if the host app did not
        // provide onConnect() with a notification callback

        // Package up the connection data for return to the host app
        local data = { "conn":    _incoming,
                       "address": _incoming.address(),
                       "state":   "disconnected" };

        // Call the host app's onconnect handler
        _incomingCB(data);
    }

    function _hexStringToInt(hs) {
        local i = 0;
        foreach (c in hs) {
            local n = c - '0';
            if (n > 9) n = ((n & 0x1F) - 7);
            i = (i << 4) + n;
        }
        return i;
    }

    function _checkUUIDs(uuids) {
        // Make sure the UUIDs table contains the correct keys
        // Set the GATT service UUIDs we wil use
        local keyList = ["blinkup_service_uuid", "ssid_setter_uuid", "password_setter_uuid",
                         "planid_setter_uuid", "token_setter_uuid", "blinkup_trigger_uuid",
                         "wifi_getter_uuid", "wifi_clear_trigger_uuid"];
        local got = 0;
        foreach (key in keyList) {
            if (uuids[key].len() != null) got++;
        }
        return got == 8 ? true : false;
    }

    function _scan(shouldLoop = false) {
        // Scan for nearby WiFi networks compatible with the host imp
        if (!_blinking) {
            _networks = imp.scanwifinetworks();

            // Check the list of WLANs for networks which have multiple reachable access points,
            // ie. networks of the same SSID but different BSSIDs, otherwise the same WLAN will
            // be listed twice
            local i = 0;
            do {
                local network = _networks[i];
                i++;
                for (local j = 0 ; j < _networks.len() ; j++) {
                    local aNetwork = _networks[j];
                    if (network.ssid == aNetwork.ssid && network.bssid != aNetwork.bssid) {
                        // We have two identical SSIDs but different base stations, so remove one
                        _networks.remove(j);
                    }
                }
            } while (_networks.len() > i);
        }

        // Should we schedule a network list refresh?
        if (shouldLoop) {
            // Yes, we should
            imp.wakeup(BTLE_BLINKUP_WIFI_SCAN_INTERVAL, function() {
                _scan(true);
            }.bindenv(this));
        }
    }
}

// Set the GATT service UUIDs we wil use
function initUUIDs() {
    local uuids = {};
    uuids.blinkup_service_uuid    <- "FADA47BEC45548C9A5F2AF7CF368D719";
    uuids.ssid_setter_uuid        <- "5EBA195632D347C681A6A7E59F18DAC0";
    uuids.password_setter_uuid    <- "ED694AB947564528AA3A799A4FD11117";
    uuids.planid_setter_uuid      <- "A90AB0DC7B5C439A9AB52107E0BD816E";
    uuids.token_setter_uuid       <- "BD107D3E48784F6DAF3DDA3B234FF584";
    uuids.blinkup_trigger_uuid    <- "F299C3428A8A4544AC4208C841737B1B";
    uuids.wifi_getter_uuid        <- "57A9ED95ADD54913849457759B79A46C";
    uuids.wifi_clear_trigger_uuid <- "2BE5DDBA32864D09A652F24FAA514AF5";
    return uuids;
}

// Prevent the imp004m sleeping on connection error
server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 10);

local bt = null;
local agentTimer = null;

// Register a handler that will clear the configuration marker
// in the imp004m SPI flash in response to a message from the agent.
// This is present to aid testing: by clearing the signature and rebooting,
// you put the imp back into its pre-activation state
agent.on("clear.spiflash", function(data) {
    // Clear the SPI flash signature for debugging
    hardware.spiflash.enable();
    hardware.spiflash.erasesector(0x0000);
    server.log("Spiflash cleared");
});

// Register a handler that will restart the device
agent.on("do.restart", function(data) {
    if ("reset" in imp) {
        imp.reset();
    } else {
        server.restart();
    }
});

// This is a dummy function representing the application code flow.
// In real-world code, this would deliver the product’s day-to-day
// functionality, connection management and error handling code
function startApplication() {
    // Application code starts here
    server.log("Application starting...");
    server.log("Use the agent to reset device state");
}

// This function defines this app's activation flow: preparing the device
// for enrollment into the Electric Imp impCloud and applying the end-user's
// local WiFi network settings.
function startBluetooth() {
    // Instantiate the BTLEBlinkUp library
    bt = BTLEBlinkUp(initUUIDs());

    // Don't use security
    bt.setSecurity(1);

    // Register a handler to receive the agent's URL
    agent.on("set.agent.url", function(data) {
        // Agent URL received (from test device only; see below),
        // so run the Bluetooth LE code
        doBluetooth(data);
    }.bindenv(this));

    // Now try and get the agent's URL from the agent
    agent.send("get.agent.url", true);

    // Set up a timer to check if the agent.send() above was un-ACK'd
    // This will be the case with an **unactivated production device**
    // because the agent is not instantiated until after activation
    agentTimer = imp.wakeup(10, function() {
        // Set up a timer to check for an un-ACK'd agent.send(),
        // which will be the case with an unactivated production device
        // (agent not instantiated until after activation)
        agentTimer = null;
        doBluetooth();
    }.bindenv(this));
}

function doBluetooth(agentURL = null) {
    // If we didn't call this from the timer, clear the timer
    if (agentTimer != null) {
        imp.cancelwakeup(agentTimer);
        agentTimer = null;
    }

    // Store the agent URL if present
    if (agentURL != null) bt.agentURL = agentURL;

    // Set the device up to listen for BlinkUp data
    bt.listenForBlinkUp(null, function(data) {
        // This is the callback through which the BLE sub-system communicates
        // with the host app, eg. to inform it activation has taken place
        if ("address" in data) server.log("Device " + data.address + " has " + data.state);
        if ("security" in data) server.log("Connection security mode: " + data.security);
        if ("activated" in data && "spiflash" in hardware && imp.info().type == "imp004m") {
            // Write BlinkUp signature post-configuration
            hardware.spiflash.enable();
            local ok = hardware.spiflash.write(0x0000, "\xC3\xC3\xC3\xC3", SPIFLASH_PREVERIFY);
            if (ok != 0) server.error("SPIflash write failed");
        }
    }.bindenv(this));

    server.log("Bluetooth LE listening for BlinkUp...");
}

// RUNTIME START

// Start by checking the imp004m SPI flash for a signature
// If it is present (it is four bytes of 0xC3 each), the code
// jumps to the application flow; otherwise we run the activation
// flow, ie. set up and run Bluetooth LE
if ("spiflash" in hardware && imp.info().type == "imp004m") {
    // Read the first four bytes of the SPI flash
    hardware.spiflash.enable();
    local bytes = hardware.spiflash.read(0x0000, 4);
    local check = 0;

    // Are the bytes all 0xC3?
    foreach (byte in bytes) {
        if (byte == 0xC3) check++;
    }

    if (check >= 4) {
        // Device is activated so go to application code
        startApplication();
    } else {
        // Device is not activated so bring up Bluetooth LE
        startBluetooth();
    }
} else {
    // Unsupported imp: just start the app anyway to ignore Bluetooth
    startApplication();
}
