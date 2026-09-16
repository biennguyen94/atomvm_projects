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

defmodule SnakeBlockbreakerClock.LedDisplay do
  @moduledoc """
  Shared LED display helpers for all 2x MAX7219 game modules.

  Provides:
  - MAX7219 register constants (injected via `use`)
  - `@empty_matrix` (injected via `use`)
  - 7-segment number bitmaps for score display
  - SPI write helpers (`write_digit/4`, `write_register/4`)
  - ADC reading (`read_adc/1`)
  - LED matrix utility functions
  """

  use Bitwise

  @center_numbers %{
    0 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00111100, 4 => 0b01000010,
           5 => 0b01000010, 6 => 0b00111100, 7 => 0b00000000, 8 => 0b00000000},
    1 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b01000000, 4 => 0b01000010,
           5 => 0b01111110, 6 => 0b01000000, 7 => 0b00000000, 8 => 0b00000000},
    2 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b01000100, 4 => 0b01100010,
           5 => 0b01010010, 6 => 0b01001100, 7 => 0b00000000, 8 => 0b00000000},
    3 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00100100, 4 => 0b01000010,
           5 => 0b01011010, 6 => 0b00100100, 7 => 0b00000000, 8 => 0b00000000},
    4 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00011000, 4 => 0b00010100,
           5 => 0b01111110, 6 => 0b00010000, 7 => 0b00000000, 8 => 0b00000000},
    5 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b01001110, 4 => 0b01001010,
           5 => 0b01001010, 6 => 0b01111010, 7 => 0b00000000, 8 => 0b00000000},
    6 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b01111110, 4 => 0b01001010,
           5 => 0b01001010, 6 => 0b01111010, 7 => 0b00000000, 8 => 0b00000000},
    7 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b01000010, 4 => 0b00100010,
           5 => 0b00010010, 6 => 0b00001110, 7 => 0b00000000, 8 => 0b00000000},
    8 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00110100, 4 => 0b01001010,
           5 => 0b01001010, 6 => 0b00110100, 7 => 0b00000000, 8 => 0b00000000},
    9 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b01001110, 4 => 0b01001010,
           5 => 0b01001010, 6 => 0b01111110, 7 => 0b00000000, 8 => 0b00000000}
  }

  @left_numbers %{
    0 => %{1 => 0b00111100, 2 => 0b01000010, 3 => 0b01000010, 4 => 0b00111100,
           5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    1 => %{1 => 0b01000100, 2 => 0b01111110, 3 => 0b01000000, 4 => 0b00000000,
           5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    2 => %{1 => 0b01000100, 2 => 0b01100010, 3 => 0b01010010, 4 => 0b01001100,
           5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    3 => %{1 => 0b01000010, 2 => 0b01001010, 3 => 0b01111110, 4 => 0b00000000,
           5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    4 => %{1 => 0b00010000, 2 => 0b00011000, 3 => 0b00010100, 4 => 0b01111110,
           5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    5 => %{1 => 0b01001110, 2 => 0b01001010, 3 => 0b01001010, 4 => 0b01111010,
           5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    6 => %{1 => 0b01111110, 2 => 0b01001010, 3 => 0b01001010, 4 => 0b01111010,
           5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    7 => %{1 => 0b01000010, 2 => 0b00100010, 3 => 0b00010010, 4 => 0b00001110,
           5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    8 => %{1 => 0b01111110, 2 => 0b01001010, 3 => 0b01001010, 4 => 0b01111110,
           5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    9 => %{1 => 0b01001110, 2 => 0b01001010, 3 => 0b01001010, 4 => 0b01111110,
           5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000}
  }

  @right_numbers %{
    0 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000,
           5 => 0b00111100, 6 => 0b01000010, 7 => 0b01000010, 8 => 0b00111100},
    1 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000,
           5 => 0b00000000, 6 => 0b01000100, 7 => 0b01111110, 8 => 0b01000000},
    2 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000,
           5 => 0b01000100, 6 => 0b01100010, 7 => 0b01010010, 8 => 0b01001100},
    3 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000,
           5 => 0b00000000, 6 => 0b01000010, 7 => 0b01001010, 8 => 0b01111110},
    4 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000,
           5 => 0b00010000, 6 => 0b00011000, 7 => 0b00010100, 8 => 0b01111110},
    5 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000,
           5 => 0b01001110, 6 => 0b01001010, 7 => 0b01001010, 8 => 0b01111010},
    6 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000,
           5 => 0b01111110, 6 => 0b01001010, 7 => 0b01001010, 8 => 0b01111010},
    7 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000,
           5 => 0b01000010, 6 => 0b00100010, 7 => 0b00010010, 8 => 0b00001110},
    8 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000,
           5 => 0b01111110, 6 => 0b01001010, 7 => 0b01001010, 8 => 0b01111110},
    9 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000,
           5 => 0b01001110, 6 => 0b01001010, 7 => 0b01001010, 8 => 0b01111110}
  }

  defmacro __using__(_opts) do
    quote do
      use Bitwise
      import SnakeBlockbreakerClock.LedDisplay

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
      @num_of_bits 8

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
    end
  end

  def number(n), do: Map.fetch!(@center_numbers, n)

  def number_left(n), do: Map.fetch!(@left_numbers, n)

  def number_right(n), do: Map.fetch!(@right_numbers, n)

  def write_digit(spi, 8, data, device) do
    reg_data = Map.get(data, 8)
    write_register(spi, 8, reg_data, device)
    :ok
  end

  def write_digit(spi, number, data, device) do
    reg_data = Map.get(data, number)
    write_register(spi, number, reg_data, device)
    write_digit(spi, number + 1, data, device)
  end

  def write_digit_diff(spi, 8, data, device, last_data) do
    reg_data = Map.get(data, 8)
    if is_nil(last_data) or Map.get(last_data, 8) != reg_data do
      write_register(spi, 8, reg_data, device)
    end

    :ok
  end

  def write_digit_diff(spi, number, data, device, last_data) do
    reg_data = Map.get(data, number)
    if is_nil(last_data) or Map.get(last_data, number) != reg_data do
      write_register(spi, number, reg_data, device)
    end

    write_digit_diff(spi, number + 1, data, device, last_data)
  end

  def write_register(spi, address, data, device) do
    :spi.write_at(spi, device, address, 8, data)
  end

  def read_adc(adc) do
    case :esp_adc.read(adc) do
      {:ok, {raw, _milli_volts}} -> {:ok, raw}
      error ->
        :io.format("Error taking reading: ~p~n", [error])
        :error
    end
  end

  def get_device(0), do: :device_1
  def get_device(1), do: :device_2

  def get_data(:device_1, {data1, _data2}), do: data1
  def get_data(:device_2, {_data1, data2}), do: data2

  def get_return_data({_data1, data2}, new_data, :device_1), do: {new_data, data2}
  def get_return_data({data1, _data2}, new_data, :device_2), do: {data1, new_data}

  def write_element({x, y}, data) do
    new_x = 128 >>> y
    current_row = Map.get(data, x + 1)
    new_row = new_x ||| current_row
    Map.put(data, x + 1, new_row)
  end

  def handle_game_over(score) do
    {get_num_macro(div(score, 10)), get_num_macro(rem(score, 10))}
  end

  def get_num_macro(n), do: number(n)
end
