# BTLEBlinkUp #

This library provides a foundation for activating end-user devices via Bluetooth LE on imp modules that support this wireless technology (currently imp004m only) using BlinkUp™.

The BTLEBlinkUp library is intended for Electric Imp customers **only**. It contains device-side Squirrel code which enables BlinkUp device activation using enrollment and WiFi credentials transmitted by a companion app running on a mobile device. The companion app must contain the [Electric Imp BlinkUp SDK](https://developer.electricimp.com/manufacturing/sdkdocs), use of which is authorized by API key. Only Electric Imp customers can be provided with a suitable BlinkUp API key. Code for the companion app is not part of this library, but iOS example code is [available separately](https://github.com/electricimp/BluetoothBlinkUp).

At this time, BTLEBlinkUp is still in development and not yet part of the Electric Imp code library system, so you will need to paste the contents of the file `btleblinkup.device.lib.nut` into your device code file rather than apply the usual `#require` directive.

## Class Usage ##

### Constructor: BTLEBlinkUp(*[lpoPin][, regonPin][, uart][, uuids]*) ###

The constructor has four parameters, all of which are optional. The first two, *lpoPin* and *regonPin*, take the two imp GPIO pins that have been connected to the Bluetooth LE radio’s LPO_IN and BT_REG_ON pins. These currently default to the imp004m Breakout Board pins with these functions: **hardware.pinE** and **hardware.pinJ**, respectively. The *uart* parameter takes a reference to the imp UART bus on which the imp’s Bluetooth radio is connected; it defaults to **hardware.uartFGJH**.

The *uuids* parameter can be used to specify alternative UUIDs for the BlinkUp service delivered by the library. The UUIDs are supplied as a table with the following keys:

| Key | UUID Role |
| --- | --- |
| *blinkup_service_uuid* | The BlinkUp service itself |
| *ssid_setter_uuid* | The BlinkUp service’s WiFi SSID setter characteristic |
| *password_setter_uuid* | The BlinkUp service’s WiFi password setter characteristic |
| *planid_setter_uuid* | The BlinkUp service’s Plan ID setter characteristic |
| *token_setter_uuid* | The BlinkUp service’s Enrolment Token setter characteristic |
| *blinkup_trigger_uuid* | The BlinkUp service’s BlinkUp initiation characteristic |
| *wifi_getter_uuid* | The BlinkUp service’s WiFi network list characteristic |
| *wifi_clear_trigger_uuid* | The BlinkUp service’s clear imp WiFi settings characteristic |

You must provide UUIDs for **all** of these keys or BlinkUp will fail and a runtime error with be thrown. Electric Imp reserves the right to add additional keys in future, so you should not extend this list yourself. If you wish your imp-enabled device to serve other GATT services alongside the BlinkUp service, this can be done using the *serve()* function detailed below.

The value of each key is a string.

**Note** The Bluetooth instance established by the constructor can be accessed by the host Squirrel using the instance’s *ble* property. You should always check that this instance is not `null` before performing any actions upon it.

## Class Methods ##

### listenForBlinkUp(*[advert][, callback]*) ###

This method provides the easiest way to provide BlinkUp via Bluetooth LE. It boots up the imp’s Bluetooth LE radio; sets up and serves two GATT services, BlinkUp and the standard Device Information service; prepares the imp to receive connections from the mobile app being used to provide the imp with activation data; and advertises the imp’s availability to other Bluetooth LE devices.

The method has two parameters, both of which are optional. The first, *advert* is a string or blob of up to 31 bytes in length — this is the imp’s Bluetooth LE advertisement payload. If you do not specify a payload, the library generates one for you using the BlinkUp service UUID (default or supplied) and the type of imp module as a device name string (eg. `imp004m`).

The *callback* parameter takes a function which will be triggered when a remote device connects to the imp, or actively disconnects from it. This function has a single parameter into which a table is passed containing any of the following keys:

| Key | Type | Notes |
| --- | --- | --- |
| *conn* | imp API BluetoothConnection instance | See [**hardware.bluetooth.onconnect()**](https://developer.electricimp.com/api/hardware/bluetooth/onconnect/) |
| *address* | String | The hexadecimal address of the connecting device |
| *security* | Integer | The security mode of the connection (1, 3 or 4) |
| *state* | String | The state of the remote device: `"connected"` or `"disconnected"` |
| *error* | String | In the event of an error, a description of the error; otherwise `null` |

#### Example ####

```
local bt = BTLEBlinkUp();
bt.listenForBlinkUp(null, function(data) {
    server.log("Device " + data.address + " has " + data.state);
});
```

### setSecurity(*mode, pin*) ###

This method applies the required security mode: 1, 3 or 4. For more information, please see [**hardware.bluetooth.setsecurity()**](https://developer.electricimp.com/api/hardware/bluetooth/setsecurity/).

The default value of *mode* is 1 (no security). For this mode, no value need be passed into *pin*, but modes 3 and 4 both require the provision of a six-digit decimal PIN code for pairing. This can be a string or an integer. Values greater than six digits will trigger an error to be reported and the no security will be applied.

#### Example ####

```
local advert = "\x11\x07\x19\xD7\x68\xF3\x7C\xAF\xF2\xA5\xC9\x48\x55\xC4\xBE\x47\xDA\xFA\x0A\x09\x69\x6D\x70\x30\x30\x34\x2D\x42\x42";
local bt = BTLEBlinkUp();
bt.setSecurity(4, "163524");
bt.listenForBlinkUp(advert, function(data) {
    server.log("Device " + data.address + " has " + data.state);
});
```

### serve(*[otherServices]*) ###

This method sets up and begins serving BlinkUp and standard Device Information GATT services. The BlinkUp service uses the UUIDs supplied to the class construtor (or the defaults, if no UUIDs were specified). The latter uses the following UUIDs, as per the Bluetooth LE standard:

```
service = { "uuid": 0x180A,
              "chars": [
                { "uuid": 0x2A29, "value": "Electric Imp" },           // Manufacturer name
                { "uuid": 0x2A25, "value": hardware.getdeviceid() },   // Serial number
                { "uuid": 0x2A24, "value": imp.info().type },          // Model number
                { "uuid": 0x2A26, "value": imp.getsoftwareversion() }  // Firmware revision
              ]
           };
```

The parameter *otherServices* takes an array of service definition tables (or a single such service as a table) as detailed [here](https://developer.electricimp.com/api/hardware/bluetooth/servegatt/). These are loaded and served alongside the two services mentioned above.

**Note** *serve()* is called implicitly by *listenForBlinkUp()*.

#### Example ####

```
// Add Battery Level sevice
local bls = { "uuid": 0x180F,
              "chars": [
                { "uuid": 0x2A19,
                  "read": function(conn) {
                    local b = blob(1);
                    local battery_percent = hardware.vbat() / 4.2 * 100;
                    b.writen(battery_percent, 'b');
                    return b;
                  }.bindenv(this) }
              ]
            };

bt.serve(bls);
```

### advertise(*[advert][, min][, max]*) ###

This method advertises the imp to other Bluetooth LE-enabled devices using the argument passed into *advert*, or a self-generated advert based on the BlinkUp service UUID and the host imp’s type as its name, if *advert* is `null`. The parameters *min* and *max* are also optional, and default to 100 (milliseconds; the minimum and maximum advertising interval).

**Note** *advertise()* is called implicitly by *listenForBlinkUp()*.

#### Example ####

```
local advert = "\x11\x07\x19\xD7\x68\xF3\x7C\xAF\xF2\xA5\xC9\x48\x55\xC4\xBE\x47\xDA\xFA\x08\x09\x69\x6D\x70\x30\x30\x34\x6D";
bt = BTLEBlinkUp();
bt.setSecurity(1);
bt.serve();
bt.advertise(advert, 90, 110);
server.log("Bluetooth running...");
```

### onConnect(*[callback]*) ###

This method registers a callback function that will be triggered when a remote device connects to the imp, or manually disconnects from it. This function has a single parameter into which a table is passed containing any of the following keys:

| Key | Type | Notes |
| --- | --- | --- |
| *conn* | imp API BluetoothConnection instance | See [**hardware.bluetooth.onconnect()**](https://developer.electricimp.com/api/hardware/bluetooth/onconnect/) |
| *address* | String | The hexadecimal address of the connecting device |
| *security* | Integer | The security mode of the connection (1, 3 or 4) |
| *state* | String | The state of the remote device: `"connected"` or `"disconnected"` |
| *error* | String | In the event of an error, a description of the error; otherwise `null` |

**Note** *onConnect()* is called implicitly by *listenForBlinkUp()*.

## License ##

BTLEBlinkUp is licensed under the terms and conditions of the MIT License.

