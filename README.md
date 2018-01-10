# Bluetooth BlinkUp #

This example comprises Squirrel code to run on a imp004m-based test device – this requires impOS™ 37 or above - and an Xcode project which you can use to build an iOS app capable of finding and configuring test devices running the Squirrel code.

The Squirrel code provides a basic framework for supporting BlinkUp™ via Bluetooth. The iOS app is used to scan for nearby imp004m-based devices running the Squirrel code, to select one of them, and then to choose a local wireless network, enter its password and transmit that information to the test device to perform BlinkUp™.

**Note** The iOS code can be run in Device Simulator, but this will not be able to access Bluetooth. To use Bluetooth, you must run the app on a connected iDevice.

## BlinkUp Preparation ##

The iOS makes use of the Electric Imp BlinkUp SDK. As such, it requires the entry of a BlinkUp API key to authorize its access to the Electric Imp impCloud™. The app prompts the user for this key when it is first run; if you do not enter your key then, you can do so at a later time, by tapping ‘Actions’ in the navigation bar and selecting ‘Enter your BlinkUp API key’ from the menu.

Please note that Electric Imp makes BlinkUp API keys available **to customers only**. This sample code cannot be used by holders of free Electric Imp accounts.

## Hardware Preparation ##

Because the iOS app makes use of the Electric Imp BlinkUp SDK, it performs production BlinkUp. As such, the test device must already have been assigned to your Electric Imp account as a development device and assigned to a Device Group. This Device Group can be the one you have deployed the sample Squirrel code to.

## License ##

This sample code is made available under the MIT License.

Copyright © 2018, Electric Imp, Inc.
