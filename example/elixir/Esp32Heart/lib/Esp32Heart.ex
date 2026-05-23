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

defmodule Esp32Heart do
  @no_op 0
  @digit_0 1
  @digit_1 2
  @digit_2 3
  @digit_3 4
  @digit_4 5
  @digit_5 6
  @digit_6 7
  @digit_7 8
  @decode_mode 9
  @intensity 10
  @scan_limit 11
  @shutdown 12
  @display_test 15
  @num_of_bits 8
  @device_name :device_1
  @spi_settings [
    {:bus_config, [
      {:miso, 19},
      {:mosi, 27},
      {:sclk, 5}
    ]},
    {:device_config, [
      {@device_name, [
        {:clock_speed_hz, 1000000},
        {:mode, 0},
        {:cs, 18},
        {:address_len_bits, 8}
      ]}
    ]}
  ]

  def start do
    {:ok, pid} = :gen_server.start(__MODULE__, [], [])
    :gen_server.call(pid, :init)
  end

  def init(_) do
    {:ok, {}}
  end

  def handle_call(:init, _from, _state) do
    {:ok, spi} = init_max7219(@spi_settings)
    IO.puts("Init SPI and MAX7219 OK")
    display_heart(spi)
    {:reply, :ok, spi}
  end

  def handle_info(_info, state), do: {:noreply, state}
  def handle_cast(_msg, state), do: {:noreply, state}
  def code_change(_old_vsn, state, _extra), do: {:ok, state}
  def terminate(_reason, _state), do: :ok

  defp init_max7219(spi_settings) do
    spi = :spi.open(spi_settings)
    write_register(spi, @decode_mode, 0)
    write_register(spi, @intensity, 1)
    write_register(spi, @scan_limit, 7)
    write_register(spi, @shutdown, 1)
    write_register(spi, @display_test, 0)
    {:ok, spi}
  end

  defp display_heart(spi) do
    heart_list = [
      0b01100110,
      0b11111111,
      0b11111111,
      0b11111111,
      0b01111110,
      0b00111100,
      0b00011000,
      0b00000000
    ]

    :ok = write_digit(spi, heart_list, 1)
  end

  defp write_digit(spi, [data | _], 8) do
    write_register(spi, 8, data)
    :ok
  end

  defp write_digit(spi, [data | tail_list], number) do
    write_register(spi, number, data)
    write_digit(spi, tail_list, number + 1)
  end

  defp write_register(spi, address, data) do
    :spi.write_at(spi, @device_name, address, @num_of_bits, data)
  end
end
