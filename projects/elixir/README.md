<!---
  Copyright 2026 Bien Nguyen <nguyennhubientdh94@gmail.com>

  SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-->

# AtomVM Elixir Project Programs

Welcome to the AtomVM Elixir Project programs.

The applications in this directory are Elixir ports of the corresponding Erlang projects. They make use of the [AtomVM Mix Plugin](https://github.com/atomvm/ExAtomVM) to compile, assemble, and if applicable, flash the application onto an ESP32 device.

| Project | esp32 |
|---------|-------|
| block_breaker_2led | ✅ |
| calculator | ❌ |
| car_project | ❌ |
| hour_glass | ✅ |
| self_balance_robot | ❌ |
| snake_blockbreaker | ✅ |
| snake_game_2led | ✅ |

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

For build and flash instructions, please refer to the [root README](../../README.md).

ESP32 peripheral wiring for each application is documented in the corresponding Erlang README.


