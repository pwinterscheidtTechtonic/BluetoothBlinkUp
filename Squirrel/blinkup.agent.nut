//  ------------------------------------------------------------------------------
//  File: blinkup.agent.nut
//  Version: 0.0.1
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

// Display the agent URL and reset endpoint in the log
server.log("URL: " + http.agenturl() + "?reset=1");

// Register a handler for incoming HTTP requests. It will check for reset commands
// and reject all others. The value of the reset parameter is ignored
http.onrequest(function(request, response) {
     if ("query" in request) {
        if ("reset" in request.query) {
            device.send("clear.spiflash", true);
            server.log("Device instructed to clear its SPI flash activation flag");
        }
    }

    response.send(200, "OK");
});
