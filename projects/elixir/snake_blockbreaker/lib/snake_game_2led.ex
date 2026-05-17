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

defmodule SnakeGame2Led do
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

  @gpio_miso 19
  @gpio_mosi 27
  @gpio_sclk 5
  @gpio_cs 18

  @low_range 800
  @high_range 3000

  @delay_read_adc 20
  @max_speed 200
  @min_speed 1000
  @blink_rate 200
  @bit_resolution 4095

  @num_of_bits 8
  @device_name :device_1

  @led0 0
  @led1 1

  @head {0, {2, 4}}
  @body %{0 => {0, {1, 4}}, 1 => {0, {2, 4}}}
  @direction {1, 0}
  @snake_length 2

  defstruct [
    :spi,
    :snakehead,
    :snakebody,
    :snakelen,
    :food,
    :data1,
    :data2,
    :direction,
    :gameover,
    :goverproc,
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

  @number_0_left %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b01100000,
    @digit_3 => 0b10010000,
    @digit_4 => 0b10010000,
    @digit_5 => 0b10010000,
    @digit_6 => 0b01100000,
    @digit_7 => 0b00000000
  }

  @number_1_left %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b01000000,
    @digit_3 => 0b11000000,
    @digit_4 => 0b01000000,
    @digit_5 => 0b01000000,
    @digit_6 => 0b11100000,
    @digit_7 => 0b00000000
  }

  @number_2_left %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b01100000,
    @digit_3 => 0b10010000,
    @digit_4 => 0b00100000,
    @digit_5 => 0b01000000,
    @digit_6 => 0b11110000,
    @digit_7 => 0b00000000
  }

  @number_3_left %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b01100000,
    @digit_3 => 0b10010000,
    @digit_4 => 0b00100000,
    @digit_5 => 0b10010000,
    @digit_6 => 0b01100000,
    @digit_7 => 0b00000000
  }

  @number_4_left %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00010000,
    @digit_3 => 0b00110000,
    @digit_4 => 0b01010000,
    @digit_5 => 0b11110000,
    @digit_6 => 0b00010000,
    @digit_7 => 0b00000000
  }

  @number_5_left %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b11110000,
    @digit_3 => 0b10000000,
    @digit_4 => 0b11110000,
    @digit_5 => 0b00010000,
    @digit_6 => 0b11110000,
    @digit_7 => 0b00000000
  }

  @number_6_left %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b11110000,
    @digit_3 => 0b10000000,
    @digit_4 => 0b11110000,
    @digit_5 => 0b10010000,
    @digit_6 => 0b11110000,
    @digit_7 => 0b00000000
  }

  @number_7_left %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b11110000,
    @digit_3 => 0b00010000,
    @digit_4 => 0b00100000,
    @digit_5 => 0b01000000,
    @digit_6 => 0b10000000,
    @digit_7 => 0b00000000
  }

  @number_8_left %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b11110000,
    @digit_3 => 0b10010000,
    @digit_4 => 0b11110000,
    @digit_5 => 0b10010000,
    @digit_6 => 0b11110000,
    @digit_7 => 0b00000000
  }

  @number_9_left %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b11110000,
    @digit_3 => 0b10010000,
    @digit_4 => 0b11110000,
    @digit_5 => 0b00010000,
    @digit_6 => 0b11110000,
    @digit_7 => 0b00000000
  }

  @number_0_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000110,
    @digit_3 => 0b00001001,
    @digit_4 => 0b00001001,
    @digit_5 => 0b00001001,
    @digit_6 => 0b00000110,
    @digit_7 => 0b00000000
  }

  @number_1_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000010,
    @digit_3 => 0b00000110,
    @digit_4 => 0b00000010,
    @digit_5 => 0b00000010,
    @digit_6 => 0b00000111,
    @digit_7 => 0b00000000
  }

  @number_2_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000110,
    @digit_3 => 0b00001001,
    @digit_4 => 0b00000010,
    @digit_5 => 0b00000100,
    @digit_6 => 0b00001111,
    @digit_7 => 0b00000000
  }

  @number_3_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000110,
    @digit_3 => 0b00001001,
    @digit_4 => 0b00000010,
    @digit_5 => 0b00001001,
    @digit_6 => 0b00000110,
    @digit_7 => 0b00000000
  }

  @number_4_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00000001,
    @digit_3 => 0b00000011,
    @digit_4 => 0b00000101,
    @digit_5 => 0b00001111,
    @digit_6 => 0b00000001,
    @digit_7 => 0b00000000
  }

  @number_5_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00001111,
    @digit_3 => 0b00001000,
    @digit_4 => 0b00001111,
    @digit_5 => 0b00000001,
    @digit_6 => 0b00001111,
    @digit_7 => 0b00000000
  }

  @number_6_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00001111,
    @digit_3 => 0b00001000,
    @digit_4 => 0b00001111,
    @digit_5 => 0b00001001,
    @digit_6 => 0b00001111,
    @digit_7 => 0b00000000
  }

  @number_7_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00001111,
    @digit_3 => 0b00000001,
    @digit_4 => 0b00000010,
    @digit_5 => 0b00000100,
    @digit_6 => 0b00001000,
    @digit_7 => 0b00000000
  }

  @number_8_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00001111,
    @digit_3 => 0b00001001,
    @digit_4 => 0b00001111,
    @digit_5 => 0b00001001,
    @digit_6 => 0b00001111,
    @digit_7 => 0b00000000
  }

  @number_9_right %{
    @digit_0 => 0b00000000,
    @digit_1 => 0b00000000,
    @digit_2 => 0b00001111,
    @digit_3 => 0b00001001,
    @digit_4 => 0b00001111,
    @digit_5 => 0b00000001,
    @digit_6 => 0b00001111,
    @digit_7 => 0b00000000
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

  @snake_game %{
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
    18 => 0b01001110,
    19 => 0b01001010,
    20 => 0b01010010,
    21 => 0b01110010,
    22 => 0b00000000,
    23 => 0b01111110,
    24 => 0b00000100,
    25 => 0b00001000,
    26 => 0b00010000,
    27 => 0b01111110,
    28 => 0b00000000,
    29 => 0b01111100,
    30 => 0b00001010,
    31 => 0b00001010,
    32 => 0b01111100,
    33 => 0b00000000,
    34 => 0b01111110,
    35 => 0b00001000,
    36 => 0b00010100,
    37 => 0b01100010,
    38 => 0b00000000,
    39 => 0b01111110,
    40 => 0b01001010,
    41 => 0b01001010,
    42 => 0b01000010,
    43 => 0b00000000,
    44 => 0b00000000,
    45 => 0b00000000,
    46 => 0b00111100,
    47 => 0b01000010,
    48 => 0b01001010,
    49 => 0b00111010,
    50 => 0b00001000,
    51 => 0b00000000,
    52 => 0b01111100,
    53 => 0b00001010,
    54 => 0b00001010,
    55 => 0b01111100,
    56 => 0b00000000,
    57 => 0b01111110,
    58 => 0b00000100,
    59 => 0b00001000,
    60 => 0b00000100,
    61 => 0b01111110,
    62 => 0b00000000,
    63 => 0b01111110,
    64 => 0b01001010,
    65 => 0b01001010,
    66 => 0b01000010,
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
    78 => 0b00000000,
    79 => 0b00000000,
    80 => 0b00000000,
    81 => 0b00000000,
    82 => 0b00000000,
    83 => 0b00000000
  }

  def start(spi) do
    :erlang.system_flag(:schedulers_online, 2)
    {:ok, pid} = GenServer.start(__MODULE__, spi)
    :timer.sleep(500)
    joystick_pid = spawn(__MODULE__, :joystick, [pid, @gpio_vrx, @gpio_vry])
    GenServer.cast(pid, {:update_joystick_pid, joystick_pid})
    spawn(__MODULE__, :blink_food, [pid])
    loop(pid, @max_speed)
  end

  def init(spi) do
    init_sw_interrupt()
    IO.puts("Init SPI and MAX7219 OK\n")
    new_proc = spawn(__MODULE__, :welcome_snake_game_process, [self(), 0])
    new_state = %__MODULE__{spi: spi, gameover: true, goverproc: new_proc}
    {:ok, new_state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:update_joystick_pid, pid}, state) do
    {:noreply, %{state | joystick_pid: pid}}
  end

  def handle_cast({:change_direction, x, y}, state) do
    if state.gameover do
      {:noreply, state}
    else
      flag = is_backward(state, {x, y})
      new_state =
        if flag do
          state
        else
          %{state | direction: {x, y}}
        end
      {:noreply, new_state}
    end
  end

  def handle_cast(:move, state) do
    new_state =
      if state.gameover do
        state
      else
        move_snake(state)
      end
    {:noreply, new_state}
  end

  def handle_cast({:display_game_over, times}, state) do
    display_game_text(state.spi, times, :lose)
    {:noreply, state}
  end

  def handle_cast({:display_snake_game, times}, state) do
    display_game_text(state.spi, times, :welcome)
    {:noreply, state}
  end

  def handle_cast(:turn_off_food, state) do
    if state.gameover do
      {:noreply, state}
    else
      turn_off_food(state.spi, state.food, {state.data1, state.data2})
      {:noreply, state}
    end
  end

  def handle_cast(:turn_on_food, state) do
    if state.gameover do
      {:noreply, state}
    else
      turn_on_food(state.spi, state.food, {state.data1, state.data2})
      {:noreply, state}
    end
  end

  def handle_info({:gpio_interrupt, @gpio_sw}, state) do
    IO.puts("receive interrupt")
    if is_pid(state.goverproc) do
      send(state.goverproc, :stop)
    end
    {snake_head, snake_body, food, {data1, data2}} = init_snake(state.spi, @body)
    new_state = %{state |
      snakehead: snake_head,
      snakebody: snake_body,
      snakelen: @snake_length,
      food: food,
      direction: @direction,
      data1: data1,
      data2: data2,
      gameover: false,
      goverproc: nil
    }
    {:noreply, new_state}
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
    IO.puts("snake genserver terminated")
    :ok
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

  def joystick(pid, adcx, adcy) do
    receive do
      :stop -> :ok
    after
      @delay_read_adc ->
        {:ok, x} = read_adc(adcx)
        {:ok, y} = read_adc(adcy)
        cond do
          x < @low_range -> GenServer.cast(pid, {:change_direction, -1, 0})
          y < @low_range -> GenServer.cast(pid, {:change_direction, 0, -1})
          x > @high_range -> GenServer.cast(pid, {:change_direction, 1, 0})
          y > @high_range -> GenServer.cast(pid, {:change_direction, 0, 1})
          true -> :nothing_change
        end
        joystick(pid, adcx, adcy)
    end
  end

  defp init_snake(spi, body) do
    digit_list = @empty_matrix
    {_id, {head_x, head_y}} = @head
    data1 = digit_list |> Map.put(head_x + 1, 128 >>> head_y) |> Map.put(head_x, 128 >>> head_y)
    data2 = @empty_matrix
    {food_id, {food_x, food_y}} = spawn_new_food(body, @snake_length)
    temp_data = get_data(get_device(food_id), {data1, data2})
    row = Map.get(temp_data, food_x + 1) ||| (128 >>> food_y)
    new_data = Map.put(temp_data, food_x + 1, row)
    {res1, res2} = get_return_data({data1, data2}, new_data, get_device(food_id))
    write_digit(spi, @digit_0, res1, :device_1)
    write_digit(spi, @digit_0, res2, :device_2)
    :io.format("First Food is ~p ~n", [{food_id, {food_x, food_y}}])
    {@head, @body, {food_id, {food_x, food_y}}, {res1, res2}}
  end

  defp move_snake(state) do
    {id, {x, y}} = state.snakehead
    {dir_x, dir_y} = state.direction
    snake_head = {x + dir_x, y + dir_y}
    new_snake_head = handle_border(id, snake_head)
    {new_snake_len, new_snake_body, new_food} =
      if new_snake_head == state.food do
        new_snake_len = state.snakelen + 1
        new_snake_body = update_snake_body(state.snakebody, new_snake_len, state.food)
        new_food = spawn_new_food(new_snake_body, new_snake_len)
        {new_snake_len, new_snake_body, new_food}
      else
        new_snake_len = state.snakelen
        previous_body = %{}
        new_snake_body = shift_snake(state.snakebody, new_snake_head, new_snake_len - 1, previous_body, 0)
        new_food = state.food
        {new_snake_len, new_snake_body, new_food}
      end
    status = is_game_over(new_snake_head, new_snake_body, new_snake_len - 1, 0)
    if status do
      send(self(), :stop_peripherals)
      :timer.sleep(500)
      {data1, data2} = handle_game_over(state.snakelen)
      write_digit(state.spi, @digit_0, data1, :device_1)
      write_digit(state.spi, @digit_0, data2, :device_2)
      :timer.sleep(2000)
      new_proc = spawn(__MODULE__, :game_over_process, [self(), 0, 0])
      %{state | gameover: true, goverproc: new_proc}
    else
      {data1, data2} = update_data(new_snake_body, {@empty_matrix, @empty_matrix}, new_food, 0, new_snake_len)
      write_digit(state.spi, @digit_0, data1, :device_1)
      write_digit(state.spi, @digit_0, data2, :device_2)
      %{state |
        snakehead: new_snake_head,
        snakebody: new_snake_body,
        snakelen: new_snake_len,
        food: new_food,
        data1: data1,
        data2: data2
      }
    end
  end

  defp handle_border(id, {x, y}) do
    cond do
      x > 7 and id == @led0 -> {@led1, {0, y}}
      x > 7 and id == @led1 -> {@led0, {0, y}}
      x < 0 and id == @led0 -> {@led1, {7, y}}
      x < 0 and id == @led1 -> {@led0, {7, y}}
      y > 7 -> {id, {x, 0}}
      y < 0 -> {id, {x, 7}}
      true -> {id, {x, y}}
    end
  end

  defp update_snake_body(snake_body, snake_len, food) do
    Map.put(snake_body, snake_len - 1, food)
  end

  defp shift_snake(_snake_body, snake_head, snake_len, previous_body, snake_len) do
    Map.put(previous_body, snake_len, snake_head)
  end

  defp shift_snake(snake_body, snake_head, snake_len, previous_body, number) do
    next_ele = Map.get(snake_body, number + 1)
    new_snake_body = Map.put(previous_body, number, next_ele)
    shift_snake(snake_body, snake_head, snake_len, new_snake_body, number + 1)
  end

  defp update_data(_map, data, {id, {x, y}}, len, len) do
    temp = get_data(get_device(id), data)
    new_data = write_element({x, y}, temp)
    get_return_data(data, new_data, get_device(id))
  end

  defp update_data(map, data, food, number, len) do
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
    update_data(map, return_data, food, number + 1, len)
  end

  defp write_element({x, y}, data) do
    new_x = 128 >>> y
    current_row = Map.get(data, x + 1)
    new_row = new_x ||| current_row
    Map.put(data, x + 1, new_row)
  end

  defp is_game_over(_snake_head, _snake_body, snake_len, snake_len) do
    false
  end

  defp is_game_over(snake_head, snake_body, snake_len, number) do
    element = Map.get(snake_body, number)
    if element == snake_head do
      true
    else
      is_game_over(snake_head, snake_body, snake_len, number + 1)
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
    row = Map.get(@snake_game, number + times)
    new_result = Map.put(result, number, row)
    get_display_data(new_result, number + 1, times, :welcome)
  end

  defp get_display_data(result, number, times, :lose) do
    row = Map.get(@game_over, number + times)
    new_result = Map.put(result, number, row)
    get_display_data(new_result, number + 1, times, :lose)
  end

  defp is_backward(state, direction) do
    {_idbody, {pre_x, pre_y}} = Map.get(state.snakebody, state.snakelen - 2)
    {_idhead, {head_x, head_y}} = state.snakehead
    {x, y} = {head_x - pre_x, head_y - pre_y}
    sub =
      if abs(x) + abs(y) != 1 do
        {rem(x, 6), rem(y, 6)}
      else
        {-x, -y}
      end
    sub == direction
  end

  defp rand() do
    value = :atomvm.random() |> rem(8)
    if value >= 0 do
      value
    else
      rand()
    end
  end

  defp rand_led() do
    value = :atomvm.random()
    if value >= 0 do
      1
    else
      0
    end
  end

  defp spawn_new_food(body, size) do
    food_x = rand()
    food_y = rand()
    food_id = rand_led()
    flag = is_exits(body, {food_id, {food_x, food_y}}, size, 0)
    if flag do
      spawn_new_food(body, size)
    else
      {food_id, {food_x, food_y}}
    end
  end

  defp is_exits(_body, _food, size, size) do
    false
  end

  defp is_exits(body, food, size, number) do
    temp = Map.get(body, number)
    if temp == food do
      true
    else
      is_exits(body, food, size, number + 1)
    end
  end

  defp turn_off_food(spi, {food_id, {food_x, food_y}}, data) do
    dev = get_device(food_id)
    temp = get_data(dev, data)
    row = Map.get(temp, food_x + 1)
    temp1 = row &&& (~~~(128 >>> food_y))
    write_register(spi, food_x + 1, temp1, dev)
  end

  defp turn_on_food(spi, {food_id, {food_x, food_y}}, data) do
    dev = get_device(food_id)
    temp = get_data(dev, data)
    row = Map.get(temp, food_x + 1)
    temp1 = row ||| (128 >>> food_y)
    write_register(spi, food_x + 1, temp1, dev)
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

  def welcome_snake_game_process(p, times) do
    receive do
      :stop -> :ok
    after
      200 ->
        GenServer.cast(p, {:display_snake_game, times})
        new_times =
          if times + 1 == 66 do
            0
          else
            times + 1
          end
        welcome_snake_game_process(p, new_times)
    end
  end

  def blink_food(pid) do
    GenServer.cast(pid, :turn_off_food)
    :timer.sleep(@blink_rate)
    GenServer.cast(pid, :turn_on_food)
    :timer.sleep(@blink_rate)
    blink_food(pid)
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

  def loop(pid, pre_speed) do
    new_speed =
      receive do
        {:newspeed, speed} -> speed
      after
        pre_speed -> pre_speed
      end
    GenServer.cast(pid, :move)
    loop(pid, new_speed)
  end
end
