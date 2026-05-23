<!---
  Copyright 2026 Bien Nguyen <nguyennhubientdh94@gmail.com>

  SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-->

# Snake Blockbreaker (Elixir)

This is the Elixir port of the `snake_blockbreaker` Erlang application.

For a description of this application, please refer to the corresponding [Erlang README](../../erlang/snake_blockbreaker/README.md).

---

Snake Game and Block Breaker (Breakout) running on AtomVM, using 2 MAX7219 LED matrix modules
controlled via SPI. Controlled by analog joystick, game speed adjustable remotely via
Distributed Erlang (disterl).

## Project structure

```
lib/
  snake_blockbreaker.ex        # Launcher: game selection screen
  snake_game_2led.ex           # Snake game on 2 LED matrices
  block_breaker_2led.ex        # Block Breaker game on 2 LED matrices
  snake_blockbreaker/
    disterl.ex                 # DistErl setup + speed control
    wifi.ex                    # WiFi STA connection
    nvs.ex                     # WiFi credentials (hardcoded)
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

## How to play

### Game selection
Joystick **left** → Snake Game, joystick **right** → Block Breaker.

### Snake Game
- Joystick controls snake direction (left/right/up/down)
- Press joystick button to start / return to game selection
- Eat blinking food (`*`) to increase score and length
- Game over when snake hits itself
- Score displayed as 7-segment digits on LED matrix

### Block Breaker
- Joystick left/right moves the paddle
- Press joystick button to start
- Break all 32 blocks to win
- Ball bounces off walls, paddle, and blocks

## Remote speed control via DistErl

ESP32 automatically connects to WiFi on boot (edit SSID/password in
`lib/snake_blockbreaker/nvs.ex`). Once an IP is obtained, a DistErl node is started with name
`biennguyen@<IP>`.

### Connect from your computer

```bash
# Get your computer's IP
hostname -I

# Start IEx with the same cookie
iex --name host@172.17.0.2 --cookie AtomVM
```

In IEx:

```elixir
device = :"biennguyen@192.168.1.250"

Node.connect(device)

Node.list(:connected)
# => [:"biennguyen@192.168.1.250"]

# Send speed: 200 = fast, 1000 = slow
send({:snake_speed, device}, {:set_speed, 300})
```

### Speed values

| Speed | Meaning |
|-------|---------|
| 200 | Very fast |
| 300 | Fast |
| 500 | Medium |
| 800 | Slow |
| 1000 | Very slow |

## WiFi configuration

Edit `lib/snake_blockbreaker/nvs.ex`:

```elixir
@wifi_ssid "your_SSID"
@wifi_passphrase "your_password"
```

If WiFi is unavailable, the game still runs normally (default speed 200ms, remote control
unavailable).
