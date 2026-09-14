#
# This file is part of AtomVM.
#
# Copyright 2026 Bien Nguyen <nguyennhubientdh94@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

defmodule SnakeBlockbreakerClock do
  @moduledoc """
  Game launcher / menu selector for Snake Game and Block Breaker on AtomVM, using 2 MAX7219 LED
  matrices controlled via SPI.

  ## Overview
  This module is the parent GenServer that presents a game selection screen on two 8x8 LED matrix
  modules (MAX7219). The player uses the joystick X-axis to choose between Snake Game (joystick
  left) and Block Breaker (joystick right). Once selected, it spawns the corresponding game
  module (`SnakeGame2Led` or `BlockBreaker2Led`) and passes the SPI handle.

  ## Features
  - Animated game selection screen with snake (LED 0) and breaker (LED 1) icons scrolling
  - Joystick-based game selection (left = Snake, right = Block Breaker)
  - Clock with joystick effects, up/down gestures and scrolling messages
  - Joystick UP cycles display modes: time (HH:MM) → solar date (day/month) →
    Vietnamese lunar date âm lịch (day/month) → time
  - Initializes 2 MAX7219 modules on separate SPI chip-select lines (CS=18 for device_1,
    CS=23 for device_2 – note device_2 uses a different CS than the game modules)
  - Configures both MAX7219: no decode, intensity 3, scan limit 8, shutdown off, test off

  ## GPIO pinout
  - VRx (ADC) → GPIO34 – used for game selection
  - All other GPIO pins are configured but only VRx is used in this module

  ### SPI configuration
  - bus: MISO=19, MOSI=27, SCLK=5
  - device_1: clock=1MHz, mode=0, CS=18, address_len=8
  - device_2: clock=1MHz, mode=0, CS=23, address_len=8

  Note: `SnakeGame2Led` and `BlockBreaker2Led` share the same SPI bus but use CS=18 for both
  devices. This module uses CS=18 for device_1 and CS=23 for device_2.

  ## Flow
  1. `start/0` – initialize GenServer, start ADC, enter `select_game/2`
  2. `init/1` – initialize SPI + both MAX7219 modules, spawn icon animation process
  3. `select_game/2` – poll joystick ADC:
     - ADC < 800 → start SnakeGame2Led
     - ADC > 3000 → start BlockBreaker2Led
     - Otherwise → sleep 100ms, retry
  4. When a game ends, it sends `:game_over` cast → re-run selection animation + poll loop

  ## Animation data
  - `@select_game_snake` – 40-frame bitmap sequence for snake icon on LED 0
  - `@select_game_breaker` – 40-frame bitmap sequence for breaker icon on LED 1
  - Display process scrolls through both sequences in 8-frame steps every 800ms

  ## GenServer messages
  - Cast `:game_over` – return to game selection after a game ends
  - Cast `{:display_select_game_flag, times}` – render current animation frame
  - Info `{pid, :do_select_game}` – stop animation, send SPI handle back to caller
  """
  use GenServer
  use Bitwise

  @no_op 0x0
  @digit_0 0x1
  @digit_1 0x2
  @digit_2 0x3
  @digit_3 0x4
  @digit_4 0x5
  @digit_5 0x6
  @digit_6 0x7
  @digit_7 0x8
  @decode_mode 0x9
  @intensity 0xA
  @scan_limit 0xB
  @shutdown 0xC
  @display_test 0xF

  @gpio_vrx 34
  @gpio_vry 35

  @gpio_miso 19
  @gpio_mosi 27
  @gpio_sclk 5
  @gpio_cs 18

  @gpio_sw 32

  @low_range 800
  @high_range 3000

  @delay_read_adc 100

  @num_of_bits 8

  @sntp_host "pool.ntp.org"
  @timezone_offset_ms 7 * 3600 * 1000

  @empty_matrix %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000000,
    @digit_3 => 0b00000000,
    @digit_4 => 0b00000000,
    @digit_5 => 0b00000000,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @clock_message %{
    1 => 0b00000000,
    2 => 0b00000000,
    3 => 0b00000000,
    4 => 0b00000000,
    5 => 0b00000000,
    6 => 0b00000000,
    7 => 0b00000000,
    8 => 0b00000000,
    9 => 0b00000000,
    10 => 0b00000000,
    11 => 0b00000000,
    12 => 0b00000000,
    13 => 0b00000000,
    14 => 0b00000000,
    15 => 0b00000000,
    16 => 0b00000000,
    17 => 0b00000000,
    18 => 0b01111110,
    19 => 0b00010000,
    20 => 0b00010000,
    21 => 0b01111110,
    22 => 0b00000000,
    23 => 0b01111110,
    24 => 0b01001010,
    25 => 0b01001010,
    26 => 0b01000010,
    27 => 0b00000000,
    28 => 0b01111110,
    29 => 0b01000000,
    30 => 0b01000000,
    31 => 0b00000000,
    32 => 0b01111110,
    33 => 0b01000000,
    34 => 0b01000000,
    35 => 0b00000000,
    36 => 0b00111100,
    37 => 0b01000010,
    38 => 0b01000010,
    39 => 0b00111100,
    40 => 0b00000000,
    41 => 0b00000000,
    42 => 0b00000000,
    43 => 0b00000000,
    44 => 0b00000000,
    45 => 0b00000000,
    46 => 0b00000000,
    47 => 0b00000000,
    48 => 0b00000000,
    49 => 0b00000000,
    50 => 0b00000000,
    51 => 0b00000000,
    52 => 0b00000000,
    53 => 0b00000000,
    54 => 0b00000000,
    55 => 0b00000000,
    56 => 0b00000000
  }

  @creator_text ~c"CREATOR: BIEN NGUYEN"
  @creator_font %{
    ?C => [
      0b00111110,
      0b01000001,
      0b01000001,
      0b01000001,
      0b00100010
    ],
    ?R => [
      0b01111111,
      0b00001001,
      0b00011001,
      0b00101001,
      0b01000110
    ],
    ?E => [
      0b01111111,
      0b01001001,
      0b01001001,
      0b01000001,
      0b01000001
    ],
    ?A => [
      0b01111110,
      0b00001001,
      0b00001001,
      0b00001001,
      0b01111110
    ],
    ?T => [
      0b00000001,
      0b00000001,
      0b01111111,
      0b00000001,
      0b00000001
    ],
    ?O => [
      0b00111110,
      0b01000001,
      0b01000001,
      0b01000001,
      0b00111110
    ],
    ?: => [
      0b00000000,
      0b00010100,
      0b00000000,
      0b00010100,
      0b00000000
    ],
    ?B => [
      0b01111111,
      0b01001001,
      0b01001001,
      0b01001001,
      0b00110110
    ],
    ?I => [
      0b00000000,
      0b01000001,
      0b01111111,
      0b01000001,
      0b00000000
    ],
    ?N => [
      0b01111111,
      0b00000110,
      0b00011000,
      0b01100000,
      0b01111111
    ],
    ?G => [
      0b00111110,
      0b01000001,
      0b01001001,
      0b01001001,
      0b00111010
    ],
    ?U => [
      0b00111111,
      0b01000000,
      0b01000000,
      0b01000000,
      0b00111111
    ],
    ?Y => [
      0b00000111,
      0b00001000,
      0b01110000,
      0b00001000,
      0b00000111
    ],
    ?M => [
      0b01111111,
      0b00000110,
      0b00011000,
      0b00000110,
      0b01111111
    ],
    ?\s => [
      0,
      0,
      0,
      0,
      0
    ]
  }
  @clock_message_end_offset 62
  @creator_message_end_offset 104

  @spisettings [
    bus_config: [miso: 19, mosi: 27, sclk: 5],
    device_config: [
      device_1: [clock_speed_hz: 1_000_000, mode: 0, cs: 18, address_len_bits: 8],
      device_2: [clock_speed_hz: 1_000_000, mode: 0, cs: 23, address_len_bits: 8]
    ]
  ]

  defstruct [:spi, :goverproc, :slot, :score]

  @digit_left %{
    0 => %{
      1 => 0b00111100,
      2 => 0b01000010,
      3 => 0b00111100,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b00000000,
      7 => 0b00000000,
      8 => 0b00000000
    },
    1 => %{
      1 => 0b01000100,
      2 => 0b01111110,
      3 => 0b01000000,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b00000000,
      7 => 0b00000000,
      8 => 0b00000000
    },
    2 => %{
      1 => 0b01100100,
      2 => 0b01010010,
      3 => 0b01001100,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b00000000,
      7 => 0b00000000,
      8 => 0b00000000
    },
    3 => %{
      1 => 0b01000010,
      2 => 0b01001010,
      3 => 0b01111110,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b00000000,
      7 => 0b00000000,
      8 => 0b00000000
    },
    4 => %{
      1 => 0b00011000,
      2 => 0b00010100,
      3 => 0b01111110,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b00000000,
      7 => 0b00000000,
      8 => 0b00000000
    },
    5 => %{
      1 => 0b01001110,
      2 => 0b01001010,
      3 => 0b01111010,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b00000000,
      7 => 0b00000000,
      8 => 0b00000000
    },
    6 => %{
      1 => 0b01111110,
      2 => 0b01001010,
      3 => 0b01111010,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b00000000,
      7 => 0b00000000,
      8 => 0b00000000
    },
    7 => %{
      1 => 0b01100010,
      2 => 0b00010010,
      3 => 0b00001110,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b00000000,
      7 => 0b00000000,
      8 => 0b00000000
    },
    8 => %{
      1 => 0b01111110,
      2 => 0b01001010,
      3 => 0b01111110,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b00000000,
      7 => 0b00000000,
      8 => 0b00000000
    },
    9 => %{
      1 => 0b01001110,
      2 => 0b01001010,
      3 => 0b01111110,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b00000000,
      7 => 0b00000000,
      8 => 0b00000000
    }
  }

  @digit_right %{
    0 => %{
      1 => 0b00000000,
      2 => 0b00000000,
      3 => 0b00000000,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b00111100,
      7 => 0b01000010,
      8 => 0b00111100
    },
    1 => %{
      1 => 0b00000000,
      2 => 0b00000000,
      3 => 0b00000000,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b01000100,
      7 => 0b01111110,
      8 => 0b01000000
    },
    2 => %{
      1 => 0b00000000,
      2 => 0b00000000,
      3 => 0b00000000,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b01100100,
      7 => 0b01010010,
      8 => 0b01001100
    },
    3 => %{
      1 => 0b00000000,
      2 => 0b00000000,
      3 => 0b00000000,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b01000010,
      7 => 0b01001010,
      8 => 0b01111110
    },
    4 => %{
      1 => 0b00000000,
      2 => 0b00000000,
      3 => 0b00000000,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b00011000,
      7 => 0b00010100,
      8 => 0b01111110
    },
    5 => %{
      1 => 0b00000000,
      2 => 0b00000000,
      3 => 0b00000000,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b01001110,
      7 => 0b01001010,
      8 => 0b01111010
    },
    6 => %{
      1 => 0b00000000,
      2 => 0b00000000,
      3 => 0b00000000,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b01111110,
      7 => 0b01001010,
      8 => 0b01111010
    },
    7 => %{
      1 => 0b00000000,
      2 => 0b00000000,
      3 => 0b00000000,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b01100010,
      7 => 0b00010010,
      8 => 0b00001110
    },
    8 => %{
      1 => 0b00000000,
      2 => 0b00000000,
      3 => 0b00000000,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b01111110,
      7 => 0b01001010,
      8 => 0b01111110
    },
    9 => %{
      1 => 0b00000000,
      2 => 0b00000000,
      3 => 0b00000000,
      4 => 0b00000000,
      5 => 0b00000000,
      6 => 0b01001110,
      7 => 0b01001010,
      8 => 0b01111110
    }
  }

  @select_game_snake %{
    1 => 0b00000100,
    2 => 0b00011100,
    3 => 0b00110000,
    4 => 0b00100000,
    5 => 0b00000000,
    6 => 0b00000000,
    7 => 0b00100000,
    8 => 0b00000000,
    9 => 0b00000000,
    10 => 0b00011100,
    11 => 0b00110000,
    12 => 0b00100000,
    13 => 0b00100000,
    14 => 0b00000000,
    15 => 0b00100000,
    16 => 0b00000000,
    17 => 0b00000000,
    18 => 0b00011000,
    19 => 0b00110000,
    20 => 0b00100000,
    21 => 0b00100000,
    22 => 0b00100000,
    23 => 0b00100000,
    24 => 0b00000000,
    25 => 0b00000000,
    26 => 0b00010000,
    27 => 0b00110000,
    28 => 0b00100000,
    29 => 0b00100000,
    30 => 0b00100100,
    31 => 0b00100000,
    32 => 0b00100000,
    33 => 0b00000000,
    34 => 0b00000000,
    35 => 0b00110000,
    36 => 0b00100000,
    37 => 0b00100000,
    38 => 0b00100100,
    39 => 0b00100000,
    40 => 0b00110000
  }

  @select_game_breaker %{
    1 => 0b00000011,
    2 => 0b00000011,
    3 => 0b10000011,
    4 => 0b11000011,
    5 => 0b10000011,
    6 => 0b00000011,
    7 => 0b00000011,
    8 => 0b00000011,
    9 => 0b00000011,
    10 => 0b00000011,
    11 => 0b10000011,
    12 => 0b10100011,
    13 => 0b10000011,
    14 => 0b00000011,
    15 => 0b00000011,
    16 => 0b00000011,
    17 => 0b00000011,
    18 => 0b00000011,
    19 => 0b10000011,
    20 => 0b10010011,
    21 => 0b10000011,
    22 => 0b00000011,
    23 => 0b00000011,
    24 => 0b00000011,
    25 => 0b00000011,
    26 => 0b00000011,
    27 => 0b10000011,
    28 => 0b10001011,
    29 => 0b10000011,
    30 => 0b00000011,
    31 => 0b00000011,
    32 => 0b00000011,
    33 => 0b00000011,
    34 => 0b00000011,
    35 => 0b10000011,
    36 => 0b10000101,
    37 => 0b10000011,
    38 => 0b00000011,
    39 => 0b00000011,
    40 => 0b00000011
  }

@select_game_flappy %{
    1 => 0b00000000,
    2 => 0b00000000,
    3 => 0b00010000,
    4 => 0b00010000,
    5 => 0b00000000,
    6 => 0b00000000,
    7 => 0b00000000,
    8 => 0b10000111,
    9 => 0b00000000,
    10 => 0b00000000,
    11 => 0b00100000,
    12 => 0b00100000,
    13 => 0b00000000,
    14 => 0b00000000,
    15 => 0b10000111,
    16 => 0b00000000,
    17 => 0b00000000,
    18 => 0b00000000,
    19 => 0b01000000,
    20 => 0b01000000,
    21 => 0b00000000,
    22 => 0b10000111,
    23 => 0b00000000,
    24 => 0b00000000,
    25 => 0b00000000,
    26 => 0b00000000,
    27 => 0b01000000,
    28 => 0b01000000,
    29 => 0b10000111,
    30 => 0b00000000,
    31 => 0b00000000,
    32 => 0b00000000,
    33 => 0b00000000,
    34 => 0b00000000,
    35 => 0b00100000,
    36 => 0b10100111,
    37 => 0b00000000,
    38 => 0b00000000,
    39 => 0b00000000,
40 => 0b00000000,
    41 => 0b00000000,
    42 => 0b00000000,
    43 => 0b10010111,
     44 => 0b00010000,
     45 => 0b00000000,
     46 => 0b00000000,
     47 => 0b00000000,
     48 => 0b00000000,
     49 => 0b00000000,
     50 => 0b10000111,
     51 => 0b00010000,
     52 => 0b00010000,
     53 => 0b00000000,
     54 => 0b00000000,
     55 => 0b00000000,
     56 => 0b00000000,
     57 => 0b10000111,
     58 => 0b00000000,
     59 => 0b00010000,
     60 => 0b00010000,
     61 => 0b00000000,
     62 => 0b00000000,
     63 => 0b00000000,
     64 => 0b10000111
  }

  def start do
    IO.puts("SnakeBlockbreakerClock: starting")
    :erlang.system_flag(:schedulers_online, 2)

    try do
      :esp.log_level_set("wifi", 1)
      :esp.log_level_set("network_driver", 1)
    rescue
      _ -> :ok
    end

    {:ok, _} = SnakeBlockbreakerClock.DistErl.start_link()

    case SnakeBlockbreakerClock.WiFi.start_link() do
      {:ok, _} -> :ok
      {:error, _} -> IO.puts("wifi: not available, game runs without remote speed control")
    end

    {:ok, pid} = GenServer.start(__MODULE__, [], name: :snake_blockbreaker_clock)

    GPIO.set_pin_mode(@gpio_sw, :input)
    GPIO.set_pin_pull(@gpio_sw, :up)

    setup_adc()
    wait_for_sntp(2)
    IO.puts("start: showing clock")
    show_clock(pid)

    start_animation(pid)
    select_game(pid, @gpio_vrx)
  end

  def init(_) do
    {:ok, spi} = init_max7219(@spisettings)
    IO.puts("Init SPI and MAX7219 OK\n")
    new_state = %__MODULE__{spi: spi, goverproc: nil, slot: :snake, score: 0}
    {:ok, new_state}
  end

  def handle_call(:get_spi, _from, state) do
    {:reply, state.spi, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:set_goverproc, proc}, state) do
    {:noreply, %{state | goverproc: proc}}
  end

  def handle_cast({:set_slot, slot}, state) do
    {:noreply, %{state | slot: slot, score: high_score_for(slot)}}
  end

  def handle_cast(:game_over, state) do
    IO.puts("parent game_over\n")
    :timer.sleep(300)
    setup_adc()
    GPIO.set_pin_mode(@gpio_sw, :input)
    GPIO.set_pin_pull(@gpio_sw, :up)
    new_proc = spawn(__MODULE__, :display_select_game, [self(), 0])
    spawn(__MODULE__, :select_game, [self(), @gpio_vrx])
    new_state = %{state | goverproc: new_proc, slot: :snake, score: high_score_for(:snake)}
    {:noreply, new_state}
  end

  def handle_cast({:exit_to_clock}, state) do
    IO.puts("parent: exiting to clock mode")
    :timer.sleep(300)

    if is_pid(state.goverproc) do
      send(state.goverproc, :stop)
    end

    clear_display(state.spi)
    clock_pid = spawn(__MODULE__, :display_clock, [self(), state.spi])
    {:noreply, %{state | goverproc: clock_pid}}
  end

  def handle_info({:clock_done}, state) do
    IO.puts("parent: clock done, starting game selection")
    new_proc = spawn(__MODULE__, :display_select_game, [self(), 0])
    spawn(__MODULE__, :select_game, [self(), @gpio_vrx, :wait_for_neutral, :snake])
    {:noreply, %{state | goverproc: new_proc, slot: :snake, score: high_score_for(:snake)}}
  end

  def handle_cast({:display_select_game_flag, times}, state) do
    display_game_text(state.spi, times, state.slot, state.score)
    {:noreply, state}
  end

  def handle_info({from, :do_select_game}, state) do
    IO.puts("receive do_select_game")

    if is_pid(state.goverproc) do
      send(state.goverproc, :stop)
    end

    new_state = %{state | goverproc: nil}
    send(from, {:spi, state.spi})
    {:noreply, new_state}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp select_game(pid, adcx) do
    select_game(pid, adcx, :wait_for_neutral, :snake)
  end

  def select_game(pid, adcx, :wait_for_neutral) do
    select_game(pid, adcx, :wait_for_neutral, :snake)
  end

  def select_game(pid, adcx, :wait_for_neutral, slot) do
    :timer.sleep(@delay_read_adc)

    if not button_pressed?() and joystick_neutral?(adcx) do
      select_game(pid, adcx, :ready, slot)
    else
      select_game(pid, adcx, :wait_for_neutral, slot)
    end
  end

  def select_game(pid, adcx, :ready, slot) do
    :timer.sleep(@delay_read_adc)

    tilt =
      if button_pressed?() do
        :button
      else
        read_tilt(adcx)
      end

    case tilt do
      :button ->
        IO.puts("select_game: button pressed -> starting #{slot}")
        start_game(pid, adcx, slot)

      :none ->
        select_game(pid, adcx, :ready, slot)

      direction ->
        new_slot = next_slot(slot, direction)
        IO.puts("select_game: slot #{slot} -> #{new_slot} (joystick #{direction})")
        GenServer.cast(pid, {:set_slot, new_slot})
        select_game(pid, adcx, :wait_for_neutral, new_slot)
    end
  end

  defp read_tilt(adcx) do
    {:ok, x} = read_adc(adcx)
    {:ok, y} = read_adc(@gpio_vry)

    cond do
      x < @low_range -> :left
      x > @high_range -> :right
      y < @low_range -> :down
      y > @high_range -> :up
      true -> :none
    end
  end

  defp joystick_neutral?(adcx) do
    read_tilt(adcx) == :none
  end

  defp next_slot(:snake, :right), do: :breaker
  defp next_slot(:breaker, :right), do: :flappy
  defp next_slot(:flappy, :right), do: :snake
  defp next_slot(:snake, :left), do: :flappy
  defp next_slot(:breaker, :left), do: :snake
  defp next_slot(:flappy, :left), do: :breaker
  defp next_slot(_slot, :down), do: :flappy
  defp next_slot(_slot, :up), do: :snake

  defp start_game(pid, _adcx, slot) do
    send(pid, {self(), :do_select_game})

    receive do
      {:spi, spi} -> start_selected_game(spi, slot)
    end
  end

  defp start_selected_game(spi, :breaker), do: BlockBreaker2Led.start(spi)
  defp start_selected_game(spi, :flappy), do: FlappyBird2Led.start(spi)
  defp start_selected_game(spi, _slot), do: SnakeGame2Led.start(spi)

  def display_select_game(p, times) do
    receive do
      :stop -> :ok
    after
      100 ->
        GenServer.cast(p, {:display_select_game_flag, times})
        new_times = rem(times + 1, 320)
        display_select_game(p, new_times)
    end
  end

  defp display_game_text(spi, times, slot, score) do
    frame = select_game_frame(times, slot)
    data1 = select_menu_matrix(times, slot)
    data1 = overlay_score(data1, stack_score(score))
    data2 = get_data(@empty_matrix, 1, frame, slot)
    write_digit(spi, @digit_0, data1, :device_1)
    write_digit(spi, @digit_0, data2, :device_2)
  end

  defp stack_score(score) do
    capped = min(score, 99)
    score_map = stack_digits_led_left(div(capped, 10), rem(capped, 10))
    shift_up_one_row(score_map)
  end

  defp shift_up_one_row(score_map) do
    for {row, value} <- score_map, into: %{} do
      {row, value >>> 1}
    end
  end

  defp overlay_score(menu, score_map) do
    for row <- 1..8, into: %{} do
      {row, Map.get(menu, row, 0) ||| Map.get(score_map, row, 0)}
    end
  end

  defp select_game_frame(times, slot) do
    rem(div(times, 8), select_game_steps(slot)) * 8
  end

  defp select_game_steps(:snake), do: div(map_size(@select_game_snake), 8)
  defp select_game_steps(:breaker), do: div(map_size(@select_game_breaker), 8)
  defp select_game_steps(:flappy), do: div(map_size(@select_game_flappy), 8)

  defp high_score_for(slot) do
    SnakeBlockbreakerClock.NVS.high_score(slot)
  end

  defp select_menu_matrix(times, slot) do
    active_row =
      case slot do
        :breaker -> 4
        :flappy -> 7
        _ -> 1
      end

    menu =
      @empty_matrix
      |> Map.put(1, 0b10000000)
      |> Map.put(4, 0b10000000)
      |> Map.put(7, 0b10000000)

    if rem(times, 4) < 2 do
      menu
    else
      Map.put(menu, active_row, 0)
    end
  end

  defp setup_adc() do
    :ok = :esp_adc.start(@gpio_vrx)
    :ok = :esp_adc.start(@gpio_vry)
    {@gpio_vrx, @gpio_vry}
  end

  defp read_adc(adc) do
    case :esp_adc.read(adc) do
      {:ok, {raw, _milli_volts}} -> {:ok, raw}
      error -> :io.format("Error taking reading: ~p~n", [error])
    end
  end

  defp init_max7219(spi_settings) do
    spi = :spi.open(spi_settings)
    write_register(spi, @decode_mode, 0x0, :device_1)
    write_register(spi, @intensity, 0x0, :device_1)
    write_register(spi, @scan_limit, 0x7, :device_1)
    write_register(spi, @shutdown, 0x1, :device_1)
    write_register(spi, @display_test, 0x0, :device_1)

    write_register(spi, @decode_mode, 0x0, :device_2)
    write_register(spi, @intensity, 0x0, :device_2)
    write_register(spi, @scan_limit, 0x7, :device_2)
    write_register(spi, @shutdown, 0x1, :device_2)
    write_register(spi, @display_test, 0x0, :device_2)
    {:ok, spi}
  end

  defp get_data(result, 9, _times, _command) do
    result
  end

  defp get_data(result, number, times, :snake) do
    row = Map.get(@select_game_snake, number + times)
    new_result = Map.put(result, number, row)
    get_data(new_result, number + 1, times, :snake)
  end

  defp get_data(result, number, times, :breaker) do
    row = Map.get(@select_game_breaker, number + times)
    new_result = Map.put(result, number, row)
    get_data(new_result, number + 1, times, :breaker)
  end

  defp get_data(result, number, times, :flappy) do
    row = Map.get(@select_game_flappy, number + times)
    new_result = Map.put(result, number, row)
    get_data(new_result, number + 1, times, :flappy)
  end

  defp write_digit(spi, 8, data, device) do
    reg_data = Map.get(data, 8)
    write_register(spi, 8, reg_data, device)
    :ok
  end

  defp write_digit(spi, number, data, device) do
    reg_data = Map.get(data, number)
    write_register(spi, number, reg_data, device)
    write_digit(spi, number + 1, data, device)
  end

  defp write_register(spi, address, data, device) do
    :spi.write_at(spi, device, address, @num_of_bits, data)
  end

  # ==================== clock ====================

  defp wait_for_sntp(0) do
    epoch_ms = :erlang.system_time(:millisecond)
    IO.puts("sntp: timeout, epoch=#{epoch_ms}")
  end

  defp wait_for_sntp(retries) do
    epoch_ms = :erlang.system_time(:millisecond)

    if epoch_ms > 1_600_000_000_000 do
      IO.puts("sntp: time is valid (epoch=#{epoch_ms})")
    else
      IO.puts("sntp: waiting for sync... retries=#{retries} epoch=#{epoch_ms}")
      Process.sleep(1000)
      wait_for_sntp(retries - 1)
    end
  end

  defp show_clock(pid) do
    spi = GenServer.call(pid, :get_spi)

    clock_loop(
      spi,
      @empty_matrix,
      @empty_matrix,
      0,
      @empty_matrix,
      @empty_matrix,
      0,
      0,
      0,
      nil,
      nil,
      0
    )
  end

  def display_clock(parent_pid, spi) do
    GPIO.set_pin_mode(@gpio_sw, :input)
    GPIO.set_pin_pull(@gpio_sw, :up)
    :esp_adc.start(@gpio_vrx)
    :esp_adc.start(@gpio_vry)

    clock_loop(
      spi,
      @empty_matrix,
      @empty_matrix,
      0,
      @empty_matrix,
      @empty_matrix,
      0,
      0,
      0,
      nil,
      nil,
      0
    )

    clear_display(spi)
    send(parent_pid, {:clock_done})
  end

  defp date_display do
    epoch_ms = :erlang.system_time(:millisecond)
    local_ms = epoch_ms + @timezone_offset_ms

    {{_year, month, day}, {_hour, _minute, _second}} =
      :calendar.system_time_to_universal_time(local_ms, :millisecond)

    date_left = stack_digits_led_left(div(day, 10), rem(day, 10))
    date_right = stack_digits_led_right(div(month, 10), rem(month, 10))
    {date_left, date_right}
  end

  defp lunar_date_display do
    epoch_ms = :erlang.system_time(:millisecond)
    local_ms = epoch_ms + @timezone_offset_ms

    {{year, month, day}, {_hour, _minute, _second}} =
      :calendar.system_time_to_universal_time(local_ms, :millisecond)

    {lunar_day, lunar_month, _lunar_year, _is_leap} =
      SnakeBlockbreakerClock.LunarDate.convert_solar_to_lunar(day, month, year)

    lunar_left = stack_digits_led_left(div(lunar_day, 10), rem(lunar_day, 10))
    lunar_right = stack_digits_led_right(div(lunar_month, 10), rem(lunar_month, 10))
    {lunar_left, lunar_right}
  end

  defp start_animation(pid) do
    GenServer.cast(pid, {:set_slot, :snake})
    new_proc = spawn(__MODULE__, :display_select_game, [pid, 0])
    GenServer.cast(pid, {:set_goverproc, new_proc})
  end

  defp clock_loop(
         spi,
         prev_left,
         prev_right,
         tick,
         disp_left,
         disp_right,
         shift_x,
         shift_y,
         blink_count,
         message_offset,
         message_step,
         date_mode
       ) do
    receive do
      :stop -> :ok
    after
      0 ->
        if button_pressed?() do
          IO.puts("clock: button pressed, exiting clock mode")
          :ok
        else
          {time_left, time_right, new_tick} =
            if tick == 0 do
              epoch_ms = :erlang.system_time(:millisecond)
              local_ms = epoch_ms + @timezone_offset_ms

              {{_year, _month, _day}, {hour, minute, _second}} =
                :calendar.system_time_to_universal_time(local_ms, :millisecond)

              hour_tens = div(hour, 10)
              hour_ones = rem(hour, 10)
              mins_tens = div(minute, 10)
              mins_ones = rem(minute, 10)

              new_left = stack_digits_led_left(hour_tens, hour_ones)
              new_right = stack_digits_led_right(mins_tens, mins_ones)

              if date_mode == 0 do
if new_left != prev_left do
                apply_effect(spi, prev_left, new_left, :device_1, clock_effect(prev_left, hour))
              end

              if new_right != prev_right do
                apply_effect(spi, prev_right, new_right, :device_2, clock_effect(prev_right, minute))
              end
              end

              if new_left != prev_left or new_right != prev_right do
                IO.puts("Clock: #{pad(hour)}:#{pad(minute)}")
              end
              {new_left, new_right, 19}
            else
              {prev_left, prev_right, tick - 1}
            end

          {new_shift_x, new_shift_y} = read_joystick_shifts(shift_x, shift_y)

          fresh_press = (shift_x == 0 and shift_y == 0) and (new_shift_x != 0 or new_shift_y != 0)

          {new_message_offset, new_message_step} =
            cond do
              fresh_press and new_shift_x < 0 and new_shift_y == 0 -> {0, 2}
              fresh_press and new_shift_x > 0 and new_shift_y == 0 -> {0, 2}
              fresh_press -> {nil, nil}
              is_integer(message_offset) and
                  message_offset < clock_message_end_offset(message_step) ->
                {message_offset + message_speed(message_step, message_offset), message_step}

              is_integer(message_offset) -> {nil, nil}
              true -> {nil, nil}
            end

          new_date_mode =
            if is_nil(new_message_offset) and is_nil(new_message_step) do
              if shift_y == 0 and new_shift_y < 0 do
                IO.puts("clock: joystick UP -> toggle solar date #{date_mode}")
                if date_mode == 0, do: 1, else: 0
              else
                if shift_y == 0 and new_shift_y > 0 do
                  IO.puts("clock: joystick DOWN -> toggle lunar date #{date_mode}")
                  if date_mode == 0, do: 2, else: 0
                else
                  date_mode
                end
              end
            else
              date_mode
            end

          if fresh_press and new_shift_x > 0 and new_shift_y == 0 do
            IO.puts("clock: joystick RIGHT -> show creator")
          end

          if fresh_press and new_shift_x < 0 and new_shift_y == 0 do
            IO.puts("clock: joystick LEFT -> show creator")
          end

          if is_nil(message_offset) and is_integer(new_message_offset) do
            case new_message_step do
              1 -> IO.puts("clock: message start: clock (forward)")
              2 -> IO.puts("clock: message start: creator (forward)")
              _ -> :ok
            end
          end

          if is_integer(message_offset) and is_nil(new_message_offset) do
            IO.puts("clock: message stopped")
          end

          {new_disp_left, new_disp_right} =
            if is_integer(new_message_offset) do
              clock_message_frame(new_message_offset, new_message_step)
            else
              case new_date_mode do
                1 -> date_display()
                2 -> lunar_date_display()
                _ -> {time_left, time_right}
              end
            end

          blink_bit = 0b00000001
          blink_on? = rem(blink_count, 10) < 5

          row8 =
            if new_message_step == 2 or new_date_mode != 0 do
              Map.get(new_disp_left, 8, 0)
            else
              (Map.get(new_disp_left, 8, 0) &&& ~~~blink_bit) |||
                if blink_on?, do: blink_bit, else: 0
            end

          new_disp_left = Map.put(new_disp_left, 8, row8)

          row1 =
            if new_message_step == 2 or new_date_mode != 0 do
              Map.get(new_disp_right, 1, 0)
            else
              (Map.get(new_disp_right, 1, 0) &&& ~~~blink_bit) |||
                if blink_on?, do: blink_bit, else: 0
            end

          new_disp_right = Map.put(new_disp_right, 1, row1)

          if new_disp_left != disp_left or new_disp_right != disp_right do
            write_digit(spi, @digit_0, new_disp_left, :device_1)
            write_digit(spi, @digit_0, new_disp_right, :device_2)
          end

          Process.sleep(50)

          clock_loop(
            spi,
            time_left,
            time_right,
            new_tick,
            new_disp_left,
            new_disp_right,
            new_shift_x,
            new_shift_y,
            blink_count + 1,
            new_message_offset,
            new_message_step,
            new_date_mode
          )
        end
    end
  end

  defp clock_message_frame(offset, message_step) do
    data1 = clock_message_data(@empty_matrix, 1, offset, message_step)
    data2 = clock_message_data(@empty_matrix, 1, offset + 8, message_step)
    {data1, data2}
  end

  defp clock_message_end_offset(2), do: @creator_message_end_offset
  defp clock_message_end_offset(_), do: @clock_message_end_offset

  defp message_speed(2, offset) do
    case rem(offset, 4) do
      0 -> 2
      _ -> 1
    end
  end

  defp message_speed(_step, _offset), do: 1

  defp clock_message_data(result, 9, _offset, _message_step), do: result

  defp clock_message_data(result, row, offset, message_step) do
    value = message_column(row + offset, message_step)
    clock_message_data(Map.put(result, row, value), row + 1, offset, message_step)
  end

  defp message_column(index, 2) when index <= 120 do
    creator_index = index - 1
    character = Enum.at(@creator_text, div(creator_index, 6))
    glyph = Map.get(@creator_font, character, [0, 0, 0, 0, 0])
    glyph_column = Enum.at(glyph, rem(creator_index, 6), 0)
    compress_creator_column(glyph_column)
  end

  defp message_column(index, _message_step), do: Map.get(@clock_message, index, 0)

  defp compress_creator_column(column) do
    top = (((column >>> 6) &&& 1) ||| ((column >>> 5) &&& 1)) <<< 5
    upper = ((column >>> 4) &&& 1) <<< 4
    middle = ((column >>> 3) &&& 1) <<< 3
    lower = ((column >>> 2) &&& 1) <<< 2
    bottom = (((column >>> 1) &&& 1) ||| (column &&& 1)) <<< 1
    top ||| upper ||| middle ||| lower ||| bottom
  end

  defp read_joystick_shifts(shift_x, shift_y) do
    {:ok, x} =
      case :esp_adc.read(@gpio_vrx) do
        {:ok, {raw, _}} -> {:ok, raw}
        other -> other
      end

    {:ok, y} =
      case :esp_adc.read(@gpio_vry) do
        {:ok, {raw, _}} -> {:ok, raw}
        other -> other
      end

    x_dev = abs(x - 2048)
    y_dev = abs(y - 2048)
    min_dev = 200

    cond do
      x_dev > y_dev and x_dev > min_dev and x < @low_range -> {shift_x - 1, 0}
      x_dev > y_dev and x_dev > min_dev and x > @high_range -> {shift_x + 1, 0}
      y_dev > x_dev and y_dev > min_dev and y < @low_range -> {shift_x - 1, 1}
      y_dev > x_dev and y_dev > min_dev and y > @high_range -> {0, shift_y - 1}
      true -> {0, 0}
    end
  end

  defp button_pressed? do
    GPIO.digital_read(@gpio_sw) == :low
  rescue
    _ -> false
  end

  defp clear_display(spi) do
    write_digit(spi, @digit_0, @empty_matrix, :device_1)
    write_digit(spi, @digit_0, @empty_matrix, :device_2)
  end

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: Integer.to_string(n)

  defp clock_effect(@empty_matrix, _n), do: 2
  defp clock_effect(_prev, n), do: rem(n, 3)

  defp stack_digits_led_right(top, bot) do
    top_map = Map.get(@digit_left, top, @digit_left[0])
    bot_map = Map.get(@digit_right, bot, @digit_right[0])

    for row <- 1..8, into: %{} do
      t = Map.get(top_map, row - 1, 0)
      b = Map.get(bot_map, row, 0)
      {row, t ||| b}
    end
  end

  defp stack_digits_led_left(top, bot) do
    top_map = Map.get(@digit_left, top, @digit_left[0])
    bot_map = Map.get(@digit_right, bot, @digit_right[0])

    for row <- 1..8, into: %{} do
      t = Map.get(top_map, row, 0)
      b = Map.get(bot_map, row + 1, 0)
      {row, t ||| b}
    end
  end

  defp apply_effect(spi, old, new, device, 0) do
    IO.puts("effect: rain_v (#{device})")
    effect_rain(spi, old, new, device)
  end

  defp apply_effect(spi, old, new, device, 1) do
    IO.puts("effect: rain_h (#{device})")
    effect_rain_h(spi, old, new, device)
  end

  defp apply_effect(spi, old, new, device, 2) do
    IO.puts("effect: scroll_up (#{device})")
    effect_scroll_up(spi, old, new, device)
  end

  # rain_v effect
  defp effect_rain(spi, _old, new, device) do
    write_digit(spi, @digit_0, @empty_matrix, device)
    Process.sleep(12)
    effect_rain_cols(spi, new, 0, @empty_matrix, device)
    write_digit(spi, @digit_0, new, device)
  end

  defp effect_rain_cols(_spi, _new, 8, cur, _device), do: cur

  defp effect_rain_cols(spi, new, col, cur, device) do
    cur = effect_rain_fall(spi, col, 1, cur, device)
    cur = effect_rain_lock(spi, new, col, cur, device)
    effect_rain_cols(spi, new, col + 1, cur, device)
  end

  defp effect_rain_fall(_spi, _col, 9, cur, _device), do: cur

  defp effect_rain_fall(spi, col, row, cur, device) do
    checker = if rem(row, 2) == 0, do: 0b10101010, else: 0b01010101

    frame =
      for r <- 1..8, into: %{} do
        if r == row do
          {r, Map.get(cur, r, 0) ||| checker}
        else
          {r, Map.get(cur, r, 0)}
        end
      end

    write_digit(spi, @digit_0, frame, device)
    Process.sleep(8)
    effect_rain_fall(spi, col, row + 1, cur, device)
  end

  defp effect_rain_lock(spi, new, col, cur, device) do
    mask = 1 <<< (7 - col)

    cur =
      for r <- 1..8, into: %{} do
        existing = Map.get(cur, r, 0)
        new_bit = Map.get(new, r, 0) &&& mask
        {r, (existing &&& (~~~mask &&& 0xFF)) ||| new_bit}
      end

    write_digit(spi, @digit_0, cur, device)
    Process.sleep(8)
    cur
  end

  # rain_h effect
  defp effect_rain_h(spi, _old, new, device) do
    write_digit(spi, @digit_0, @empty_matrix, device)
    Process.sleep(12)
    effect_rain_rows(spi, new, 1, @empty_matrix, device)
    write_digit(spi, @digit_0, new, device)
  end

  defp effect_rain_rows(_spi, _new, 9, cur, _device), do: cur

  defp effect_rain_rows(spi, new, row, cur, device) do
    cur = effect_rain_flow(spi, row, 0, cur, device)
    cur = effect_rain_lock_row(spi, new, row, cur, device)
    effect_rain_rows(spi, new, row + 1, cur, device)
  end

  defp effect_rain_flow(_spi, _row, 8, cur, _device), do: cur

  defp effect_rain_flow(spi, row, col, cur, device) do
    mask = 1 <<< (7 - col)

    frame =
      for r <- 1..8, into: %{} do
        if r == row do
          {r, mask}
        else
          {r, Map.get(cur, r, 0)}
        end
      end

    write_digit(spi, @digit_0, frame, device)
    Process.sleep(8)
    effect_rain_flow(spi, row, col + 1, cur, device)
  end

  defp effect_rain_lock_row(spi, new, row, cur, device) do
    new_row = Map.get(new, row, 0)
    cur = %{cur | row => new_row}
    write_digit(spi, @digit_0, cur, device)
    Process.sleep(8)
    cur
  end

  # scroll_up effect
  defp effect_scroll_up(spi, old, new, device) do
    for step <- 0..7 do
      frame =
        for row <- 1..8, into: %{} do
          src = row + step

          if src <= 8 do
            {row, Map.get(old, src, 0)}
          else
            {row, Map.get(new, src - 8, 0)}
          end
        end

      write_digit(spi, @digit_0, frame, device)
      Process.sleep(20)
    end

    write_digit(spi, @digit_0, new, device)
  end
end
