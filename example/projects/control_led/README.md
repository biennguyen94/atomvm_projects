# `control_led` Application
Welcome to the `control_led` AtomVM application.
The `control_led` AtomVM application uses the `http_server` module to control ON/OF led (GPIO2) of ESP32.
## Usage
> **IMPORTANT** before you compile and flash this example you need to edit `myssid` and `mypsk` in src/morse_server.erl to match your wireless network configuration.
```
    Config = [
       {sta, [
            {ssid, esp:nvs_get_binary(atomvm, sta_ssid, <<"myssid">>)},
            {psk,  esp:nvs_get_binary(atomvm, sta_psk, <<"mypsk">>)},
```
This application is used for controlling the LED using webserver. The default on-board LED for most ESP32 boards is GPIO 2.  You may also connect an LED to any GPIO pin and connect its anode to ground with a 100 Ohm or higher (220 Ohm recommended) resistor.

    +-----------+
    |           |    1k ohm
    |       IO2 o--- \/\/\/\ ---+
    |           |   resistor    |
    |           |               |
    |           |               |
    |           |               |
    |       GND o------|<-------+
    +-----------+      LED
        ESP32

When the ESP32 first boots up, at at the end of the serial output, you should see output similar to:

    I (1822) NETWORK: SYSTEM_EVENT_STA_CONNECTED received.
    I (2822) event: sta ip: 10.9.163.210, mask: 255.255.254.0, gw: 10.9.162.1
    I (2822) NETWORK: SYSTEM_EVENT_STA_GOT_IP: 10.9.163.210
    Acquired IP address: "10.9.163.210" Netmask: "255.255.254.0" Gateway: "10.9.162.1"

Your ESP can be reached with a web browser on port 8080 by its IP address or DHCP hostname, in the example above this would either be:

    "http://192.168.0.32:8080"  or  "http://atomvm-240ac458d278:8080"

For more information about programming on the AtomVM platform, see the [AtomVM Programmers Guide](https://doc.atomvm.net/programmers-guide.html).

### Example Result

This is the GUI to control the Led of GPIO2.

![](https://i.ibb.co/tc1S3hs/Microsoft-Teams-image.jpg)

*When Led is OFF, the button has RED color.*

*The Led of GPIO2 is OFF too.*

![](https://i.ibb.co/0QS4ZHk/Microsoft-Teams-image-1.jpg)

*When Led is ON, the button has GREEN color.*
*The Led of GPIO2 is ON too.*

