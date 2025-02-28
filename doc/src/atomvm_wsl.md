# WSL
## Install WSL
* Search for Command Prompt, right-click the top result, and select the Run as administrator option.
* wsl --install
* Restart your computer
Once you complete the steps, the required Linux components will install automatically on Windows 11 and the latest version of the Ubuntu Linux distribution.

## Install WSL with specific distro
* Search for Command Prompt, right-click the top result, and select the Run as administrator option.
* wsl --list --online
* wsl --install -d <DISTRO-NAME>
* Restart your computer

## Setup USB
### Option 1
* On Windows: Head over the GitHub repo of the usbipd-win project. Then download and install the latest release (https://github.com/dorssel/usbipd-win/releases/latest)

* On WSL (Ubuntu): sudo apt install linux-tools-5.4.0-77-generic hwdata
* On WSL (Ubuntu): Now we need to modify the sudo options to allow the root user to find the usbip command. To do so, edit the /etc/sudoers file using sudo visudo and add /usr/lib/linux-tools/5.4.0-77-generic to the beginning of secure_path. It should look like the following:
```
Defaults        secure_path="/usr/lib/linux-tools/5.4.0-77-generic:/usr/local/sbin:..."
```
* On Windows: Search for Command Prompt, right-click the top result, and select the Run as administrator option.
* On Windows: usbipd wsl list
* On Windows: usbipd bind --busid 1-8 --force
* On Windows: Search for Command Prompt, right-click the top result, and open it with normal user (don't select the Run as administrator option).
* On Windows: usbipd wsl attach --busid 1-8

Check on Ubuntu with command: ls /dev/tty*, let's see if we can see ttyUSB0 or not.

### Option 2
* On Windows: Head over the GitHub repo of the usbipd-win project. Then download and install the latest release (https://github.com/dorssel/usbipd-win/releases/latest)
Working version:
2.4.1+1.Branch.master.Sha.90acf9456020ca8c6310ca62a71ee23cb6ca34ad 

* On WSL (Ubuntu): Now we need to modify the sudo options to allow the root user to find the usbip command. To do so, edit the /etc/sudoers file using sudo visudo and add /usr/lib/linux-tools/5.4.0-77-generic to the beginning of secure_path. It should look like the following:
```
Defaults        secure_path="/usr/lib/linux-tools/5.4.0-77-generic:/usr/local/sbin:..."
```

* On WSL (Ubuntu):
```
sudo apt install linux-tools-5.4.0-77-generic linux-tools-virtual hwdata usbutils
sudo update-alternatives --install /usr/local/bin/usbip usbip `ls /usr/lib/linux-tools/*/usbip | tail -n1` 20
```
* On Windows: Search for Command Prompt, right-click the top result, and select the Run as administrator option.
```
usbipd wsl list
usbipd wsl attach --busid 2-2
```

## Setup VsCode for WSL
* Install VSCode in Windows
* Install Remote Development extension package
* F1 -> WSL: New WSL Window using Distro..

## Copy file from WSL to Container
```
docker cp /tools/atomvm_basic_projects/example/hello_world/src/hello_world.erl cb920e4dc7a0:/tools/atomvm_basic_projects/example/hello_world/src/hello_world.erl
```

## Reference
* https://pureinfotech.com/install-wsl-windows-11/
* https://www.xda-developers.com/wsl-connect-usb-devices-windows-11/
* https://github.com/dorssel/usbipd-win/issues/251#issuecomment-1079961293
* https://www.geekbits.io/how-to-connect-a-usb-device-to-wsl-instance/