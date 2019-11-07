//  ------------------------------------------------------------------------------
//  File: blinkup.device.nut
//
//  Version: 1.3.0
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

// IMPORTS
#require "bt_firmware.lib.nut:1.0.0"
//#require "btleblinkup.device.lib.nut:2.0.0"
#import "/Users/smitty/Documents/GitHub/BTLEBlinkUp/btleblinkup.device.lib.nut"

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
    bt = BTLEBlinkUp(initUUIDs(), (iType == "imp004m" ? BT_FIRMWARE.CYW_43438 : BT_FIRMWARE.CYW_43455));

    // Set security level for demo
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
iType <- imp.info().type;
if ("spiflash" in hardware && (iType == "imp004m" || iType == "imp006" || iType == "impC001")) {
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
