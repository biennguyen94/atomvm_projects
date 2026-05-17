<!---
  Copyright 2026 Bien Nguyen <nguyennhubientdh94@gmail.com>

  SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-->

# AtomVM Elixir Project Programs

Welcome to the AtomVM Elixir Project programs.

The applications in this directory are Elixir ports of the corresponding Erlang projects. They make use of the [AtomVM Mix Plugin](https://github.com/atomvm/ExAtomVM) to compile, assemble, and if applicable, flash the application onto an ESP32 device.

For descriptions of each application, please refer to the README in the corresponding Erlang directory:

| Elixir Application | Erlang README |
|--------------------|---------------|
| [block_breaker_2led](block_breaker_2led/README.md) | [Erlang](../erlang/block_breaker_2led/README.md) |
| [calculator](calculator/README.md) | [Erlang](../erlang/calculator/README.md) |
| [car_project](car_project/README.md) | [Erlang](../erlang/car_project/README.md) |
| [hour_glass](hour_glass/README.md) | [Erlang](../erlang/hour_glass/README.md) |
| [self_balance_robot](self_balance_robot/README.md) | [Erlang](../erlang/self_balance_robot/README.md) |
| [snake_blockbreaker](snake_blockbreaker/README.md) | [Erlang](../erlang/snake_blockbreaker/README.md) |
| [snake_game_2led](snake_game_2led/README.md) | [Erlang](../erlang/snake_game_2led/README.md) |

To build and run an example in this directory, change your working directory to the corresponding example program, and execute the generic instructions below.

## Generic Instructions

The following generic instructions apply to the Elixir tests in this repository. Special notes about building and running the example programs that deviate from these instructions are noted in the README file for the particular example program.

### Preparation (Optional)

In order to avoid warnings from the Elixir compiler, you can make all of the symbols used from AtomVM libraries available to your application at build time. This has the advantage of making the compiler less noisy. However, it has the side effect of making your application files larger than they need to be, which can increase the time to deploy your applications to flash storage, for example, on a device.

If you want to take this path, create a directory called `avm_deps` in the top level of this project directory:

    shell$ mkdir avm_deps

Download a copy of the AtomVM library (`atomvmlib-<version>.avm`) from the AtomVM Github [release repository](https://github.com/atomvm/AtomVM/releases/). Copy this file into the `avm_deps` directory.

Afterwards, you should see something like:

    shell$ ls -l avm_deps
    total 264
    -rw-rw-r--  1 user  wheel  11380 May  8 16:32 atomvmlib-v0.6.0.avm

### Building

To build and package this application into an AtomVM AVM file, use the `packbeam` target:

    shell$ mix deps.get
    shell$ mix atomvm.packbeam

This target will create an AVM file (e.g., `calculator.avm`) file in the top-level directory.

### Running on the ESP32 platform

To run this application on the ESP32 platform, you must flash the application to the device attached to your computer via USB. You may then optionally monitor the program via a serial console program to view any data output to the console.

#### Flashing onto an ESP32 Device

To flash this application to your ESP32 device, issue the `esp32_flash` target. Use the `--port` option to specify the port to which your device is connected:

    shell$ mix atomvm.esp32.flash --port /dev/ttyUSB0

#### Monitoring an ESP32 Device

Use a serial console program, such as `minicom`, to attach to the device over USB:

    shell$ minicom -D /dev/ttyUSB0


