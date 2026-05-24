# AtomVM Projects

A collection of Erlang and Elixir projects for [AtomVM](https://github.com/atomvm/AtomVM) on ESP32, with Docker-based development environment tooling.

## Table of Contents

- [AtomVM Projects](#atomvm-projects)
  - [Table of Contents](#table-of-contents)
  - [Repository Structure](#repository-structure)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [1. Deploy Docker Container](#1-deploy-docker-container)
    - [2. Flash AtomVM Firmware](#2-flash-atomvm-firmware)
  - [Building and Flashing Applications](#building-and-flashing-applications)
    - [Erlang (Rebar3)](#erlang-rebar3)
    - [Elixir (Mix)](#elixir-mix)
    - [Debugging via Serial](#debugging-via-serial)
  - [Examples](#examples)
    - [Erlang (`example/erlang/`)](#erlang-exampleerlang)
    - [Elixir (`example/elixir/`)](#elixir-exampleelixir)
  - [Projects](#projects)
    - [Erlang (`projects/erlang/`)](#erlang-projectserlang)
    - [Elixir (`projects/elixir/`)](#elixir-projectselixir)
  - [Available Firmware Images](#available-firmware-images)
  - [Additional Resources](#additional-resources)

## Repository Structure

| Directory | Description |
|-----------|-------------|
| `atomvm_image/` | Pre-built AtomVM firmware images (`.img`) for ESP32 |
| `docker/` | Dockerfiles for building development environments (Ubuntu 18.04 / 20.04 / 22.04 / 24.04) |
| `example/` | Peripheral and feature demonstration programs (Erlang & Elixir) |
| `projects/` | Full application projects (Erlang & Elixir) |

## Getting Started

### Prerequisites

- Docker (recommended) or ESP-IDF toolchain installed locally
- ESP32 development board
- USB cable for connecting ESP32 to your computer

### 1. Deploy Docker Container

```bash
# Pull pre-built image
docker pull biennguyen94/atomvm:ubuntu24_04_v2

# Or build it yourself
cd docker/24.04
docker build --network host -t <image_name> .

# Run container
docker run --privileged -v /dev/:/dev/ -d --name bien_atomvm -it biennguyen94/atomvm:ubuntu24_04_v2 bash
```

### 2. Flash AtomVM Firmware

```bash
# Access container
docker exec -it bien_atomvm bash

# Connect ESP32 and verify
ls /dev/ttyUSB0

# Erase existing firmware
python3 ${IDF_PATH}/components/esptool_py/esptool/esptool.py \
    --chip esp32 --port /dev/ttyUSB0 --baud 115200 erase_flash

# Flash AtomVM image (offset 0x1000)

### Elixir
```bash
cd /tools/atomvm_projects
python3 ${IDF_PATH}/components/esptool_py/esptool/esptool.py \
    --chip esp32 --port /dev/ttyUSB0 --baud 115200 \
    --before default_reset --after hard_reset \
    write_flash -u --flash_mode dio --flash_freq 40m --flash_size detect \
    0x1000 atomvm_image/AtomVM-esp32-elixir-v0.7.0-alpha.1.img
```

### Erlang
```bash
cd /tools/atomvm_projects
python3 ${IDF_PATH}/components/esptool_py/esptool/esptool.py \
    --chip esp32 --port /dev/ttyUSB0 --baud 115200 \
    --before default_reset --after hard_reset \
    write_flash -u --flash_mode dio --flash_freq 40m --flash_size detect \
    0x1000 atomvm_image/AtomVM-esp32-v0.7.0-alpha.1.img
```

> **Note**: If you get `No module named esptool`, run `. $IDF_PATH/export.sh`.

## Building and Flashing Applications

### Erlang (Rebar3)

```bash
# Build .avm packbeam
cd /tools/atomvm_projects/example/erlang/hello_world
rebar3 packbeam          # or: rebar3 atomvm packbeam

# Flash to ESP32 (offset 0x210000)
rebar3 atomvm esp32_flash --port /dev/ttyUSB0

# Or manually with esptool:
python3 ${IDF_PATH}/components/esptool_py/esptool/esptool.py \
    --chip esp32 --port /dev/ttyUSB0 --baud 115200 \
    --before default_reset --after hard_reset \
    write_flash -u --flash_mode dio --flash_freq 40m --flash_size detect \
    0x210000 _build/default/lib/hello_world.avm
```

### Elixir (Mix)

```bash
# Build .avm packbeam
cd /tools/atomvm_projects/example/elixir/HelloWorld
mix deps.get && mix atomvm.packbeam

# Flash to ESP32
mix atomvm.esp32.flash --port /dev/ttyUSB0
```

### Debugging via Serial

```bash
minicom -D /dev/ttyUSB0
```

> **Note**: minicom and esptool share the same USB port — close minicom before flashing.

## Examples

### Erlang (`example/erlang/`)

| Project | Description |
|---------|-------------|
| `hello_world/` | Minimal hello world |
| `control_led/` | LED control via web interface |
| `encoder/` | Rotary encoder |
| `esp32_heart/` | LED matrix heart display |
| `gpio_interrupt/` | GPIO interrupt handling |
| `joystick/` | Joystick ADC input |
| `ledc/` | LED PWM controller with web control |
| `mpu6500/` | MPU6500 accelerometer/gyroscope sensor |

### Elixir (`example/elixir/`)

| Project | Description |
|---------|-------------|
| `HelloWorld/` | Minimal hello world |
| `Blinky/` | Blink an LED |
| `ControlLed/` | LED control |
| `Encoder/` | Rotary encoder |
| `Esp32Heart/` | LED matrix heart display |
| `GpioInterrupt/` | GPIO interrupt handling |
| `Joystick/` | Joystick ADC input |
| `LEDC_Example/` | LED PWM controller (fade) |
| `LEDC_Example2/` | LED PWM controller with web control |
| `Mpu6500/` | MPU6500 sensor |
| `esp32_temp/` | ESP32 temperature sensor |
| `mpu6500_web_temp/` | MPU6500 sensor with web interface |
| `hello_atomvm_disterl_wifi/` | Wi-Fi + distributed Erlang messaging *(empty/placeholder)* |

## Projects

### Erlang (`projects/erlang/`)

| Project | Description |
|---------|-------------|
| `block_breaker_2led/` | Block breaker game on 2 LED matrices |
| `calculator/` | Calculator with LCD and keypad |
| `car_project/` | WiFi-controlled car |
| `hour_glass/` | Hour glass game with motion sensing |
| `self_balance_robot/` | Self-balancing robot |
| `snake_blockbreaker/` | Snake and block breaker combo |
| `snake_game_2led/` | Snake game on 2 LED matrices |

### Elixir (`projects/elixir/`)

| Project | Description |
|---------|-------------|
| `block_breaker_2led/` | Block breaker game on 2 LED matrices |
| `calculator/` | Calculator with LCD and keypad |
| `car_project/` | WiFi-controlled car |
| `hour_glass/` | Hour glass game with motion sensing |
| `self_balance_robot/` | Self-balancing robot |
| `snake_blockbreaker/` | Snake and block breaker combo |
| `snake_game_2led/` | Snake game on 2 LED matrices |

All 7 Erlang projects have matching Elixir ports — the same applications reimplemented in Elixir.

## Available Firmware Images

Pre-built images are located in the `atomvm_image/` directory. Flash at offset `0x1000`.

| File | Description |
|------|-------------|
| `AtomVM-esp32-elixir-v0.7.0-alpha.1.img` | AtomVM with Elixir support, v0.7.0-alpha.1 |
| `AtomVM-esp32-v0.7.0-alpha.1.img` | AtomVM (Erlang only), v0.7.0-alpha.1 |

## Additional Resources

- [AtomVM Getting Started Guide](https://doc.atomvm.org/main/getting-started-guide.html) — official guide for setting up the AtomVM development environment and writing your first application.
