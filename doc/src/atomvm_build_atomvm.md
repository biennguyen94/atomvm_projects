# Build AtomVM
## Build AtomVM
```
git clone https://github.com/atomvm/AtomVM
```

### To build libs and tests
```
mkdir build
cd build
cmake ..
make -j 8
```

### Unit test can be ran with
```
./tests/test-erlang
./src/AtomVM ./tests/erlang_tests/floatabs.beam
```

### To re-build test beam file after test changes
```
cd /tools/AtomVM/build/tests
make
/tools/AtomVM/build/src/AtomVM ./tests/erlang_tests/floatabs.beam
```

## Build for ESP32
### To build esp32 platform (does not work for esp-idf 4.4 and later, see Docker file of Ubuntu 20.04)
```
cd /tools/AtomVM/src/platforms/esp32
make menuconfig (then just press E)
make -j 8
```

### To build esp32 for esp-idf 4.4 and later
```
cd /tools/AtomVM/src/platforms/esp32
. $IDF_PATH/export.sh
python3 $IDF_PATH/tools/idf.py reconfigure
python3 $IDF_PATH/tools/idf.py build
```

### To create .img
```
cd /tools/AtomVM/build
./tools/release/esp32/mkimage.sh
```

### To erase the flash
```
sudo ${IDF_PATH}/components/esptool_py/esptool/esptool.py --chip esp32 --port /dev/ttyUSB0 --baud 115200 erase_flash
```

### To flash the entire image to device
```
sudo ${IDF_PATH}/components/esptool_py/esptool/esptool.py \
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
Or this script can be used: `FLASH_OFFSET=0x1000 /tools/AtomVM/tools/dev/flash.sh /tools/AtomVM/atomvm-esp32-0.5.0.img`

## For develop the application
### To build .avm
```
rebar3 packbeam
```

### To flash own application
```
sudo ${IDF_PATH}/components/esptool_py/esptool/esptool.py \
    --chip esp32 \
    --port /dev/ttyUSB0 \
    --baud 115200 \
    --before default_reset \
    --after hard_reset \
    write_flash \
    -u --flash_mode dio --flash_freq 40m \
    --flash_size detect \
    0x210000 \
    /tools/atomvm_examples/erlang/blinky/_build/default/lib/blinky.avm
```
Or this script can be used: `/tools/AtomVM/tools/dev/flash.sh /tools/AtomVM/examples/erlang/esp32/blink.avm`


