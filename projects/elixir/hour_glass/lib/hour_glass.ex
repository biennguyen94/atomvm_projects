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

defmodule HourGlass do
  use Bitwise

  @gpio_scl 22
  @gpio_sda 21

  @mpu9250_addr 0x68
  @acc_addr 0x3B
  @temp_addr 0x41
  @gyro_addr 0x43
  @acc_config_addr 0x1C
  @gyro_config_addr 0x1B
  @base_freq 1_000_000

  @acc_full_scale_2_g 0x00
  @acc_full_scale_4_g 0x08
  @acc_full_scale_8_g 0x10
  @acc_full_scale_16_g 0x18

  @num_byte 4
  @acc_scale 4.8828125e-4
  @radian_to_degree 57.2957795

  @top :top
  @bot :bot
  @left :left
  @right :right
  @middle :mid
  @max_row 15

  @yes 1
  @no -1

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

  @led0 0
  @led1 1

  @spisettings [
    bus_config: [
      miso: 19,
      mosi: 27,
      sclk: 5
    ],
    device_config: [
      device_1: [
        clock_speed_hz: 1_000_000,
        mode: 0,
        cs: 18,
        address_len_bits: 8
      ],
      device_2: [
        clock_speed_hz: 1_000_000,
        mode: 0,
        cs: 23,
        address_len_bits: 8
      ]
    ]
  ]

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

  @default_matrix %{
    @digit_0 => 0b00111111,
    @digit_1 => 0b00111111,
    @digit_2 => 0b11111111,
    @digit_3 => 0b11111111,
    @digit_4 => 0b11111111,
    @digit_5 => 0b11111111,
    @digit_6 => 0b11111111,
    @digit_7 => 0b11111111
  }

  defstruct [:spi, :data1, :data2, :predata1, :predata2, :direction, :isstop, :timer]

  def start do
    :erlang.system_flag(:schedulers_online, 2)
    i2c = i2c_init()
    mpu_config(i2c)
    {:ok, pid} = GenServer.start(__MODULE__, [])
    spawn(__MODULE__, :hour_glass, [pid])
    read(pid, i2c, @top)
  end

  def init(_) do
    {:ok, spi} = init_max7219(@spisettings)
    write_digit(spi, @digit_0, @empty_matrix, :device_1)
    write_digit(spi, @digit_0, @default_matrix, :device_2)
    state = %__MODULE__{spi: spi, data1: @empty_matrix, data2: @default_matrix, timer: 0,
                        predata1: @empty_matrix, predata2: @default_matrix, direction: :top, isstop: false}
    IO.puts("Init SPI and MAX7219 OK\n")
    {:ok, state}
  end

  def handle_call(:print_test, _from, state) do
    if state.isstop do
      {:reply, :ok, state}
    else
      {new_data1, new_data2} = update_data(0, state.spi, state.data1, state.data2, state.direction)

      {timer, flag, last_data1, last_data2} =
        if state.timer == 1 do
          {0, true, elem(drop_seed(state.spi, state.direction, new_data1, new_data2), 0),
            elem(drop_seed(state.spi, state.direction, new_data1, new_data2), 1)}
        else
          {state.timer + 1, false, new_data1, new_data2}
        end

      condition = ((last_data1 == state.predata1) and (last_data2 == state.predata2)) and flag

      new_state =
        if condition do
          IO.puts("END")
          %{state | data1: last_data1, data2: last_data2, timer: 0,
                    predata1: @empty_matrix, predata2: @empty_matrix, direction: state.direction, isstop: true}
        else
          %{state | data1: last_data1, data2: last_data2,
                    predata1: state.data1, predata2: state.data2, timer: timer}
        end

      {:reply, :ok, new_state}
    end
  end

  def handle_call(_msg, _from, state), do: {:reply, :ok, state}

  def handle_cast({:change_direction, dir}, state) do
    new_state = %{state | direction: dir, isstop: false, predata1: @empty_matrix, predata2: @empty_matrix}
    {:noreply, new_state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  def terminate(_reason, _state), do: :ok

  # Hour Glass Control

  defp get_left({x, y}), do: {x - 1, y}
  defp get_right({x, y}), do: {x, y + 1}
  defp get_down({x, y}), do: {x - 1, y + 1}

  defp get_x_y_raw(data, {x, y}) do
    row = Map.get(data, x + 1)
    temp = (row <<< y) &&& 128

    if temp == 128, do: @yes, else: @no
  end

  defp get_x_y(data, {x, y}, dir) do
    {new_x, new_y} = transform({x, y}, dir)
    get_x_y_raw(data, {new_x, new_y})
  end

  defp set_x_y(spi, device, data, {x, y}, dir, @yes) do
    {new_x, new_y} = transform({x, y}, dir)
    set_x_y_raw(spi, device, data, {new_x, new_y}, @yes)
  end

  defp set_x_y(spi, device, data, {x, y}, dir, @no) do
    {new_x, new_y} = transform({x, y}, dir)
    set_x_y_raw(spi, device, data, {new_x, new_y}, @no)
  end

  defp set_x_y_raw(spi, device, data, {x, y}, @yes) do
    row = Map.get(data, x + 1)
    temp = (128 >>> y) ||| row
    write_register(spi, x + 1, temp, device)
    Map.put(data, x + 1, temp)
  end

  defp set_x_y_raw(spi, device, data, {x, y}, @no) do
    row = Map.get(data, x + 1)
    temp = (~~~(128 >>> y)) &&& row
    write_register(spi, x + 1, temp, device)
    Map.put(data, x + 1, temp)
  end

  defp transform({x, y}, dir) do
    cond do
      dir == :right -> rotate_right({x, y})
      dir == :top -> rotate_top({x, y})
      dir == :left -> rotate_left({x, y})
      true -> {x, y}
    end
  end

  defp flip_horizontally({x, y}), do: {7 - x, y}
  defp flip_vertically({x, y}), do: {x, 7 - y}
  defp rotate_right({x, y}), do: {x, y} |> then(fn {nx, ny} -> {ny, nx} end) |> flip_horizontally()
  defp rotate_top({x, y}), do: {x, y} |> flip_horizontally() |> flip_vertically()
  defp rotate_left({x, y}), do: {x, y} |> rotate_right() |> rotate_top()

  defp can_go_left(data, {x, y}, dir) do
    if x == 0, do: @no, else: 0 - get_x_y(data, get_left({x, y}), dir)
  end

  defp can_go_right(data, {x, y}, dir) do
    if y == 7, do: @no, else: 0 - get_x_y(data, get_right({x, y}), dir)
  end

  defp can_go_down(data, {x, y}, dir) do
    cond0 = can_go_left(data, {x, y}, dir)
    cond1 = can_go_right(data, {x, y}, dir)

    cond do
      y == 7 -> @no
      x == 0 -> @no
      cond0 == @no -> @no
      cond1 == @no -> @no
      true -> 0 - get_x_y(data, get_down({x, y}), dir)
    end
  end

  defp go_down(spi, dev, data, {x, y}, dir) do
    del_seed = set_x_y(spi, dev, data, {x, y}, dir, @no)
    set_x_y(spi, dev, del_seed, get_down({x, y}), dir, @yes)
  end

  defp go_left(spi, dev, data, {x, y}, dir) do
    del_seed = set_x_y(spi, dev, data, {x, y}, dir, @no)
    set_x_y(spi, dev, del_seed, get_left({x, y}), dir, @yes)
  end

  defp go_right(spi, dev, data, {x, y}, dir) do
    del_seed = set_x_y(spi, dev, data, {x, y}, dir, @no)
    set_x_y(spi, dev, del_seed, get_right({x, y}), dir, @yes)
  end

  defp toggle_x_y(spi, dev, data, {x, y}) do
    set_x_y_raw(spi, dev, data, {x, y}, 0 - get_x_y_raw(data, {x, y}))
  end

  defp move_seed(spi, dev, data, {x, y}, dir) do
    is_exit = get_x_y(data, {x, y}, dir)
    left = can_go_left(data, {x, y}, dir)
    right = can_go_right(data, {x, y}, dir)
    down = can_go_down(data, {x, y}, dir)
    cond0 = (left == @no) and (right == @no)
    cond1 = (left == @no) and (right == @yes)
    cond2 = (left == @yes) and (right == @no)
    cond3 = rand_led() == 1

    cond do
      is_exit == @no -> data
      cond0 -> data
      down == @yes -> go_down(spi, dev, data, {x, y}, dir)
      cond1 -> go_right(spi, dev, data, {x, y}, dir)
      cond2 or cond3 -> go_left(spi, dev, data, {x, y}, dir)
      true -> go_right(spi, dev, data, {x, y}, dir)
    end
  end

  defp drop_seed(spi, dir, data1, data2) do
    cond0 = (dir == @top) or (dir == @bot)
    temp0 = get_x_y_raw(data1, {0, 7})
    temp1 = get_x_y_raw(data2, {7, 0})
    cond1 = (temp0 == @yes) and (temp1 == @no)
    cond2 = (temp0 == @no) and (temp1 == @yes)
    condition = cond0 and (cond1 or cond2)

    if condition do
      new_data1 = toggle_x_y(spi, :device_1, data1, {0, 7})
      new_data2 = toggle_x_y(spi, :device_2, data2, {7, 0})
      {new_data1, new_data2}
    else
      {data1, data2}
    end
  end

  defp update_data(@max_row, _spi, data1, data2, _dir), do: {data1, data2}

  defp update_data(num, spi, data1, data2, dir) do
    rand = rand_led()

    it =
      if num < 8 do
        0
      else
        num - 7
      end

    {new_data1, new_data2} = update_x_y(num, rand, it, num - it + 1, spi, data1, data2, dir)
    update_data(num + 1, spi, new_data1, new_data2, dir)
  end

  defp update_x_y(_num, _rand, it, it, _spi, data1, data2, _dir), do: {data1, data2}

  defp update_x_y(num, 1, times, it, spi, data1, data2, dir) do
    y = num - times
    x = 7 - times
    {{x1, y1}, {x2, y2}} = get_position({x, y}, dir)
    new_data1 = move_seed(spi, :device_1, data1, {x1, y1}, dir)
    new_data2 = move_seed(spi, :device_2, data2, {x2, y2}, dir)
    update_x_y(num, 1, times + 1, it, spi, new_data1, new_data2, dir)
  end

  defp update_x_y(num, 0, times, it, spi, data1, data2, dir) do
    y = times
    x = 7 - (num - times)
    {{x1, y1}, {x2, y2}} = get_position({x, y}, dir)
    new_data1 = move_seed(spi, :device_1, data1, {x1, y1}, dir)
    new_data2 = move_seed(spi, :device_2, data2, {x2, y2}, dir)
    update_x_y(num, 0, times + 1, it, spi, new_data1, new_data2, dir)
  end

  defp rand_led do
    value = :atomvm.random()
    if value >= 0, do: 1, else: 0
  end

  defp get_position({x, y}, dir) do
    cond do
      dir == @top -> {{x, y}, {y, x}}
      dir == @bot -> {{y, x}, {x, y}}
      dir == @left ->
        new_y = rem(y + 7, 8)
        {{new_y, x}, {new_y, x}}
      true ->
        new_x = rem(x + 7, 8)
        {{y, new_x}, {y, new_x}}
    end
  end

  # SPI and MAX7219 part

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

  # MPU part

  defp i2c_init do
    I2C.open(scl: @gpio_scl, sda: @gpio_sda, clock_speed_hz: @base_freq)
  end

  defp mpu_config(i2c) do
    mpu_send_command(i2c, @acc_config_addr, @acc_full_scale_16_g)
  end

  defp mpu_send_command(i2c, register, command) do
    I2C.begin_transmission(i2c, @mpu9250_addr)
    I2C.write_byte(i2c, register)
    I2C.write_byte(i2c, command)
    I2C.end_transmission(i2c)
  end

  def mpu_read_data(i2c) do
    I2C.begin_transmission(i2c, @mpu9250_addr)
    I2C.write_byte(i2c, @acc_addr)
    I2C.end_transmission(i2c)
    I2C.read_bytes(i2c, @mpu9250_addr, @num_byte)
  end

  def read(pid, i2c, dir) do
    {:ok, val} = mpu_read_data(i2c)
    <<acc_x::16-integer-signed, acc_y::16-integer-signed>> = val

    angle = :math.atan2(acc_x * @acc_scale, acc_y * @acc_scale) * @radian_to_degree
    direction = get_direction(angle)
    condition = (dir != direction) and (direction != @middle)

    if condition do
      IO.puts("Send Request")
      GenServer.cast(pid, {:change_direction, direction})
      Process.sleep(100)
      read(pid, i2c, direction)
    else
      Process.sleep(100)
      read(pid, i2c, dir)
    end
  end

  defp get_direction(angle) do
    cond0 = (angle <= -80) and (angle >= -100)
    cond1 = (angle <= 180) and (angle >= 160)
    cond2 = (angle <= 10) and (angle >= -10)
    cond3 = (angle <= 90) and (angle >= 80)

    cond do
      cond0 -> @top
      cond1 -> @left
      cond2 -> @right
      cond3 -> @bot
      true -> @middle
    end
  end

  def hour_glass(pid) do
    :ok = GenServer.call(pid, :print_test)
    hour_glass(pid)
  end
end
