# Prepare docker container
Pull docker image
```
docker pull biennguyen94/atomvm:ubuntu20_04_v3
```

Or build docker image
```
cd /tools/atomvm_basic_projects/docker/20.04
docker build --network host -t bien_atomvm.test .
```

Deploy docker image to container
```
docker run --privileged -v /dev/:/dev/ --name bien_atomvm -it biennguyen94/atomvm:ubuntu20_04_v3 bash
```

In first time, after exiting from container, we need to start container
```
Ctrl + D
docker start bien_atomvm
```

Access to container
```
docker exec -it bien_atomvm bash
```

Connect ESP32 to computer via USB, check by command in container: `ls /dev/tty*`, if we can see `/dev/ttyUSB0`, then we are success

# Build and Flash AtomVM image to ESP32
To build libs
```
mkdir build
cd build
cmake ..
make -j 8
```

To build esp32 for esp-idf 4.4 and later (ubuntu 20.04).
Note: python3 is sourced by command `. $IDF_PATH/export.sh`
```
cd /tools/AtomVM/src/platforms/esp32
. $IDF_PATH/export.sh
python3 $IDF_PATH/tools/idf.py reconfigure
python3 $IDF_PATH/tools/idf.py build
```

To create .img
```
cd /tools/AtomVM/build
./tools/release/esp32/mkimage.sh
```

To erase the flash
For ubuntu 20.04:
```
python3 ${IDF_PATH}/components/esptool_py/esptool/esptool.py --chip esp32 --port /dev/ttyUSB0 --baud 115200 erase_flash
```

To flash the entire image to device
For ubuntu 20.04:
```
python3 ${IDF_PATH}/components/esptool_py/esptool/esptool.py \
    --chip esp32 \
    --port /dev/ttyUSB0 \
    --baud 115200 \
    --before default_reset \
    --after hard_reset \
    write_flash \
    -u --flash_mode dio --flash_freq 40m \
    --flash_size detect \
    0x1000 \
    /tools/AtomVM/src/platforms/esp32/build/atomvm-esp32-0.5.0.img
```

# Running blinky example
Access to container
```
docker exec -it bien_atomvm bash
```

Clone repo
```
cd /tools/
git clone https://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@github.com/biennguyen94/atomvm_basic_projects.git
```

Build application source code to .avm
```
cd /tools/atomvm_basic_projects/example/2_blinky/
rebar3 packbeam
```

Flash .avm to ESP32
```
python3 ${IDF_PATH}/components/esptool_py/esptool/esptool.py \
    --chip esp32 \
    --port /dev/ttyUSB0 \
    --baud 115200 \
    --before default_reset \
    --after hard_reset \
    write_flash \
    -u --flash_mode dio --flash_freq 40m \
    --flash_size detect \
    0x210000 \
    _build/default/lib/blinky.avm
```

Open minicom for debugging
```
minicom -D /dev/ttyUSB0
```

# Note
* I only genarate Git personal access token in 30 days, so when it expires you can't clone atomvm_basic_projects repo, please let me know, I will provide a new token.
* minicom and flash .avm are using same a USB device port, so note that whenever you flash .avm, you must close minicom.

# Refer
https://forums.docker.com/t/how-to-expose-host-serial-port-to-container-correctly/81588/2
https://www.losant.com/blog/how-to-access-serial-devices-in-docker
https://stackoverflow.com/questions/24225647/docker-a-way-to-give-access-to-a-host-usb-or-serial-device
