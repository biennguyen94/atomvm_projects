# Docker build
```
docker build --network host -t bien_atomvm.test .
```

# Docker run
```
docker run --privileged -v /dev/:/dev/ --name bien_atomvm -it bien_atomvm.test bash
```

Check by command in container: `ls /dev/tty*`, if we can see `/dev/ttyUSB0`, then we are success

# Build .avm
```
cd /tools/atomvm_basic_projects/example/2_blinky/
rebar3 packbeam
```

# Load .avm
```
${IDF_PATH}/components/esptool_py/esptool/esptool.py \
    --chip esp32 \
    --port /dev/ttyUSB0 \
    --baud 115200 \
    --before default_reset \
    --after hard_reset \
    write_flash \
    -u --flash_mode dio --flash_freq 40m \
    --flash_size detect \
    0x210000 \
    /tools/atomvm_basic_projects/example/2_blinky/_build/default/lib/blinky.avm
```

Open minicom:
```
minicom -D /dev/ttyUSB0
```

# Access to container  (for 2nd times)
```
docker start bien_atomvm
docker exec -it bien_atomvm bash
```

# Refer
https://forums.docker.com/t/how-to-expose-host-serial-port-to-container-correctly/81588/2
https://www.losant.com/blog/how-to-access-serial-devices-in-docker
https://stackoverflow.com/questions/24225647/docker-a-way-to-give-access-to-a-host-usb-or-serial-device
