<!---
  Copyright 2026 Bien Nguyen <nguyennhubientdh94@gmail.com>

  SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-->

# Snake Game 2LED (Elixir)

This is the Elixir port of the `snake_game_2led` Erlang application.

For a description of this application, please refer to the corresponding [Erlang README](../../erlang/snake_game_2led/README.md).

---

Snake Game running on AtomVM, using 2 MAX7219 LED matrix modules
controlled via SPI. Controlled by analog joystick, game speed adjustable via
variable resistor.

## Project structure

```
lib/
  snake_game_2led.ex       # Snake game on 2 LED matrices
```

## GPIO pinout

### Joystick & variable resistor
| Pin | GPIO |
|------|------|
| VRx (ADC) | 34 |
| VRy (ADC) | 35 |
| SW (push button) | 32 (input, pull-up) |
| Variable resistor (ADC) | 33 (unused in this game) |

### SPI (MAX7219)
| Pin | GPIO |
|------|------|
| MISO | 19 |
| MOSI | 27 |
| SCLK | 5 |
| CS (device_1) | 18 |
| CS (device_2) | 23 |

## How to play

- Joystick controls snake direction (left/right/up/down)
- Press joystick button to start / restart
- Eat blinking food (`*`) to increase score and length
- Snake wraps across LED matrix borders
- Game over when snake hits itself
- Score displayed as 7-segment digits on LED matrix on game over

## Speed control

Game speed is fixed at 200ms per tick. Speed is adjustable only in the
parent `snake_blockbreaker` project which supports remote DistErl control.
