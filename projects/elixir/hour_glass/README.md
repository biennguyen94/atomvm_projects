<!---
  Copyright 2026 Bien Nguyen <nguyennhubientdh94@gmail.com>

  SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-->

# HourGlass (Elixir)

This is the Elixir port of the `hour_glass` Erlang application.

For a description of this application, please refer to the corresponding [Erlang README](../../erlang/hour_glass/README.md).

---

Sand particle simulation running on AtomVM, using an MPU9250 accelerometer for tilt detection
and 2 MAX7219 LED matrices for display via SPI.

## Project structure

```
lib/
  hour_glass.ex       # Sand physics simulation + tilt control
```

## GPIO pinout

### I2C (MPU9250)
| Pin | GPIO |
|-----|------|
| SCL | 22 |
| SDA | 21 |
| MPU9250 address | 0x68 |

### SPI (MAX7219)
| Pin | GPIO |
|-----|------|
| MISO | 19 |
| MOSI | 27 |
| SCLK | 5 |
| CS (device_1, left LED) | 18 |
| CS (device_2, right LED) | 23 |

## How it works

The MPU9250 accelerometer measures the device's orientation. Sand grains (lit pixels) on two
8x8 LED matrices respond to gravity:

- **Tilt detection**: angle calculated from accelerometer X/Y axes
- **4 orientations**: top, bottom, left, right
- **Sand physics**: each grain tries to fall downward; if blocked, it moves left/right randomly
- **Center bridge**: sand flows between LED matrices through a gate at `{0,7}` ↔ `{7,0}`
- **Coordinate transform**: each orientation rotates the display so gravity always pulls
  "downward"

### Orientation mapping

| Angle range | Direction |
|-------------|-----------|
| -80° to -100° | Top |
| 160° to 180° | Left |
| -10° to 10° | Right |
| 80° to 90° | Bottom |
| otherwise | Mid (no change) |

### Particle movement

On each simulation tick (every 10ms):
1. All sand grains are scanned diagonally (top-right to bottom-left)
2. Each grain tries to fall down; if the space below is occupied, it branches left or right
3. Sand accumulates at the bottom until it fills the matrix, then spills through the center
   gate to the other LED
4. When all grains settle (no changes between ticks), the simulation pauses until the
   device is tilted again

## SPI initialization

Both MAX7219 modules are configured with intensity 0 (dim) for a subtle hourglass effect.
The default state is: LED 0 empty, LED 1 full of sand.
