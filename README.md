# Basic project for ESP32 (AtomVM)
## Trees
* atomvm_image: contains some useful available built AtomVM images
* doc: contains all useful documents
* docker: contains all dockers images with all packages (lib, esp, ..) built for different Ubuntu version and sphinx server
* example: contain all basic applications and projects

## Deployment and Flashing an application to ESP32
### Deploy docker container environment
- Pull docker image:
  `docker pull biennguyen94/atomvm:ubuntu24_04_v1`
- Deploy docker image to container:
  `docker run --privileged -v /dev/:/dev/ -d --name bien_atomvm -it biennguyen94/atomvm:ubuntu24_04_v1 bash`
- Access to container:
  `docker exec -it bien_atomvm bash`
- Add needed PATH:
  ```
  export PATH="$PATH:/root/26.2.5.5/.cache/rebar3/bin" &&\
  . $IDF_PATH/export.sh
  ```

### Erase and Flash .img to ESP32
- Access to container
  `docker exec -it bien_atomvm bash`
- Connect ESP32 to computer via USB, check by command in container: `ls /dev/tty*`, if we can see `/dev/ttyUSB0`, then we are success to connect ESP32 to our container
- Clone repo
  ```
  cd /tools/ &&\
  git clone https://github.com/biennguyen94/atomvm_basic_projects.git
  ```
- Erase flashed .img:
 ```
 python3 ${IDF_PATH}/components/esptool_py/esptool/esptool.py --chip esp32 --port /dev/ttyUSB0 --baud 115200 erase_flash
 ```
- Flash .img to ESP32:
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
    /tools/atomvm_basic_projects/atomvm_image/AtomVM-esp32-v0.6.5/AtomVM-esp32-v0.6.5.img
```

### Build and flash an application to ESP32
- Whenever you have .img is already flashed to ESP32, you can do following steps to build and flash applications.
- Access to container
  `docker exec -it bien_atomvm bash`
- Connect ESP32 to computer via USB, check by command in container: `ls /dev/tty*`, if we can see `/dev/ttyUSB0`, then we are success to connect ESP32 to our container
- Build an application source code (.avm)
  ```
  cd /tools/atomvm_basic_projects/example/projects/hello_world/ &&\
  rebar3 packbeam
  ```
- Flash .avm to ESP32
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
    _build/default/lib/hello_world.avm
    ```
- Open minicom for debugging
  `minicom -D /dev/ttyUSB0`

Note: minicom and flashing an .avm are using same a USB device port, so note that whenever you flash .avm, you must close minicom.

