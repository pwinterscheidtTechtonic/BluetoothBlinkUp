//  ------------------------------------------------------------------------------
//  File: blinkup.agent.nut
//
//  Version: 1.0.1
//
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
//  ------------------------------------------------------------------------------

// This is a very basic agent implementation, one that is simply used as a remote
// control to cause the device to clear the flag it maintains in its SPI flash to
// indicate whether it has been activated (ie. sent enrolment and WiFi details via
// Bluetooth and BlinkUp) or not. This can be cleared to aid debugging by putting
// the device into its pre-activation state, ie. ready for BlinkUp.

// IMPORTS
#require "Rocky.class.nut:2.0.1"

// CONSTANTS
const HTML_STRING = @"<!DOCTYPE html><html lang='en-US'><meta charset='UTF-8'>
<html>
    <head>
        <title>Electric Imp BlinkUp™</title>
        <link rel='stylesheet' href='https://netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css'>
        <link href='https://fonts.googleapis.com/css?family=Abel' rel='stylesheet'>
        <link rel='shortcut icon' href='https://smittytone.github.io/images/ico-imp.ico'>
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <style>
            body { background-color: #25ABDC; }
            p {color: white; font-family: Abel, sans-serif; font-size: 18px}
            p.error-message {color:#ffcc00; font-size: 16px}
            p.colophon {font-size: 14px; text-align: center}
            h2 {color: white; font-family: Abel, sans-serif; font-size: 36px}
            h4 {color: white; font-family: Abel, sans-serif; font-size: 18px}
            td {color: white; font-family: Abel, sans-serif}
            hr {border-color: #ffcc00}
            .tabborder {width: 25%%}
            .tabcontent {width: 50%%}
            .uicontent {border: 2px solid white}
            .container {padding: 20px}
            .center { margin-left: auto;
                      margin-right: auto;
                      margin-bottom: auto;
                      margin-top: auto; }

            @media only screen and (max-width: 640px) {
                .tabborder {width: 5%%}
                .tabcontent {width: 90%%}
                .container {padding: 5px}
                .uicontent {border: 0px}
            }
        </style>
    </head>
    <body>
        <div class='container'>
            <div class='uicontent'>
                <h2 align='center'>Electric Imp BlinkUp™ Demo</h2>
                <p>&nbsp;</p>
                <div class='current-status-readout' align='center'>
                    <h4 class='readout-id'>Device ID: <span></span></h4>
                    <h4 class='readout-url'>Agent URL: <span></span></h4>
                    <h4 class='readout-state'>Device Status: <span></span></h4>
                    <h4 class='readout-state'>Agent Status: online</h4>
                </div>
                <p>&nbsp;</p>
                <div class='reset-button' style='color:dimGrey;font-family:Abel,sans-serif' align='center'>
                    <button type='submit' id='resetter' style='height:32px;width:200px'>Clear BlinkUp Signature</button>
                </div>
                <p>&nbsp;</p>
                <p class='colophon'>BlinkUp Demo &copy; Electric Imp, Inc. 2018</p>
            </div>
        </div>

        <script src='https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js'></script>
        <script>
            // Variables
            var agenturl = '%s';
            var isMobile = false;

            // Set up actions
            $('.reset-button button').click(reset);

            // Get initial readings
            getState(updateReadout);

            // Functions
            function updateReadout(data) {
                 $('.readout-url span').text(agenturl);
                 $('.readout-id span').text(data.id);
                 $('.readout-state span').text(data.state);
            }

            function getState(callback) {
                // Request the current data
                $.ajax({
                    url : agenturl + '/current',
                    type: 'GET',
                    success : function(response) {
                        response = JSON.parse(response);
                        if (callback) {
                            callback(response);
                        }
                    }
                });
            }

            function reset() {
                // Trigger a device reset
                $.ajax({
                    url : agenturl + '/action',
                    type: 'POST',
                    data: JSON.stringify({ 'action' : 'reset' }),
                    success : function(response) {
                        getState(updateReadout);
                    }
                });
            }
        </script>
    </body>
</html>";

// GLOBAL VARIABLES
local api = null;

// RUNTIME START

// Send the device the Agent URL when asked
device.on("get.agent.url", function(dummy) {
    device.send("set.agent.url", http.agenturl());
});

// Set up the Web API
api = Rocky();

api.get("/", function(context) {
    // Deliver the UI page
    context.send(200, format(HTML_STRING, http.agenturl()));
});

api.get("/current", function(context) {
    // Deliver the device information
    local data = {};
    data.id <- imp.configparams.deviceid;
    data.state <- device.isconnected() ? "online" : "offline";
    data.url <- http.agenturl();
    context.send(200, http.jsonencode(data));
});

api.post("/action", function(context) {
    try {
        local data = http.jsondecode(context.req.rawbody);
        if ("action" in data) {
            if (data.action == "reset") {
                device.send("clear.spiflash", true);
                server.log("Device instructed to clear its SPI flash activation flag");
                context.send(200, "OK");
                return;
            }
        }

        response.send(400, "Unknown command");
    } catch (err) {
        server.error(err);
        context.send(400, "Bad data posted");
        return;
    }
});
