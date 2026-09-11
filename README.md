# AtomVM Projects

A collection of Erlang and Elixir projects for [AtomVM](https://github.com/atomvm/AtomVM) on ESP32, with Docker-based development environment tooling.

## Table of Contents

- [AtomVM Projects](#atomvm-projects)
  - [Table of Contents](#table-of-contents)
  - [Repository Structure](#repository-structure)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [WSL USB Setup](#wsl-usb-setup)
    - [1. Deploy Docker Container](#1-deploy-docker-container)
    - [2. Access Container \& Erase Firmware](#2-access-container--erase-firmware)
    - [3. Flash AtomVM Image](#3-flash-atomvm-image)
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
| `docker/` | Dockerfiles for building development environments (Ubuntu 18.04 / 20.04 / 22.04 / 24.04 / Debian 13) |
| `example/` | Peripheral and feature demonstration programs (Erlang & Elixir) |
| `projects/` | Full application projects (Erlang & Elixir) |

## Getting Started

### Prerequisites

- Docker (required)
- ESP32 development board
- USB cable for connecting ESP32 to your computer

### WSL USB Setup

> **Linux users:** Skip this section and continue with [Deploy Docker Container](#1-deploy-docker-container).

On Windows with WSL, use [`usbipd-win`](https://github.com/dorssel/usbipd-win) to attach the ESP32 USB device to your WSL distribution. Run the installation and device commands in **Windows PowerShell as Administrator**:

```powershell
# Install usbipd-win (or install it from the Microsoft Store)
winget install --interactive --exact dorssel.usbipd-win

# List connected USB devices and note the ESP32 BUSID
usbipd list

# Share the ESP32 USB device (replace 4-1 with your BUSID)
usbipd bind --busid 4-1
```

Then attach the device to WSL from a regular PowerShell window:

```powershell
usbipd attach --wsl --busid 4-1
```

Inside WSL, verify that the serial device is available before starting the container:

```bash
ls /dev/ttyUSB* /dev/ttyACM*
```

If the board is unplugged or WSL is restarted, run `usbipd list` and the attach command again. To release it from WSL, run `usbipd detach --busid 4-1` in PowerShell.

### 1. Deploy Docker Container

The quickest option is to run the setup script from the repository root. It pulls the pre-built image, starts the container, and updates the repository inside the container:

```bash
./setup.sh
```

The script creates the container with the name `bien_atomvm` and runs `git pull` in `/tools/atomvm_projects` inside the container. Alternatively, use one of the manual setup options below.

#### Use the Pre-built Image

```bash
docker pull biennguyen94/atomvm:debian13_v1
docker run --privileged -v /dev/:/dev/ -d --name bien_atomvm -it biennguyen94/atomvm:debian13_v1 bash
```

#### Build the Image Locally

```bash
cd docker/debian-13
docker build --network host -t atomvm:debian13 .
docker run --privileged -v /dev/:/dev/ -d --name bien_atomvm -it atomvm:debian13 bash
```

### 2. Access Container & Erase Firmware

Connect your ESP32 and verify it's detected:

```bash
# Access container
docker exec -it bien_atomvm bash

# Verify ESP32 is connected
ls /dev/ttyUSB0

# Erase existing firmware
esptool --chip esp32 --port /dev/ttyUSB0 --baud 115200 erase-flash
```

### 3. Flash AtomVM Image

Erlang
```bash
cd /tools/atomvm_projects
esptool \
    --chip esp32 --port /dev/ttyUSB0 --baud 115200 \
    --before default-reset --after hard-reset \
    write-flash -u --flash-mode dio --flash-freq 40m --flash-size detect \
    0x1000 atomvm_image/AtomVM-esp32-v0.7.0-alpha.1.img
```

Elixir--flash-freq
```bash
cd /tools/atomvm_projects
esptool \
    --chip esp32 --port /dev/ttyUSB0 --baud 115200 \
    --before default-reset --after hard-reset \
    write-flash -u --flash-mode dio --flash-freq 40m --flash-size detect \
    0x1000 atomvm_image/AtomVM-esp32-elixir-v0.7.0-alpha.1.img
```

> **Note**: If you get `No module named esptool`, run `. $IDF_PATH/export.sh`.

## Building and Flashing Applications

### Erlang (Rebar3)

```bash
# Build .avm packbeam
cd /tools/atomvm_projects/example/erlang/hello_world
rebar3 atomvm packbeam

# Flash to ESP32 (offset 0x210000)
rebar3 atomvm esp32_flash --port /dev/ttyUSB0
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
| `sg90_servo/` | SG90 servo control example |
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
| `snake_blockbreaker_clock/` | Snake + clock combo (Elixir-only example) |
| `snake_game_2led/` | Snake game on 2 LED matrices |
| `sntp_clock/` | SNTP-based clock example (Elixir-only) |

All Erlang projects have matching Elixir ports; the Elixir set also includes additional examples such as `snake_blockbreaker_clock` and `sntp_clock`.

## Available Firmware Images

Pre-built images are located in the `atomvm_image/` directory. Flash at offset `0x1000`.

| File | Description |
|------|-------------|
| `AtomVM-esp32-v0.7.0-alpha.1.img` | AtomVM (Erlang only), v0.7.0-alpha.1 |
| `AtomVM-esp32-elixir-v0.7.0-alpha.1.img` | AtomVM with Elixir support, v0.7.0-alpha.1 |

## Additional Resources

- [AtomVM Getting Started Guide](https://doc.atomvm.org/main/getting-started-guide.html) — official guide for setting up the AtomVM development environment and writing your first application.
