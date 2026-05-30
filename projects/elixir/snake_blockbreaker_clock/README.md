<!---
  Copyright 2026 Bien Nguyen <nguyennhubientdh94@gmail.com>

  SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-->

# Snake Blockbreaker Clock (Elixir)

Fork of the `snake_blockbreaker` Elixir application, modified to show a **digital clock with transition effects** on 2 MAX7219 LED matrix modules as the primary mode, with Snake Game and Block Breaker as secondary features.

## Overview

The device boots into **clock mode**: displays HH:MM on two 8x8 LED matrices, synchronized via SNTP. The clock supports:

- Joystick-controlled pan (horizontal/vertical scroll) of the display
- Three transition effects on digit change: `rain_v` (vertical rain), `rain_h` (horizontal rain), `scroll_up`
- Blinking colon separator
- Returns to game selection after a timeout

When the joystick button is pressed in clock mode, the device exits to the **game selection screen**, where the player can choose Snake Game or Block Breaker (same as the original).

## Project structure

```
lib/
  snake_blockbreaker_clock.ex    # Launcher + clock mode + game selection
  snake_game_2led.ex             # Snake game on 2 LED matrices
  block_breaker_2led.ex          # Block Breaker game on 2 LED matrices
  snake_blockbreaker_clock/
    disterl.ex                   # DistErl setup + speed control
    wifi.ex                      # WiFi STA connection
    nvs.ex                       # WiFi credentials (hardcoded)
```

## GPIO pinout

### Joystick
| Pin | GPIO |
|------|------|
| VRx (ADC) | 34 |
| VRy (ADC) | 35 |
| SW (push button) | 32 (input, pull-up) |

### SPI (MAX7219)
| Pin | GPIO |
|------|------|
| MISO | 19 |
| MOSI | 27 |
| SCLK | 5 |
| CS (device_1) | 18 |
| CS (device_2) | 23 |

## Clock mode

- Time is fetched via SNTP (pool.ntp.org) and displayed as **HH:MM** in 7-segment style
- Left matrix shows hours, right matrix shows minutes
- A blinking dot (colon) alternates between the two matrices
- **Joystick X/Y** pans the display horizontally/vertically
- When the digits change, one of 3 effects plays:
  - `rain_v` — columns fall from top with checkerboard pattern
  - `rain_h` — rows flow from left
  - `scroll_up` — old digits scroll upward revealing new digits
- **Short button press** → exit to game selection
- **Long button press** (2s) → unused in clock mode

## Game selection

Joystick **left** → Snake Game, joystick **right** → Block Breaker.

Both games can return to clock mode via a **long press** (2s) of the joystick button.

## Remote speed control via DistErl

Same as the original project. Edit credentials in `lib/snake_blockbreaker_clock/nvs.ex`.

### Connect from your computer

```bash
iex --name host@172.17.0.2 --cookie AtomVM
```

```elixir
device = :"biennguyen@192.168.1.250"
Node.connect(device)
send({:snake_speed, device}, {:set_speed, 300})
```

## WiFi configuration

Edit `lib/snake_blockbreaker_clock/nvs.ex`:

```elixir
@wifi_ssid "your_SSID"
@wifi_passphrase "your_password"
```

If WiFi is unavailable, the clock still runs using `system_time` (no SNTP sync), and games use default speed.
