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

defmodule SnakeBlockbreaker do
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
  5. `select_game1/2` – same as `select_game/2`, called after a game ends

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

  @low_range 800
  @high_range 3000

  @delay_read_adc 100

  @num_of_bits 8

  @spisettings [
    bus_config: [miso: 19, mosi: 27, sclk: 5],
    device_config: [
      device_1: [clock_speed_hz: 1_000_000, mode: 0, cs: 18, address_len_bits: 8],
      device_2: [clock_speed_hz: 1_000_000, mode: 0, cs: 23, address_len_bits: 8]
    ]
  ]

  defstruct [:spi, :goverproc]

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

  def start do
    :erlang.system_flag(:schedulers_online, 2)
    {:ok, _} = SnakeBlockbreaker.DistErl.start_link()
    case SnakeBlockbreaker.WiFi.start_link() do
      {:ok, _} -> :ok
      {:error, _} -> IO.puts("wifi: not available, game runs without remote speed control")
    end
    {:ok, pid} = GenServer.start(__MODULE__, [], name: :snake_blockbreaker)
    {adcx, _adcy} = setup_adc()
    select_game(pid, adcx)
  end

  def init(_) do
    {:ok, spi} = init_max7219(@spisettings)
    IO.puts("Init SPI and MAX7219 OK\n")
    new_proc = spawn(__MODULE__, :display_select_game, [self(), 0])
    new_state = %__MODULE__{spi: spi, goverproc: new_proc}
    {:ok, new_state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(:game_over, state) do
    IO.puts("parent game_over\n")
    new_proc = spawn(__MODULE__, :display_select_game, [self(), 0])
    spawn(__MODULE__, :select_game1, [self(), @gpio_vrx])
    new_state = %{state | goverproc: new_proc}
    {:noreply, new_state}
  end

  def handle_cast({:display_select_game_flag, times}, state) do
    display_game_text(state.spi, times)
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
    {:ok, x} = read_adc(adcx)
    cond do
      x < @low_range ->
        send(pid, {self(), :do_select_game})
        receive do
          {:spi, spi} -> SnakeGame2Led.start(spi)
        end
      x > @high_range ->
        send(pid, {self(), :do_select_game})
        receive do
          {:spi, spi} -> BlockBreaker2Led.start(spi)
        end
      true ->
        :timer.sleep(@delay_read_adc)
        select_game(pid, adcx)
    end
  end

  def select_game1(pid, adcx) do
    {:ok, x} = read_adc(adcx)
    cond do
      x < @low_range ->
        send(pid, {self(), :do_select_game})
        receive do
          {:spi, spi} -> SnakeGame2Led.start(spi)
        end
      x > @high_range ->
        send(pid, {self(), :do_select_game})
        receive do
          {:spi, spi} -> BlockBreaker2Led.start(spi)
        end
      true ->
        :timer.sleep(@delay_read_adc)
        select_game1(pid, adcx)
    end
  end

  def display_select_game(p, times) do
    receive do
      :stop -> :ok
    after
      800 ->
        GenServer.cast(p, {:display_select_game_flag, times})
        new_times =
          if times + 8 > 32 do
            0
          else
            times + 8
          end
        display_select_game(p, new_times)
    end
  end

  defp display_game_text(spi, times) do
    data1 = get_data(@empty_matrix, 1, times, :snake)
    data2 = get_data(@empty_matrix, 1, times, :breaker)
    write_digit(spi, @digit_0, data1, :device_1)
    write_digit(spi, @digit_0, data2, :device_2)
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
    write_register(spi, @intensity, 0x3, :device_1)
    write_register(spi, @scan_limit, 0x7, :device_1)
    write_register(spi, @shutdown, 0x1, :device_1)
    write_register(spi, @display_test, 0x0, :device_1)

    write_register(spi, @decode_mode, 0x0, :device_2)
    write_register(spi, @intensity, 0x3, :device_2)
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
end
