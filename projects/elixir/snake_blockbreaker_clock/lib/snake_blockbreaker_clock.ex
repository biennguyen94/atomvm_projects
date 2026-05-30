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

  @spisettings [
    bus_config: [miso: 19, mosi: 27, sclk: 5],
    device_config: [
      device_1: [clock_speed_hz: 1_000_000, mode: 0, cs: 18, address_len_bits: 8],
      device_2: [clock_speed_hz: 1_000_000, mode: 0, cs: 23, address_len_bits: 8]
    ]
  ]

  defstruct [:spi, :goverproc]

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

  def start do
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
    wait_for_sntp(60)
    show_clock(pid)

    start_animation(pid)
    select_game(pid, @gpio_vrx)
  end

  def init(_) do
    {:ok, spi} = init_max7219(@spisettings)
    IO.puts("Init SPI and MAX7219 OK\n")
    new_state = %__MODULE__{spi: spi, goverproc: nil}
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

  def handle_cast(:game_over, state) do
    IO.puts("parent game_over\n")
    new_proc = spawn(__MODULE__, :display_select_game, [self(), 0])
    spawn(__MODULE__, :select_game1, [self(), @gpio_vrx])
    new_state = %{state | goverproc: new_proc}
    {:noreply, new_state}
  end

  def handle_cast({:exit_to_clock}, state) do
    IO.puts("parent: exiting to clock mode")
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
    spawn(__MODULE__, :select_game1, [self(), @gpio_vrx])
    {:noreply, %{state | goverproc: new_proc}}
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
    clock_loop(spi, @empty_matrix, @empty_matrix, 0, @empty_matrix, @empty_matrix, 0, 0, 0)
  end

  def display_clock(parent_pid, spi) do
    GPIO.set_pin_mode(@gpio_sw, :input)
    GPIO.set_pin_pull(@gpio_sw, :up)
    :esp_adc.start(@gpio_vrx)
    :esp_adc.start(@gpio_vry)
    clock_loop(spi, @empty_matrix, @empty_matrix, 0, @empty_matrix, @empty_matrix, 0, 0, 0)
    clear_display(spi)
    send(parent_pid, {:clock_done})
  end

  defp start_animation(pid) do
    new_proc = spawn(__MODULE__, :display_select_game, [pid, 0])
    GenServer.cast(pid, {:set_goverproc, new_proc})
  end

  defp clock_loop(spi, prev_left, prev_right, tick, disp_left, disp_right, shift_x, shift_y, blink_count) do
    receive do
      :stop -> :ok
    after
      0 ->
        if button_pressed?() do
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

              if new_left != prev_left do
                apply_effect(spi, prev_left, new_left, :device_1, rem(hour, 3))
              end
              if new_right != prev_right do
                apply_effect(spi, prev_right, new_right, :device_2, rem(minute, 3))
              end

              IO.puts("Clock: #{pad(hour)}:#{pad(minute)}")
              {new_left, new_right, 19}
            else
              {prev_left, prev_right, tick - 1}
            end

          {new_shift_x, new_shift_y} = read_joystick_shifts(shift_x, shift_y)
          {new_disp_left, new_disp_right} = apply_shifts(time_left, time_right, new_shift_x, new_shift_y)

          blink_bit = 0b00000001
          blink_on? = rem(blink_count, 10) < 5
          row8 = (Map.get(new_disp_left, 8, 0) &&& ~~~blink_bit) ||| (if blink_on?, do: blink_bit, else: 0)
          new_disp_left = Map.put(new_disp_left, 8, row8)
          row1 = (Map.get(new_disp_right, 1, 0) &&& ~~~blink_bit) ||| (if blink_on?, do: blink_bit, else: 0)
          new_disp_right = Map.put(new_disp_right, 1, row1)

          if new_disp_left != disp_left or new_disp_right != disp_right do
            write_digit(spi, @digit_0, new_disp_left, :device_1)
            write_digit(spi, @digit_0, new_disp_right, :device_2)
          end

          Process.sleep(50)
          clock_loop(spi, time_left, time_right, new_tick, new_disp_left, new_disp_right, new_shift_x, new_shift_y, blink_count + 1)
        end
    end
  end

  defp read_joystick_shifts(shift_x, shift_y) do
    {:ok, x} = case :esp_adc.read(@gpio_vry) do
      {:ok, {raw, _}} -> {:ok, raw}
      other -> other
    end
    {:ok, y} = case :esp_adc.read(@gpio_vrx) do
      {:ok, {raw, _}} -> {:ok, raw}
      other -> other
    end

    x_dev = abs(x - 2048)
    y_dev = abs(y - 2048)
    min_dev = 200

    cond do
      x_dev > y_dev and x_dev > min_dev and x < @low_range -> {shift_x - 1, 0}
      x_dev > y_dev and x_dev > min_dev and x > @high_range -> {shift_x + 1, 0}
      y_dev > x_dev and y_dev > min_dev and y < @low_range -> {0, shift_y - 1}
      y_dev > x_dev and y_dev > min_dev and y > @high_range -> {0, shift_y + 1}
      true -> {0, 0}
    end
  end

  defp apply_shifts(left, right, shift_x, shift_y) do
    {shifted_left, shifted_right} = tilt_cols_coupled(left, right, shift_x)
    {tilt_rows(shifted_left, shift_y), tilt_rows(shifted_right, shift_y)}
  end

  defp tilt_cols_coupled(left, right, 0), do: {left, right}
  defp tilt_cols_coupled(left, right, shift) do
    s = rem(shift, 16)
    s = if s < 0, do: s + 16, else: s
    new_left = for row <- 1..8, into: %{} do
      l = Map.get(left, row, 0)
      r = Map.get(right, row, 0)
      combined = (l <<< 8) ||| r
      rotated = (combined >>> s) ||| ((combined &&& ((1 <<< s) - 1)) <<< (16 - s))
      {row, (rotated >>> 8) &&& 0xFF}
    end
    new_right = for row <- 1..8, into: %{} do
      l = Map.get(left, row, 0)
      r = Map.get(right, row, 0)
      combined = (l <<< 8) ||| r
      rotated = (combined >>> s) ||| ((combined &&& ((1 <<< s) - 1)) <<< (16 - s))
      {row, rotated &&& 0xFF}
    end
    {new_left, new_right}
  end

  defp tilt_rows(data, 0), do: data

  defp tilt_rows(data, shift) do
    for row <- 1..8, into: %{} do
      src = Integer.mod(row - shift - 1, 8) + 1
      {row, Map.get(data, src, 0)}
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

  defp stack_digits_led_right(top, bot) do
    top_map = Map.get(@digit_left, top, @digit_left[0])
    bot_map = Map.get(@digit_right, bot, @digit_right[0])
    for row <- 1..8, into: %{} do
      t = Map.get(top_map, row-1, 0)
      b = Map.get(bot_map, row, 0)
      {row, t ||| b}
    end
  end

  defp stack_digits_led_left(top, bot) do
    top_map = Map.get(@digit_left, top, @digit_left[0])
    bot_map = Map.get(@digit_right, bot, @digit_right[0])
    for row <- 1..8, into: %{} do
      t = Map.get(top_map, row, 0)
      b = Map.get(bot_map, row+1, 0)
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
    frame = for r <- 1..8, into: %{} do
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
    cur = for r <- 1..8, into: %{} do
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
    frame = for r <- 1..8, into: %{} do
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
      frame = for row <- 1..8, into: %{} do
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
