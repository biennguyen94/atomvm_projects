# Requirements
	- A computer running MacOS or Linux (Windows support is not currently supported);
	- An ESP32 module with a USB/UART connector (typically part of an ESP32 development board);
	- A USB cable capable of connecting the ESP32 module or board to your development machine (laptop or PC);
	- The esptool program (https://github.com/espressif/esptool), for flashing the AtomVM image and AtomVM programs;
	- An Erlang/OTP release (21, 22, or 23);
	- A serial console program, such as minicom or screen, so that you can view console output from your AtomVM application;
	- For Erlang programs, rebar3;
	- Manage multiple language runtime versions on a per-project basis, asdf

# Flash layout
```
+-----------------+  ------------- 0x0000
|    secure       |
|     boot        | 4KB
|                 |
+-----------------+  ------------- 0x1000
|                 |             ^
|   boot loader   | 28KB        |
|                 |             |
+-----------------+             |
| partition table | 3KB         |
+-----------------+             |
|                 |             |
|       NVS       | 24KB        |
|                 |             |
+-----------------+             |
|     PHY_INIT    | 4KB         |
+-----------------+             | AtomVM
|                 |             | binary
|                 |             | image
|                 |             |
|     AtomVM      |             |
|     Virtual     | 1.75MB      |
|     Machine     |             |
|                 |             |
|                 |             |
+-----------------+             |
|     lib.avm     | 256KB       v
+-----------------+  ------------- 0x210000
|                 |             ^
|                 |             |
|     main.avm    | 1MB+        | Erlang/Elixir
|                 |             | Application
|                 |             |
|                 |             v
+-----------------+  ------------- end
```

# Deploying an AtomVM application to an ESP32 device
Typically involved two steps:
* Connecting the ESP32 device;
* Deploying the AtomVM virtual machine;
* Deploying an AtomVM application (typically an iterative process)	

	
## Deploying the AtomVM virtual machine
	* First erasing any existing applications on the ESP32 device:
		shell$ esptool.py --chip esp32 --port /dev/ttyUSB0 --baud 115200 erase_flash
	* Next, download the latest stable or nightly ESP32 release image from the https://atomvm.net/
	* Finally, use the esptool to flash the image to the start address 0x1000 on the ESP32:
```
shell$ esptool.py --chip esp32 --port /dev/ttyUSB0 --baud 115200 \
--before default_reset --after hard_reset \
write_flash -u --flash_mode dio --flash_freq 40m --flash_size detect \
0x1000 atomvm-esp32-v0.1.0.bin
```

## Deploying an AtomVM application
* Edit or create the $HOME/.config/rebar3/rebar.config file to include the atomvm_rebar3_plugin plugin (https://github.com/atomvm/atomvm_rebar3_plugin):
%% $HOME/.config/rebar3/rebar.config
{plugins, [
	{atomvm_rebar3_plugin, "0.3.0"},
	...
]}.
* In any directory in which you have write permission, issue:
shell$ rebar3 new atomvm_app <app-name>
* With this plugin installed, you have access to the esp32_flash target, which will build an AtomVM packbeam:
```
shell$ rebar3 esp32_flash --port /dev/ttyUSB0
===> Fetching atomvm_rebar3_plugin v0.3.0
===> Fetching rebar3_hex v6.11.3
===> Fetching hex_core v0.7.1
===> Fetching verl v1.0.2
===> Analyzing applications...
===> Compiling verl
===> Compiling hex_core
===> Compiling rebar3_hex
===> Fetching atomvm_packbeam v0.3.0
===> Analyzing applications...
===> Compiling atomvm_rebar3_plugin
===> Compiling packbeam
===> Verifying dependencies...
===> Analyzing applications...
===> Compiling myapp
===> AVM file written to : myapp.avm
===> esptool.py --chip esp32 --port /dev/ttyUSB0 --baud 115200 --before default_reset --after hard_reset write_flash -u --flash_mode dio --flash_freq 40m --flash_size detect 0x210000 /home/frege/myapp/_build/default/lib/myapp.avm
```

# Development Workflow
```
*.erl or *.ex                  *.beam
+-------+                   +-------+
|       |+                  |       |+
|       ||+                 |       ||+
|       |||     -------->   |       |||
|       |||  Erlang/Elixir  |       |||
+-------+||     Compiler    +-------+||
 +-------+|                  +-------+|
  +-------+                   +-------+
     ^                           |
     |                           | packbeam
     |                           |
     |                           v
     |                       +-------+
     |                       |       |
     | test                  |       |
     | debug                 |       |
     | fix                   |       |
     |                       +-------+
     |                        app.avm
     |                           |
     |                           | flash/upload
     |                           |
     |                           v
     +-------------------- Micro-controller
                              device
```

The typical compile-test-debug cycle can be summarized in the following steps:
* Deploy the AtomVM virtual machine to your device
* Develop an AtomVM application in Erlang or Elixir
	* Write application
	* Deploy application to device
	* Test/Debug/Fix application
	* Repeat	
	
# PackBEAM tool
The PackBEAM tool is a command-line application that is to build Packbeam files and deploy then to your device of choice
```
shell$ PackBEAM -h
	Usage: PackBEAM [-h] [-l] <avm-file> [<options>]
		-h                                                Print this help menu.
		-l <input-avm-file>                               List the contents of an AVM file.
		[-a] <output-avm-file> <input-beam-or-avm-file>+  Create an AVM file (archive if -a specified).
```
To create a packbeam file, specify the name of the AVM file to created (by convention, ending in .avm), followed by a list of BEAM files:\

```
shell$ PackBEAM foo.avm path/to/foo.beam path/to/bar.beam
```

To list the contents of an AVM file, use the -l flag:
```
shell% PackBEAM -l foo.avm
	foo.beam *
	bar.beam
	gnu.beam
```
Any BEAM files that export a start/0 function will contain an asterisk (*) in the AVM file contents.


# Useful docs
APIs:
https://doc.atomvm.net/apidocs/erlang/eavmlib/index.html


esp-idf:
https://github.com/espressif/esp-idf


	
reading/writing Gyro/Acc value for MPU6050:
https://howtomechatronics.com/tutorials/arduino/arduino-and-mpu6050-accelerometer-and-gyroscope-tutorial/
https://playground.arduino.cc/Main/MPU-6050/#multiple
https://github.com/leech001/MPU6050/blob/master/examples/STM32F401CCU6_MPU6050/Core/Src/mpu6050.c (Kalman filter)


MPU6050 dattasheet:
https://pdf1.alldatasheet.com/datasheet-pdf/view/1132807/TDK/MPU-6050.html

HR 04: https://controllerstech.blogspot.com/2019/10/hc-sr04-and-stm32.html

Balancing robot:
https://create.arduino.cc/projecthub/marketingmanagerofdattabanur/arduino-self-balancing-robot-e23f9c?ref=part&ref_id=11332&offset=6
https://github.com/sonphambk/2-WHEEL-SELF-BALANCING-ROBOT-WITH-STM32F103/blob/master/Src/main.c

PID:
http://www.hocavr.com/2018/06/ieu-khien-ong-co-dc-servo-pid.html

ESP32:
https://docs.espressif.com/projects/esp-idf/en/latest/esp32/hw-reference/esp32/get-started-devkitc.html
https://docs.espressif.com/projects/esp-idf/en/latest/esp32/_images/esp32-devkitC-v4-pinout.png
https://khuenguyencreator.com/lap-trinh-esp32-webserver-che-do-wifi-station/

# Reference
https://github.com/atomvm/

https://doc.atomvm.net/

https://atomvm.net/