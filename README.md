# Bluetooth BlinkUp #

This example comprises Squirrel code to run on a imp004m-based test device – this requires impOS™ 37 or above — and an Xcode project which you can use to build an iOS app (written in Swift) that is capable of finding and configuring test devices running the Squirrel code.

The Squirrel code provides a basic framework for supporting BlinkUp™ via Bluetooth. The iOS app is used to scan for nearby imp004m-based devices running the Squirrel code, to select one of them, and then to choose a local wireless network, enter its password and transmit that information to the test device to perform BlinkUp™.

**Note** The iOS code can be run in Device Simulator, but this will not be able to access Bluetooth. To use Bluetooth, you must run the app on a connected iDevice.

## BlinkUp Preparation ##

The iOS makes use of the Electric Imp BlinkUp SDK. As such, it requires the entry of a BlinkUp API key to authorize its access to the Electric Imp impCloud™. The app prompts the user for this key when it is first run; if you do not enter your key then, you can do so at a later time, by tapping ‘Actions’ in the navigation bar and selecting ‘Enter your BlinkUp API key’ from the menu.

Please note that Electric Imp makes BlinkUp API keys available **to customers only**. This sample code cannot be used by holders of free Electric Imp accounts.

## Hardware Preparation ##

Because the iOS app makes use of the Electric Imp BlinkUp SDK, it performs production BlinkUp. As such, the test device must already have been assigned to your Electric Imp account as a development device and assigned to a Device Group. This Device Group can be the one you have deployed the sample Squirrel code to.

## Using the App ##

When the app has launched and you have entered your BlinkUp API Key — or it has been read from your phone’s keychain — pull down the list view to start a scan (or tap ‘Actions’ and select ‘Start Scan’. Any devices running the demo’s Squirrel code will now appear in the list — tap one to view the list of compatible WiFi networks the device can see. Select your network from the list and enter its password. You can click on the eye icon to view the password characters.

<p align="center"><img src="/images/01.png" width="375">&nbsp;&nbsp;<img src="images/02.png" width="375"></p>

Finally, tap ‘Send BlinkUp’ to transmit the WiFi credentials to the device. It will then reconnect to the new network. The device logs details of the process, so you can observe it connect if you are viewing the log stream in impCentral™ or an impCentral API-based tool.

## iOS Bluetooth Attribute Caching ##

By default, iOS caches the attribute information it discovers from devices. This ensures that future scans need not use the radio, conserving power. However, it also means if you change your Squirrel app’s served attributes during development, they will not be detected by the app.

The easiest approach to dealing with this is to disable then re-enable Bluetooth on your Apple device. You may also need to power-cycle the device.

## License ##

This sample code is made available under the MIT License.

Copyright © 2018, Electric Imp, Inc.
