defmodule HourGlass do
  @moduledoc false

  use GenServer
  import Bitwise

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
  @bottom :bot
  @left :left
  @right :right
  @middle :mid
  @max_row 15

  @yes 1
  @no -1

  @no_op 0x00
  @digit_0 0x01
  @digit_1 0x02
  @digit_2 0x03
  @digit_3 0x04
  @digit_4 0x05
  @digit_5 0x06
  @digit_6 0x07
  @digit_7 0x08
  @decode_mode 0x09
  @intensity 0x0A
  @scan_limit 0x0B
  @shutdown 0x0C
  @display_test 0x0F

  @num_of_bits 8

  @spi_settings [
    {:bus_config, [
      {:miso, 19},
      {:mosi, 27},
      {:sclk, 5}
    ]},
    {:device_config, [
      {:device_1, [
        {:clock_speed_hz, 1_000_000},
        {:mode, 0},
        {:cs, 18},
        {:address_len_bits, 8}
      ]},
      {:device_2, [
        {:clock_speed_hz, 1_000_000},
        {:mode, 0},
        {:cs, 23},
        {:address_len_bits, 8}
      ]}
    ]}
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
    @digit_0 => 0b00111111,
    @digit_1 => 0b00111111,
    @digit_2 => 0b11111111,
    @digit_3 => 0b11111111,
    @digit_4 => 0b11111111,
    @digit_5 => 0b11111111,
    @digit_6 => 0b11111111,
    @digit_7 => 0b11111111
  }

  defstruct spi: nil,
            data1: @empty_matrix,
            data2: @default_matrix,
            predata1: @empty_matrix,
            predata2: @empty_matrix,
            direction: @top,
            isstop: false,
            timer: 0

  def start do
    :erlang.system_flag(:schedulers_online, 2)
    i2c = i2c_init()
    mpu_config(i2c)
    {:ok, pid} = GenServer.start(__MODULE__, [], [])
    spawn(__MODULE__, :hour_glass, [pid])
    read(pid, i2c, @top)
  end

  @impl true
  def init(_) do
    {:ok, spi} = init_max7219(@spi_settings)

    write_digit(spi, @digit_0, @empty_matrix, :device_1)
    write_digit(spi, @digit_0, @default_matrix, :device_2)

    state = %__MODULE__{
      spi: spi,
      data1: @empty_matrix,
      data2: @default_matrix,
      predata1: @empty_matrix,
      predata2: @empty_matrix,
      direction: @top,
      isstop: false,
      timer: 0
    }

    IO.puts("Init SPI and MAX7219 OK\n")
    {:ok, state}
  end

  @impl true
  def handle_call(:print_test, _from, state) do
    new_state =
      if state.isstop do
        state
      else
        {new_data1, new_data2} =
          update_data(0, state.spi, state.data1, state.data2, state.direction)

        {timer, flag, last_data_pair} =
          if state.timer == 1 do
            {0, true, drop_seed(state.spi, state.direction, new_data1, new_data2)}
          else
            {state.timer + 1, false, {new_data1, new_data2}}
          end

        {last_data1, last_data2} = last_data_pair

        condition = last_data1 == state.predata1 and last_data2 == state.predata2 and flag

        if condition do
          IO.puts("END")

          %__MODULE__{
            state
            | data1: last_data1,
              data2: last_data2,
              timer: 0,
              predata1: @empty_matrix,
              predata2: @empty_matrix,
              isstop: true
          }
        else
          %__MODULE__{
            state
            | data1: last_data1,
              data2: last_data2,
              predata1: state.data1,
              predata2: state.data2,
              timer: timer
          }
        end
      end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(_msg, _from, state), do: {:reply, :ok, state}

  @impl true
  def handle_cast({:change_direction, dir}, state) do
    new_state = %__MODULE__{state | direction: dir, isstop: false, predata1: @empty_matrix, predata2: @empty_matrix}
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  @impl true
  def terminate(_reason, _state), do: :ok

  defp get_left({x, y}), do: {x - 1, y}
  defp get_right({x, y}), do: {x, y + 1}
  defp get_down({x, y}), do: {x - 1, y + 1}

  defp get_x_y_raw(data, {x, y}) do
    row = Map.fetch!(data, x + 1)
    temp = (row <<< y) &&& 128

    if temp == 128, do: @yes, else: @no
  end

  defp get_x_y(data, point, dir) do
    {new_x, new_y} = transform(point, dir)
    get_x_y_raw(data, {new_x, new_y})
  end

  defp set_x_y(spi, device, data, point, dir, @yes) do
    {new_x, new_y} = transform(point, dir)
    set_x_y_raw(spi, device, data, {new_x, new_y}, @yes)
  end

  defp set_x_y(spi, device, data, point, dir, @no) do
    {new_x, new_y} = transform(point, dir)
    set_x_y_raw(spi, device, data, {new_x, new_y}, @no)
  end

  defp set_x_y_raw(spi, device, data, {x, y}, @yes) do
    row = Map.fetch!(data, x + 1)
    temp = (128 >>> y) ||| row
    write_register(spi, x + 1, temp, device)
    Map.put(data, x + 1, temp)
  end

  defp set_x_y_raw(spi, device, data, {x, y}, @no) do
    row = Map.fetch!(data, x + 1)
    temp = bnot(128 >>> y) &&& row
    write_register(spi, x + 1, temp, device)
    Map.put(data, x + 1, temp)
  end

  defp transform(point, dir) do
    cond do
      dir == @right -> rotate_right(point)
      dir == @top -> rotate_top(point)
      dir == @left -> rotate_left(point)
      true -> point
    end
  end

  defp flip_horizontally({x, y}), do: {7 - x, y}
  defp flip_vertically({x, y}), do: {x, 7 - y}

  defp rotate_right({x, y}) do
    {new_x, new_y} = {y, x}
    flip_horizontally({new_x, new_y})
  end

  defp rotate_top(point), do: point |> flip_vertically() |> flip_horizontally()
  defp rotate_left(point), do: rotate_top(rotate_right(point))

  defp can_go_left(data, point, dir) do
    if elem(point, 0) == 0 do
      @no
    else
      0 - get_x_y(data, get_left(point), dir)
    end
  end

  defp can_go_right(data, point, dir) do
    if elem(point, 1) == 7 do
      @no
    else
      0 - get_x_y(data, get_right(point), dir)
    end
  end

  defp can_go_down(data, point, dir) do
    left = can_go_left(data, point, dir)
    right = can_go_right(data, point, dir)

    cond do
      elem(point, 1) == 7 ->
        @no

      elem(point, 0) == 0 ->
        @no

      left == @no ->
        @no

      right == @no ->
        @no

      true ->
        0 - get_x_y(data, get_down(point), dir)
    end
  end

  defp go_down(spi, dev, data, point, dir) do
    del_seed = set_x_y(spi, dev, data, point, dir, @no)
    set_x_y(spi, dev, del_seed, get_down(point), dir, @yes)
  end

  defp go_left(spi, dev, data, point, dir) do
    del_seed = set_x_y(spi, dev, data, point, dir, @no)
    set_x_y(spi, dev, del_seed, get_left(point), dir, @yes)
  end

  defp go_right(spi, dev, data, point, dir) do
    del_seed = set_x_y(spi, dev, data, point, dir, @no)
    set_x_y(spi, dev, del_seed, get_right(point), dir, @yes)
  end

  defp toggle_x_y(spi, dev, data, point) do
    set_x_y_raw(spi, dev, data, point, 0 - get_x_y_raw(data, point))
  end

  defp move_seed(spi, dev, data, point, dir) do
    is_exit = get_x_y(data, point, dir)
    left = can_go_left(data, point, dir)
    right = can_go_right(data, point, dir)
    down = can_go_down(data, point, dir)
    cond do
      is_exit == @no ->
        data

      left == @no and right == @no ->
        data

      down == @yes ->
        go_down(spi, dev, data, point, dir)

      left == @no and right == @yes ->
        go_right(spi, dev, data, point, dir)

      left == @yes and right == @no ->
        go_left(spi, dev, data, point, dir)

      rand_led() == 1 ->
        go_left(spi, dev, data, point, dir)

      true ->
        go_right(spi, dev, data, point, dir)
    end
  end

  defp drop_seed(spi, dir, data1, data2) do
    temp0 = get_x_y_raw(data1, {0, 7})
    temp1 = get_x_y_raw(data2, {7, 0})
    cond0 = dir == @top or dir == @bottom
    cond1 = temp0 == @yes and temp1 == @no
    cond2 = temp0 == @no and temp1 == @yes
    condition = cond0 and (cond1 or cond2)

    if condition do
      {toggle_x_y(spi, :device_1, data1, {0, 7}), toggle_x_y(spi, :device_2, data2, {7, 0})}
    else
      {data1, data2}
    end
  end

  defp update_data(@max_row, _spi, data1, data2, _dir), do: {data1, data2}

  defp update_data(num, spi, data1, data2, dir) do
    it = if num < 8, do: 0, else: num - 7
    {new_data1, new_data2} = update_x_y(num, rand_led(), it, num - it + 1, spi, data1, data2, dir)
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
      dir == @top ->
        {{x, y}, {y, x}}

      dir == @bottom ->
        {{y, x}, {x, y}}

      dir == @left ->
        new_y = rem(y + 7, 8)
        {{new_y, x}, {new_y, x}}

      true ->
        new_x = rem(x + 7, 8)
        {{y, new_x}, {y, new_x}}
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

  defp write_digit(spi, 8, data, device) do
    reg_data = Map.fetch!(data, 8)
    write_register(spi, 8, reg_data, device)
    :ok
  end

  defp write_digit(spi, number, data, device) do
    reg_data = Map.fetch!(data, number)
    write_register(spi, number, reg_data, device)
    write_digit(spi, number + 1, data, device)
  end

  defp write_register(spi, address, data, device) do
    :spi.write_at(spi, device, address, @num_of_bits, data)
  end

  defp i2c_init do
    :i2c.open([{:scl, @gpio_scl}, {:sda, @gpio_sda}, {:clock_speed_hz, @base_freq}])
  end

  defp mpu_config(i2c), do: mpu_send_command(i2c, @acc_config_addr, @acc_full_scale_16_g)

  defp mpu_send_command(i2c, register, command) do
    :i2c.begin_transmission(i2c, @mpu9250_addr)
    :i2c.write_byte(i2c, register)
    :i2c.write_byte(i2c, command)
    :i2c.end_transmission(i2c)
  end

  def mpu_read_data(i2c) do
    :i2c.begin_transmission(i2c, @mpu9250_addr)
    :i2c.write_byte(i2c, @acc_addr)
    :i2c.end_transmission(i2c)
    :i2c.read_bytes(i2c, @mpu9250_addr, @num_byte)
  end

  defp read(pid, i2c, dir) do
    {:ok, val} = mpu_read_data(i2c)
    <<acc_x::16-signed, acc_y::16-signed>> = val

    angle = :math.atan2(acc_x * @acc_scale, acc_y * @acc_scale) * @radian_to_degree
    direction = get_direction(angle)
    condition = dir != direction and direction != @middle

    if condition do
      IO.puts("Send Request")
      GenServer.cast(pid, {:change_direction, direction})
      :timer.sleep(100)
      read(pid, i2c, direction)
    else
      :timer.sleep(100)
      read(pid, i2c, dir)
    end
  end

  defp get_direction(angle) do
    cond do
      angle <= -80 and angle >= -100 -> @top
      angle <= 180 and angle >= 160 -> @left
      angle <= 10 and angle >= -10 -> @right
      angle <= 90 and angle >= 80 -> @bottom
      true -> @middle
    end
  end

  def hour_glass(pid) do
    :ok = GenServer.call(pid, :print_test)
    hour_glass(pid)
  end
end
