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

defmodule BlockBreaker2Led do
  use GenServer
  import Bitwise

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
  @gpio_sw 32
  @gpio_resistor 33

  @low_range 800
  @high_range 3000
  @delay_read_adc 100
  @max_speed 100
  @min_speed 1000
  @bit_resolution 4095

  @num_of_bits 8
  @device_name :device_1
  @led0 0
  @led1 1

  @max_point 32

  @ball %{0 => {0, {7, 1}}}

  @cross_bar %{
    0 => {0, {6, 0}},
    1 => {0, {7, 0}},
    2 => {1, {0, 0}}
  }

  @default_point %{
    0 => {0, {0, 7}},
    1 => {0, {1, 7}},
    2 => {0, {2, 7}},
    3 => {0, {3, 7}},
    4 => {0, {4, 7}},
    5 => {0, {5, 7}},
    6 => {0, {6, 7}},
    7 => {0, {7, 7}},
    8 => {0, {0, 6}},
    9 => {0, {1, 6}},
    10 => {0, {2, 6}},
    11 => {0, {3, 6}},
    12 => {0, {4, 6}},
    13 => {0, {5, 6}},
    14 => {0, {6, 6}},
    15 => {0, {7, 6}},
    16 => {1, {0, 7}},
    17 => {1, {1, 7}},
    18 => {1, {2, 7}},
    19 => {1, {3, 7}},
    20 => {1, {4, 7}},
    21 => {1, {5, 7}},
    22 => {1, {6, 7}},
    23 => {1, {7, 7}},
    24 => {1, {0, 6}},
    25 => {1, {1, 6}},
    26 => {1, {2, 6}},
    27 => {1, {3, 6}},
    28 => {1, {4, 6}},
    29 => {1, {5, 6}},
    30 => {1, {6, 6}},
    31 => {1, {7, 6}}
  }

  defstruct [
    :spi,
    :crossbar,
    :ball,
    :direction,
    :point,
    :data1,
    :data2,
    :isgameover,
    :goverproc,
    :score,
    :joystick_pid
  ]

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

  @default_matrix %{
    @digit_0 => 0b11100000,
    @digit_1 => 0b11100000,
    @digit_2 => 0b11100000,
    @digit_3 => 0b11100000,
    @digit_4 => 0b11100000,
    @digit_5 => 0b11100000,
    @digit_6 => 0b11100000,
    @digit_7 => 0b11100000
  }

  @number_0_left %{
    @digit_0 => 0b00111100,
    @digit_1 => 0b01000010,
    @digit_2 => 0b01000010,
    @digit_3 => 0b00111100,
    @digit_4 => 0b00000000,
    @digit_5 => 0b00000000,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_1_left %{
    @digit_0 => 0b01000100,
    @digit_1 => 0b01111110,
    @digit_2 => 0b01000000,
    @digit_3 => 0b00000000,
    @digit_4 => 0b00000000,
    @digit_5 => 0b00000000,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_2_left %{
    @digit_0 => 0b01000100,
    @digit_1 => 0b01100010,
    @digit_2 => 0b01010010,
    @digit_3 => 0b01001100,
    @digit_4 => 0b00000000,
    @digit_5 => 0b00000000,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_3_left %{
    @digit_0 => 0b01000010,
    @digit_1 => 0b01001010,
    @digit_2 => 0b01111110,
    @digit_3 => 0b00000000,
    @digit_4 => 0b00000000,
    @digit_5 => 0b00000000,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_4_left %{
    @digit_0 => 0b00010000,
    @digit_1 => 0b00011000,
    @digit_2 => 0b00010100,
    @digit_3 => 0b01111110,
    @digit_4 => 0b00000000,
    @digit_5 => 0b00000000,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_5_left %{
    @digit_0 => 0b01001110,
    @digit_1 => 0b01001010,
    @digit_2 => 0b01001010,
    @digit_3 => 0b01111010,
    @digit_4 => 0b00000000,
    @digit_5 => 0b00000000,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_6_left %{
    @digit_0 => 0b01111110,
    @digit_1 => 0b01001010,
    @digit_2 => 0b01001010,
    @digit_3 => 0b01111010,
    @digit_4 => 0b00000000,
    @digit_5 => 0b00000000,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_7_left %{
    @digit_0 => 0b01000010,
    @digit_1 => 0b00100010,
    @digit_2 => 0b00010010,
    @digit_3 => 0b00001110,
    @digit_4 => 0b00000000,
    @digit_5 => 0b00000000,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_8_left %{
    @digit_0 => 0b01111110,
    @digit_1 => 0b01001010,
    @digit_2 => 0b01001010,
    @digit_3 => 0b01111110,
    @digit_4 => 0b00000000,
    @digit_5 => 0b00000000,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_9_left %{
    @digit_0 => 0b01001110,
    @digit_1 => 0b01001010,
    @digit_2 => 0b01001010,
    @digit_3 => 0b01111110,
    @digit_4 => 0b00000000,
    @digit_5 => 0b00000000,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_0_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000000,
    @digit_3 => 0b00000000,
    @digit_4 => 0b00111100,
    @digit_5 => 0b01000010,
    @digit_6 => 0b01000010,
    @digit_7 => 0b00111100
  }

  @number_1_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000000,
    @digit_3 => 0b00000000,
    @digit_4 => 0b00000000,
    @digit_5 => 0b01000100,
    @digit_6 => 0b01111110,
    @digit_7 => 0b01000000
  }

  @number_2_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000000,
    @digit_3 => 0b00000000,
    @digit_4 => 0b01000100,
    @digit_5 => 0b01100010,
    @digit_6 => 0b01010010,
    @digit_7 => 0b01001100
  }

  @number_3_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000000,
    @digit_3 => 0b00000000,
    @digit_4 => 0b00000000,
    @digit_5 => 0b01000010,
    @digit_6 => 0b01001010,
    @digit_7 => 0b01111110
  }

  @number_4_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000000,
    @digit_3 => 0b00000000,
    @digit_4 => 0b00010000,
    @digit_5 => 0b00011000,
    @digit_6 => 0b00010100,
    @digit_7 => 0b01111110
  }

  @number_5_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000000,
    @digit_3 => 0b00000000,
    @digit_4 => 0b01001110,
    @digit_5 => 0b01001010,
    @digit_6 => 0b01001010,
    @digit_7 => 0b01111010
  }

  @number_6_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000000,
    @digit_3 => 0b00000000,
    @digit_4 => 0b01111110,
    @digit_5 => 0b01001010,
    @digit_6 => 0b01001010,
    @digit_7 => 0b01111010
  }

  @number_7_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000000,
    @digit_3 => 0b00000000,
    @digit_4 => 0b01000010,
    @digit_5 => 0b00100010,
    @digit_6 => 0b00010010,
    @digit_7 => 0b00001110
  }

  @number_8_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000000,
    @digit_3 => 0b00000000,
    @digit_4 => 0b01111110,
    @digit_5 => 0b01001010,
    @digit_6 => 0b01001010,
    @digit_7 => 0b01111110
  }

  @number_9_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000000,
    @digit_3 => 0b00000000,
    @digit_4 => 0b01001110,
    @digit_5 => 0b01001010,
    @digit_6 => 0b01001010,
    @digit_7 => 0b01111110
  }

  @number_0 %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00111100,
    @digit_3 => 0b01000010,
    @digit_4 => 0b01000010,
    @digit_5 => 0b00111100,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_1 %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b01000000,
    @digit_3 => 0b01000010,
    @digit_4 => 0b01111110,
    @digit_5 => 0b01000000,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_2 %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b01000100,
    @digit_3 => 0b01100010,
    @digit_4 => 0b01010010,
    @digit_5 => 0b01001100,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_3 %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00100100,
    @digit_3 => 0b01000010,
    @digit_4 => 0b01011010,
    @digit_5 => 0b00100100,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_4 %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00011000,
    @digit_3 => 0b00010100,
    @digit_4 => 0b01111110,
    @digit_5 => 0b00010000,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_5 %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b01001110,
    @digit_3 => 0b01001010,
    @digit_4 => 0b01001010,
    @digit_5 => 0b01111010,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_6 %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b01111110,
    @digit_3 => 0b01001010,
    @digit_4 => 0b01001010,
    @digit_5 => 0b01111010,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_7 %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b01000010,
    @digit_3 => 0b00100010,
    @digit_4 => 0b00010010,
    @digit_5 => 0b00001110,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_8 %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00110100,
    @digit_3 => 0b01001010,
    @digit_4 => 0b01001010,
    @digit_5 => 0b00110100,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @number_9 %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b01001110,
    @digit_3 => 0b01001010,
    @digit_4 => 0b01001010,
    @digit_5 => 0b01111110,
    @digit_6 => 0b00000000,
    @digit_7 => 0b00000000
  }

  @game_over %{
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
    18 => 0b00111100,
    19 => 0b01000010,
    20 => 0b01001010,
    21 => 0b00111010,
    22 => 0b00001000,
    23 => 0b00000000,
    24 => 0b01111100,
    25 => 0b00001010,
    26 => 0b00001010,
    27 => 0b01111100,
    28 => 0b00000000,
    29 => 0b01111110,
    30 => 0b00000100,
    31 => 0b00001000,
    32 => 0b00000100,
    33 => 0b01111110,
    34 => 0b00000000,
    35 => 0b01111110,
    36 => 0b01001010,
    37 => 0b01001010,
    38 => 0b01000010,
    39 => 0b00000000,
    40 => 0b00000000,
    41 => 0b00000000,
    42 => 0b00111100,
    43 => 0b01000010,
    44 => 0b01000010,
    45 => 0b00111100,
    46 => 0b00000000,
    47 => 0b00011110,
    48 => 0b00100000,
    49 => 0b01000000,
    50 => 0b00100000,
    51 => 0b00011110,
    52 => 0b00000000,
    53 => 0b01111110,
    54 => 0b01001010,
    55 => 0b01001010,
    56 => 0b01000010,
    57 => 0b00000000,
    58 => 0b01111110,
    59 => 0b00001010,
    60 => 0b00001010,
    61 => 0b01110110,
    62 => 0b00000000,
    63 => 0b00000000,
    64 => 0b00000000,
    65 => 0b00000000,
    66 => 0b00000000,
    67 => 0b00000000,
    68 => 0b00000000,
    69 => 0b00000000,
    70 => 0b00000000,
    71 => 0b00000000,
    72 => 0b00000000,
    73 => 0b00000000,
    74 => 0b00000000,
    75 => 0b00000000,
    76 => 0b00000000,
    77 => 0b00000000,
    78 => 0b00000000
  }

  @breaker_game %{
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
    19 => 0b01001010,
    20 => 0b01001010,
    21 => 0b00110100,
    22 => 0b00000000,
    23 => 0b01111110,
    24 => 0b00001010,
    25 => 0b00001010,
    26 => 0b01110110,
    27 => 0b00000000,
    28 => 0b01111110,
    29 => 0b01001010,
    30 => 0b01001010,
    31 => 0b01000010,
    32 => 0b00000000,
    33 => 0b01111100,
    34 => 0b00001010,
    35 => 0b00001010,
    36 => 0b01111100,
    37 => 0b00000000,
    38 => 0b01111110,
    39 => 0b00001000,
    40 => 0b00010100,
    41 => 0b01100010,
    42 => 0b00000000,
    43 => 0b01111110,
    44 => 0b01001010,
    45 => 0b01001010,
    46 => 0b01000010,
    47 => 0b00000000,
    48 => 0b01111110,
    49 => 0b00001010,
    50 => 0b00001010,
    51 => 0b01110110,
    52 => 0b00000000,
    53 => 0b00000000,
    54 => 0b00000000,
    55 => 0b00111100,
    56 => 0b01000010,
    57 => 0b01001010,
    58 => 0b00111010,
    59 => 0b00001000,
    60 => 0b00000000,
    61 => 0b01111100,
    62 => 0b00001010,
    63 => 0b00001010,
    64 => 0b01111100,
    65 => 0b00000000,
    66 => 0b01111110,
    67 => 0b00000100,
    68 => 0b00001000,
    69 => 0b00000100,
    70 => 0b01111110,
    71 => 0b00000000,
    72 => 0b01111110,
    73 => 0b01001010,
    74 => 0b01001010,
    75 => 0b01000010,
    76 => 0b00000000,
    77 => 0b00000000,
    78 => 0b00000000,
    79 => 0b00000000,
    80 => 0b00000000,
    81 => 0b00000000,
    82 => 0b00000000,
    83 => 0b00000000,
    84 => 0b00000000,
    85 => 0b00000000,
    86 => 0b00000000,
    87 => 0b00000000,
    88 => 0b00000000,
    89 => 0b00000000,
    90 => 0b00000000,
    91 => 0b00000000,
    92 => 0b00000000
  }

  @game_win %{
    1 => 0b00111100,
    2 => 0b01000010,
    3 => 0b01001010,
    4 => 0b00111010,
    5 => 0b00001000,
    6 => 0b00000000,
    7 => 0b01111100,
    8 => 0b00001010,
    9 => 0b00001010,
    10 => 0b01111100,
    11 => 0b00000000,
    12 => 0b01111110,
    13 => 0b00000100,
    14 => 0b00001000,
    15 => 0b00000100,
    16 => 0b01111110,
    17 => 0b00000000,
    18 => 0b01111110,
    19 => 0b01001010,
    20 => 0b01001010,
    21 => 0b01000010,
    22 => 0b00000000,
    23 => 0b00000000,
    24 => 0b01111110,
    25 => 0b00100000,
    26 => 0b00010000,
    27 => 0b00100000,
    28 => 0b01111110,
    29 => 0b00000000,
    30 => 0b01000010,
    31 => 0b01000010,
    32 => 0b01111110,
    33 => 0b01000010,
    34 => 0b01000010,
    35 => 0b00000000,
    36 => 0b01111110,
    37 => 0b00000100,
    38 => 0b00001000,
    39 => 0b00010000,
    40 => 0b00100000,
    41 => 0b01111110,
    42 => 0b00000000
  }

  def start(spi) do
    :erlang.system_flag(:schedulers_online, 2)
    {:ok, pid} = GenServer.start(__MODULE__, spi)
    :timer.sleep(500)
    joystick_pid = spawn(__MODULE__, :joystick, [pid, @gpio_vrx, @gpio_vry])
    GenServer.cast(pid, {:update_joystick_pid, joystick_pid})
    ball(pid, 150)
  end

  def init(spi) do
    init_sw_interrupt()
    new_proc = spawn(__MODULE__, :welcome_block_breaker_game_process, [self(), 0])
    state = %__MODULE__{spi: spi, goverproc: new_proc, isgameover: true}
    :io.format("Init SPI and MAX7219 OK ~p ~n", [@cross_bar])
    {:ok, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:update_joystick_pid, pid}, state) do
    {:noreply, %{state | joystick_pid: pid}}
  end

  def handle_cast(:update_game, state) do
    {temp1, temp2} = update_data(state.crossbar, {state.data1, state.data2}, 0, 3)
    {temp3, temp4} = update_data(state.ball, {temp1, temp2}, 0, 1)
    {temp5, temp6} = update_data(state.point, {temp3, temp4}, 0, @max_point)
    write_digit(state.spi, @digit_0, temp5, :device_1)
    write_digit(state.spi, @digit_0, temp6, :device_2)
    new_state = %{state | data1: temp5, data2: temp6}
    {:noreply, new_state}
  end

  def handle_cast(:reset_game, state) do
    new_state = %{state |
      crossbar: @cross_bar,
      data1: @empty_matrix,
      data2: @empty_matrix,
      score: 0,
      goverproc: nil,
      point: @default_point,
      ball: @ball,
      direction: {-1, 1},
      isgameover: false
    }
    {:noreply, new_state}
  end

  def handle_cast({:move_cross_bar, direc}, state) do
    if state.isgameover do
      {:noreply, state}
    else
      {new_cross_bar, flag} = update_cross_bar(state.crossbar, direc)
      if flag do
        temp1 = remove_current_crossbar(state.data1, 1)
        temp2 = remove_current_crossbar(state.data2, 1)
        {data1, data2} = update_data(new_cross_bar, {temp1, temp2}, 0, 3)
        write_digit(state.spi, @digit_0, data1, :device_1)
        write_digit(state.spi, @digit_0, data2, :device_2)
        new_state = %{state | data1: data1, data2: data2, crossbar: new_cross_bar}
        {:noreply, new_state}
      else
        {:noreply, state}
      end
    end
  end

  def handle_cast(:move_ball, state) do
    if state.isgameover do
      {:noreply, state}
    else
      ball = Map.get(state.ball, 0)
      {new_ball, new_direc, game_over, new_point, new_score} =
        move_ball(ball, state.direction, state.crossbar, state.point, state.score)
      new_state =
        if game_over do
          IO.puts("GAME OVER")
          send(self(), :stop_peripherals)
          :timer.sleep(500)
          {data1, data2} = handle_game_over(state.score)
          write_digit(state.spi, @digit_0, data1, :device_1)
          write_digit(state.spi, @digit_0, data2, :device_2)
          :timer.sleep(2000)
          new_proc = spawn(__MODULE__, :game_over_process, [self(), 0, 0])
          %{state | isgameover: true, goverproc: new_proc}
        else
          if new_score == @max_point do
            IO.puts("GAME WIN")
            send(self(), :stop_peripherals)
            :timer.sleep(500)
            {data1, data2} = handle_game_over(new_score)
            write_digit(state.spi, @digit_0, data1, :device_1)
            write_digit(state.spi, @digit_0, data2, :device_2)
            :timer.sleep(2000)
            new_proc = spawn(__MODULE__, :game_win_process, [self(), 0])
            %{state | isgameover: true, goverproc: new_proc}
          else
            {data1, data2} = update_ball(new_ball, ball, state.data1, state.data2)
            write_digit(state.spi, @digit_0, data1, :device_1)
            write_digit(state.spi, @digit_0, data2, :device_2)
            %{state | ball: %{0 => new_ball}, data1: data1, data2: data2, direction: new_direc, point: new_point, score: new_score}
          end
        end
      {:noreply, new_state}
    end
  end

  def handle_cast({:display_game_win, times}, state) do
    display_game_text(state.spi, times, :win)
    {:noreply, state}
  end

  def handle_cast({:display_game_over, times}, state) do
    display_game_text(state.spi, times, :lose)
    {:noreply, state}
  end

  def handle_cast({:display_breaker_game, times}, state) do
    display_game_text(state.spi, times, :welcome)
    {:noreply, state}
  end

  def handle_info({:gpio_interrupt, @gpio_sw}, state) do
    IO.puts("receive interrupt")
    if is_pid(state.goverproc) do
      send(state.goverproc, :stop)
    end
    GenServer.cast(self(), :reset_game)
    GenServer.cast(self(), :update_game)
    {:noreply, state}
  end

  def handle_info(:stop_peripherals, state) do
    GPIO.stop()
    if is_pid(state.joystick_pid) do
      send(state.joystick_pid, :stop)
    end
    {:noreply, state}
  end

  def handle_info(:back_to_welcome, state) do
    IO.puts("receive back_to_welcome")
    if is_pid(state.goverproc) do
      send(state.goverproc, :stop)
    end
    GenServer.cast(:snake_blockbreaker, :game_over)
    {:stop, :normal, state}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp update_data(_map, data, len, len) do
    data
  end

  defp update_data(map, data, number, len) do
    {id, element} = Map.get(map, number)
    device = get_device(id)
    previous_data = get_data(device, data)
    new_data =
      if element != {-1, -1} do
        write_element(element, previous_data)
      else
        previous_data
      end
    return_data = get_return_data(data, new_data, device)
    update_data(map, return_data, number + 1, len)
  end

  defp write_element({x, y}, data) do
    new_x = 128 >>> y
    current_row = Map.get(data, x + 1)
    new_row = new_x ||| current_row
    Map.put(data, x + 1, new_row)
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

  defp get_device(num) do
    case num do
      0 -> :device_1
      1 -> :device_2
    end
  end

  defp get_data(device, {data1, data2}) do
    case device do
      :device_1 -> data1
      :device_2 -> data2
    end
  end

  defp get_return_data({data1, data2}, new_data, device) do
    case device do
      :device_1 -> {new_data, data2}
      :device_2 -> {data1, new_data}
    end
  end

  defp update_cross_bar(cross_bar, direction) do
    {id1, {first, y1}} = Map.get(cross_bar, 0)
    {id2, {middle, y2}} = Map.get(cross_bar, 1)
    {id3, {last, y3}} = Map.get(cross_bar, 2)
    cond1 = first == 0 and direction == -1 and id1 == 0
    cond2 = last == 7 and direction == 1 and id3 == 1
    cond3 = first == 0 and direction == -1 and id1 == 1
    cond4 = last == 7 and direction == 1 and id3 == 0
    cond do
      cond1 or cond2 ->
        {cross_bar, false}
      cond3 ->
        new_cross_bar = %{
          0 => {0, {7, 0}},
          1 => {id1, {first, y1}},
          2 => {id2, {middle, y2}}
        }
        {new_cross_bar, true}
      cond4 ->
        new_cross_bar = %{
          0 => {id2, {middle, y2}},
          1 => {id3, {last, y3}},
          2 => {1, {0, 0}}
        }
        {new_cross_bar, true}
      true ->
        new_cross_bar =
          case direction do
            1 ->
              %{
                0 => {id2, {middle, y2}},
                1 => {id3, {last, y3}},
                2 => {id3, {last + 1, y3}}
              }
            -1 ->
              %{
                0 => {id1, {first - 1, y1}},
                1 => {id1, {first, y1}},
                2 => {id2, {middle, y2}}
              }
            _ ->
              cross_bar
          end
        {new_cross_bar, true}
    end
  end

  defp remove_current_crossbar(map, 9) do
    map
  end

  defp remove_current_crossbar(map, number) do
    element = Map.get(map, number)
    row = element &&& (~~~128)
    new_map = Map.put(map, number, row)
    remove_current_crossbar(new_map, number + 1)
  end

  defp move_ball({id, {x, y}}, {dir_x, dir_y}, cross_bar, point, score) do
    {flag, direction_x, direction_y, x1, y1, temp_id} = is_game_over({id, {x, y}}, {dir_x, dir_y}, cross_bar)
    {is_collision, pos} = is_collision(point, 0, {id, {x1, y1}})
    if is_collision do
      new_x = x1 - direction_x
      new_y = y1 - direction_y
      new_dir_x = 0 - direction_x
      new_dir_y = 0 - direction_y
      new_point = Map.put(point, pos, {-1, -1})
      cond1 = new_x == -1
      cond2 = new_x == 8
      cond do
        cond1 -> {{@led0, {7, new_y}}, {new_dir_x, new_dir_y}, flag, new_point, score + 1}
        cond2 -> {{@led1, {0, new_y}}, {new_dir_x, new_dir_y}, flag, new_point, score + 1}
        true -> {{temp_id, {new_x, new_y}}, {new_dir_x, new_dir_y}, flag, new_point, score + 1}
      end
    else
      cond_x1 = x1 == 7 and id == @led1
      cond_x2 = x1 == 0 and id == @led0
      cond_x3 = x1 == 7 and id == @led0 and direction_x == 1
      cond_x4 = x1 == 0 and id == @led1 and direction_x == -1
      {new_x, new_dir_x, new_id} =
        cond do
          cond_x1 -> {6, -1, temp_id}
          cond_x2 -> {1, 1, temp_id}
          cond_x3 -> {0, direction_x, @led1}
          cond_x4 -> {7, direction_x, @led0}
          true -> {x1 + direction_x, direction_x, temp_id}
        end
      {new_y, new_dir_y} =
        cond do
          y1 == 1 -> {2, 1}
          y1 == 7 -> {6, -1}
          true -> {y1 + direction_y, direction_y}
        end
      {{new_id, {new_x, new_y}}, {new_dir_x, new_dir_y}, flag, point, score}
    end
  end

  defp is_game_over({id, {x, y}}, {dir_x, dir_y}, cross_bar) do
    if y == 1 do
      compare_crossbar({id, {x, y}}, {dir_x, dir_y}, cross_bar)
    else
      {false, dir_x, dir_y, x, y, id}
    end
  end

  defp compare_crossbar(ball, {dir_x, dir_y}, cross_bar) do
    {id, {ball_x, ball_y}} = ball
    temp0 = Map.get(cross_bar, 0)
    temp1 = Map.get(cross_bar, 1)
    temp2 = Map.get(cross_bar, 2)
    ball_1 = {id, {ball_x, ball_y - 1}}
    ball_2 = {id, {ball_x + dir_x, ball_y + dir_y}}
    cond = ball == {@led1, {0, 1}} and temp2 == {@led0, {7, 0}} and {dir_x, dir_y} == {-1, -1}
    cond0 = ball == {@led0, {7, 1}} and temp0 == {@led1, {0, 0}} and {dir_x, dir_y} == {1, -1}
    cond1 = ball_1 == temp1
    cond2 = ball_1 == temp0 or ball_1 == temp2
    cond3 = ball_2 == temp0 or ball_2 == temp2
    cond4 = (ball_y == 1 and ball_x == 0 and {0, {ball_x + 1, ball_y - 1}} == temp0) or
            (ball_y == 1 and ball_x == 7 and {1, {ball_x - 1, ball_y - 1}} == temp2)
    cond do
      cond or cond0 ->
        {false, 0 - dir_x, 0 - dir_y, ball_x - dir_x, ball_y, id}
      cond1 ->
        {false, 0, 1, ball_x, ball_y, id}
      cond2 ->
        {res1, res2} = handle_change_direc(dir_x, dir_y)
        {false, res1, res2, ball_x, ball_y, id}
      cond3 ->
        new_ball_x = ball_x - dir_x
        cond do
          new_ball_x == 8 -> {false, 0 - dir_x, 0 - dir_y, 0, ball_y, @led1}
          new_ball_x == -1 -> {false, 0 - dir_x, 0 - dir_y, 7, ball_y, @led0}
          true -> {false, 0 - dir_x, 0 - dir_y, new_ball_x, ball_y, id}
        end
      cond4 ->
        {false, 0 - dir_x, 0 - dir_y, ball_x, ball_y, id}
      true ->
        {true, dir_x, dir_y, ball_x, ball_y, id}
    end
  end

  defp handle_change_direc(dir_x, dir_y) do
    if dir_x == 0 do
      if :atomvm.random() > 0 do
        {-1, dir_y}
      else
        {1, dir_y}
      end
    else
      {dir_x, dir_y}
    end
  end

  defp is_collision(_point, @max_point, _ball) do
    {false, -1}
  end

  defp is_collision(point, current, ball) do
    var = Map.get(point, current)
    if ball == var do
      {true, current}
    else
      is_collision(point, current + 1, ball)
    end
  end

  defp update_ball({id, {x, y}}, {pre_id, {pre_x, pre_y}}, data1, data2) do
    pre_dev = get_device(pre_id)
    pre_data = get_data(pre_dev, {data1, data2})
    del_x = (~~~(128 >>> pre_y)) &&& Map.get(pre_data, pre_x + 1)
    new_data = Map.put(pre_data, pre_x + 1, del_x)
    if id == pre_id do
      new_x = 128 >>> y
      current_row = Map.get(new_data, x + 1)
      new_row = new_x ||| current_row
      result = Map.put(new_data, x + 1, new_row)
      get_return_data({data1, data2}, result, pre_dev)
    else
      device = get_device(id)
      dev_data = get_data(device, {data1, data2})
      new_x = 128 >>> y
      current_row = Map.get(dev_data, x + 1)
      new_row = new_x ||| current_row
      result = Map.put(dev_data, x + 1, new_row)
      if device == :device_1 do
        {result, new_data}
      else
        {new_data, result}
      end
    end
  end

  defp init_sw_interrupt() do
    GPIO.set_pin_mode(@gpio_sw, :input)
    GPIO.set_pin_pull(@gpio_sw, :up)
    gpio = GPIO.start()
    GPIO.set_int(gpio, @gpio_sw, :rising)
  end

  defp read_adc(adc) do
    case :esp_adc.read(adc) do
      {:ok, {raw, _milli_volts}} -> {:ok, raw}
      error -> :io.format("Error taking reading: ~p~n", [error])
    end
  end

  def joystick(pid, adcx, _adcy) do
    receive do
      :stop -> :ok
    after
      @delay_read_adc ->
        {:ok, x} = read_adc(adcx)
        cond do
          x < @low_range -> GenServer.cast(pid, {:move_cross_bar, -1})
          x > @high_range -> GenServer.cast(pid, {:move_cross_bar, 1})
          true -> :nothing_change
        end
        joystick(pid, adcx, _adcy)
    end
  end

  defp handle_game_over(score) do
    first_num = get_num_macro(div(score, 10))
    second_num = get_num_macro(rem(score, 10))
    {first_num, second_num}
  end

  defp get_num_macro(number) do
    case number do
      0 -> @number_0
      1 -> @number_1
      2 -> @number_2
      3 -> @number_3
      4 -> @number_4
      5 -> @number_5
      6 -> @number_6
      7 -> @number_7
      8 -> @number_8
      9 -> @number_9
    end
  end

  defp display_game_text(spi, times, command) do
    data1 = get_display_data(@empty_matrix, 1, times, command)
    data2 = get_display_data(@empty_matrix, 1, times + 8, command)
    write_digit(spi, @digit_0, data1, :device_1)
    write_digit(spi, @digit_0, data2, :device_2)
  end

  defp get_display_data(result, 9, _times, _command) do
    result
  end

  defp get_display_data(result, number, times, :welcome) do
    row = Map.get(@breaker_game, number + times)
    new_result = Map.put(result, number, row)
    get_display_data(new_result, number + 1, times, :welcome)
  end

  defp get_display_data(result, number, times, :lose) do
    row = Map.get(@game_over, number + times)
    new_result = Map.put(result, number, row)
    get_display_data(new_result, number + 1, times, :lose)
  end

  defp get_display_data(result, number, times, :win) do
    row = Map.get(@game_win, number + times)
    new_result = Map.put(result, number, row)
    get_display_data(new_result, number + 1, times, :win)
  end

  def game_over_process(p, times, count_reset_to_welcome) do
    receive do
      :stop -> :ok
    after
      100 ->
        GenServer.cast(p, {:display_game_over, times})
        {new_times, new_count_reset_to_welcome} =
          if times + 1 == 61 do
            {0, count_reset_to_welcome + 1}
          else
            {times + 1, count_reset_to_welcome}
          end
        if count_reset_to_welcome == 1 do
          send(p, :back_to_welcome)
        end
        game_over_process(p, new_times, new_count_reset_to_welcome)
    end
  end

  def welcome_block_breaker_game_process(p, times) do
    receive do
      :stop -> :ok
    after
      200 ->
        GenServer.cast(p, {:display_breaker_game, times})
        new_times =
          if times + 1 == 75 do
            0
          else
            times + 1
          end
        welcome_block_breaker_game_process(p, new_times)
    end
  end

  def game_win_process(p, times) do
    receive do
      :stop -> :ok
    after
      200 ->
        GenServer.cast(p, {:display_game_win, times})
        new_times =
          if times + 1 == 27 do
            0
          else
            times + 1
          end
        game_win_process(p, new_times)
    end
  end

  def variable_resistor(parent, adc, previous_speed) do
    {:ok, speed} = read_adc(adc)
    map_speed = map_value(speed, 0, @bit_resolution, @max_speed, @min_speed)
    is_change = is_not_in_range(previous_speed, map_speed)
    if is_change do
      send(parent, {:newspeed, map_speed})
    end
    new_speed =
      if is_change do
        map_speed
      else
        previous_speed
      end
    :timer.sleep(new_speed)
    variable_resistor(parent, adc, new_speed)
  end

  defp is_not_in_range(pre_val, new_val) do
    low = pre_val - 10
    high = pre_val + 10
    not (new_val >= low and new_val <= high)
  end

  defp map_value(value, in_low, in_high, out_low, out_high) do
    res = (value - in_low) * (out_high - out_low) / (in_high - in_low) + out_low
    round(res)
  end

  def ball(pid, pre_speed) do
    new_speed =
      receive do
        {:newspeed, speed} -> speed
      after
        pre_speed -> pre_speed
      end
    GenServer.cast(pid, :move_ball)
    ball(pid, new_speed)
  end
end
