<!---
  Copyright 2026 Bien Nguyen <nguyennhubientdh94@gmail.com>

  SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-->

# Block Breaker 2LED (Elixir)

This is the Elixir port of the `block_breaker_2led` Erlang application.

For a description of this application, please refer to the corresponding [Erlang README](../../erlang/block_breaker_2led/README.md).

---

Block Breaker (Breakout) running on AtomVM, using 2 MAX7219 LED matrix modules
controlled via SPI. Controlled by analog joystick, game speed adjustable via
variable resistor.

## Project structure

```
lib/
  block_breaker_2led.ex    # Block Breaker game on 2 LED matrices
```

## GPIO pinout

### Joystick & variable resistor
| Pin | GPIO |
|------|------|
| VRx (ADC) | 34 |
| VRy (ADC) | 35 (unused in this game) |
| SW (push button) | 32 (input, pull-up) |
| Variable resistor (ADC) | 33 |

### SPI (MAX7219)
| Pin | GPIO |
|------|------|
| MISO | 19 |
| MOSI | 27 |
| SCLK | 5 |
| CS (device_1) | 18 |
| CS (device_2) | 23 |

## How to play

- Joystick **left/right** moves the paddle
- Press joystick button to start
- Break all 32 blocks to win
- Ball bounces off walls, paddle, and blocks
- Score displayed as 7-segment digits on LED matrix on game over

## Speed control via variable resistor

Turn the variable resistor to adjust game speed in real time:

| Speed | Meaning |
|-------|---------|
| 100 | Very fast |
| 300 | Fast |
| 500 | Medium |
| 800 | Slow |
| 1000 | Very slow |

## Block layout

- 32 breakable blocks (8 columns × 2 rows × 2 LEDs)
- Rows 6 and 7 on both LED matrices
- Blocks are mirrored across both matrices
