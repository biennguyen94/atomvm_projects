# `Ledc` Application

Welcome to the `Ledc` AtomVM application.
The `Ledc` AtomVM application illustrates use of the AtomVM `Ledc` interface.
In this application, we create a webserver to control the bright level (duty cycle) through a range slider. The value of bright level will show in websever UI realtime and send it to minicom.
## Usage

This application is used for controlling the LED using webserver. The default on-board LED for most ESP32 boards is GPIO 18.  You may also connect an LED to any GPIO pin and connect its anode to ground with a 100 Ohm or higher (220 Ohm recommended) resistor.

    +-----------+
    |           |    1k ohm
    |       IO18 o--- \/\/\/\ ---+
    |           |   resistor    |
    |           |               |
    |           |               |
    |           |               |
    |       GND o------|<-------+
    +-----------+      LED
        ESP32

> **IMPORTANT** before you compile and flash this example you need to edit `myssid` and `mypsk` in src/config.erl to match your wireless network configuration.
```
    Config = [
       {sta, [
            {ssid, esp:nvs_get_binary(atomvm, sta_ssid, <<"myssid">>)},
            {psk,  esp:nvs_get_binary(atomvm, sta_psk, <<"mypsk">>)},
```

When the ESP32 first boots up, at at the end of the serial output, you should see output similar to:

    I (1822) NETWORK: SYSTEM_EVENT_STA_CONNECTED received.
    I (2822) event: sta ip: 10.9.163.210, mask: 255.255.254.0, gw: 10.9.162.1
    I (2822) NETWORK: SYSTEM_EVENT_STA_GOT_IP: 10.9.163.210
    Acquired IP address: "10.9.163.210" Netmask: "255.255.254.0" Gateway: "10.9.162.1"

Your ESP can be reached with a web browser on port 8080 by its IP address or DHCP hostname, in the example above this would either be:

    "http://192.168.0.32:8080"  or  "http://atomvm-240ac458d278:8080"

For more information about programming on the AtomVM platform, see the [AtomVM Programmers Guide](https://doc.atomvm.net/programmers-guide.html).

### Example Result

This is the GUI to control the bright level of Led using webserver.
The example result when adjusting the range slider will be shown below.

**Setting the low bright level:**

![](https://i.ibb.co/p30Bfr8/Microsoft-Teams-image-3.jpg)

- With the above image, the value of Duty Cycle is 20%.
- The bright level of led is LOW(20%) and minicom get the message when pressing the "Save" button (check the images below).

![](https://i.ibb.co/TkN300r/Microsoft-Teams-image-1.png[/img][/url])
![](https://i.ibb.co/s6r86qy/Microsoft-Teams-image-5.jpg[/img][/url])


**Setting the high bright level:**

![](https://i.ibb.co/pz7cNXk/Microsoft-Teams-image-4.jpg[/img][/url])

- The value of Duty Cycle on webserver is 100%.
- The bright level of led is HIGHEST (100%) and minicom get the message when pressing the "Save" button (check the images below).

![](https://i.ibb.co/D7WJGzK/Microsoft-Teams-image-2.png[/img][/url])
![](https://i.ibb.co/NCy5SqJ/Microsoft-Teams-image-6.jpg[/img][/url])