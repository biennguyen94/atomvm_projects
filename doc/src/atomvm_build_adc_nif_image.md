# Build and Run ADC test
## Create .img (ubuntu 18.04)
```
cd /tools
git clone -b release-0.5 https://github.com/atomvm/AtomVM
mkdir build
cd build
cmake ..
make -j 8

cd /tools/AtomVM/src/platforms/esp32/components
git clone https://github.com/biennguyen94/atomvm_adc.git

cd /tools/AtomVM/src/platforms/esp32/
make

/tools/AtomVM/build/tools/release/esp32/mkimage.sh
```
note: this .img is also available at: https://github.com/biennguyen94/atomvm_basic_projects/tree/master/atomvm_image/adc_nif

## Erase & Flash to esp32
### Erase
For ubuntu 20.04:
```
sudo python3 ${IDF_PATH}/components/esptool_py/esptool/esptool.py --chip esp32 --port /dev/ttyUSB0 --baud 115200 erase_flash
```
For ubuntu 18.04:
```
sudo ${IDF_PATH}/components/esptool_py/esptool/esptool.py --chip esp32 --port /dev/ttyUSB0 --baud 115200 erase_flash
```
### Flash
For ubuntu 20.04:
```
sudo python3 ${IDF_PATH}/components/esptool_py/esptool/esptool.py \
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
For ubuntu 18.04:
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

## Run ADC test
rebar.config needs to contain as following:
```
{erl_opts, [debug_info]}.
{deps, [
    {atomvm_adc, {git, "https://github.com/biennguyen94/atomvm_adc.git", {branch, "master"}}}
]}.
{plugins, [atomvm_rebar3_plugin]}.
```
Run adc test as normal in 14_adc_example folder (note only need to flash adc_example.avm)
