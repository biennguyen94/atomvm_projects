# Basic project for ESP32 (AtomVM)
## Trees
* atomvm_image: contains available built AtomVM images
* doc: contains useful documents
* docker: contains dockers images with all packages (lib, esp, ..) built for different Ubuntu versions
* example: contain periperals demo
* projects: contain projects

## Deployment and Flashing an application to ESP32
### Deploy docker container environment
- Pull docker image:
  `docker pull biennguyen94/atomvm:ubuntu24_04_v1`
- Or optionally, you can build docker image by yourself:
  ```
  cd /tools/atomvm_basic_projects/docker/24.04 &&\
  docker build --network host -t <image_name> .
  ```
- Deploy docker image to container:
  `docker run --privileged -v /dev/:/dev/ -d --name bien_atomvm -it biennguyen94/atomvm:ubuntu24_04_v1 bash`

  Note: if you pull image from my docker hub, <image_name> will be biennguyen94/atomvm:ubuntu24_04_v1 as above command, in case you build it by yourself, pls adapt it to yours
- Access to container:
  `docker exec -it bien_atomvm bash`

### Erase and Flash .img to ESP32
- Access to container
  `docker exec -it bien_atomvm bash`
- Connect ESP32 to computer via USB, check by command in container: `ls /dev/tty*`, if you can see `/dev/ttyUSB0`, then you are success to connect ESP32 to the container
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
    /tools/atomvm_basic_projects/atomvm_image/AtomVM-esp32-elixir-v0.7.0-alpha.1.img
```

### Erlang - Build and flash an application (.avm) to ESP32
- Whenever you have an .img is already flashed to ESP32, you can do following steps to build and flash applications.
- Access to container
  `docker exec -it bien_atomvm bash`
- Connect ESP32 to computer via USB, check by command in container: `ls /dev/tty*`, if you can see `/dev/ttyUSB0`, then you are success to connect ESP32 to the container
- Clone repo
  ```
  cd /tools/ &&\
  git clone https://github.com/biennguyen94/atomvm_basic_projects.git
  ```
- Build an erlang application (.avm)
  ```
  cd /tools/atomvm_basic_projects/example/erlang/hello_world/ &&\
  rebar3 packbeam
  ```
  or
  `rebar3 atomvm packbeam`
- Flash .avm onto ESP32
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
  or
  `rebar3 atomvm esp32_flash --port /dev/ttyUSB0`

Note: if you encounter this error `/usr/bin/python3: No module named esptool` when flashing an .avm, you can fix it by: `. $IDF_PATH/export.sh`
- Open minicom for debugging
  `minicom -D /dev/ttyUSB0`

Note: minicom and flashing an .avm are using a same USB device port, so note that whenever you flash an .avm, you must close minicom.

### Elixir - Build and flash an application (.avm) to ESP32
- Whenever you have an .img is already flashed to ESP32, you can do following steps to build and flash applications.
- Access to container
  `docker exec -it bien_atomvm bash`
- Connect ESP32 to computer via USB, check by command in container: `ls /dev/tty*`, if you can see `/dev/ttyUSB0`, then you are success to connect ESP32 to the container
- Clone repo
  ```
  cd /tools/ &&\
  git clone https://github.com/biennguyen94/atomvm_basic_projects.git
  ```
- Build an erlang application (.avm)
  ```
  cd /tools/atomvm_basic_projects/example/elixir/HelloWorld &&\
  mix deps.get && mix atomvm.packbeam
  ```
- Flash .avm onto ESP32
  ```
  mix atomvm.esp32.flash --port /dev/ttyUSB0
  ```

Note: if you encounter this error `/usr/bin/python3: No module named esptool` when flashing an .avm, you can fix it by: `. $IDF_PATH/export.sh`
- Open minicom for debugging
  `minicom -D /dev/ttyUSB0`

Note: minicom and flashing an .avm are using a same USB device port, so note that whenever you flash an .avm, you must close minicom.