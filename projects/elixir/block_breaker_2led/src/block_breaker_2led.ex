defmodule BlockBreaker2led do
  use GenServer
  use Bitwise

  # ---------------------------------------------------------------------------
  # Constants (originally from global.hrl — fill in actual values as needed)
  # ---------------------------------------------------------------------------
  @spi_settings []
  @gpio_sw 0
  @gpio_vrx 34
  @gpio_vry 35
  # @gpio_resistor 32   # uncomment if variable-resistor path is re-enabled
  @max_speed 500
  @min_speed 100
  @bit_resolution 4095
  @cross_bar %{0 => {0, {0, 0}}, 1 => {0, {1, 0}}, 2 => {0, {2, 0}}}
  @empty_matrix %{1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0}
  @ball %{0 => {0, {3, 4}}}
  @default_point %{}
  @max_point 10
  @digit_0 1
  @decode_mode 0x09
  @intensity 0x0A
  @scan_limit 0x0B
  @shutdown 0x0C
  @display_test 0x0F
  @num_of_bits 8
  @low_range 1000
  @high_range 3000
  @delay_read_adc 100
  @led0 0
  @led1 1
  # Number bitmaps — replace with real data from global.hrl
  @number_0 %{1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0}
  @number_1 @number_0
  @number_2 @number_0
  @number_3 @number_0
  @number_4 @number_0
  @number_5 @number_0
  @number_6 @number_0
  @number_7 @number_0
  @number_8 @number_0
  @number_9 @number_0
  # Scrolling text bitmaps — replace with real data from global.hrl
  @breaker_game %{}
  @game_over %{}
  @game_win %{}

  # ---------------------------------------------------------------------------
  # State struct (replaces the -record(state, ...) in global.hrl)
  # ---------------------------------------------------------------------------
  defstruct spi: nil,
            goverproc: nil,
            isgameover: false,
            crossbar: nil,
            data1: nil,
            data2: nil,
            score: 0,
            point: nil,
            ball: nil,
            direction: {-1, 1}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start do
    :erlang.system_flag(:schedulers_online, 2)
    {:ok, p} = GenServer.start(__MODULE__, [], [])
    {adcx, adcy} = setup_adc()
    spawn(__MODULE__, :joystick, [p, adcx, adcy])

    # TEMPORARY: variable-resistor reading disabled (unstable ADC values)
    # :ok = :esp_adc.start(@gpio_resistor)
    # spawn(__MODULE__, :variable_resistor, [self(), @gpio_resistor, @max_speed])

    ball(p, 150)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_) do
    {:ok, spi} = init_max7219(@spi_settings)
    init_sw_interrupt()
    new_proc = spawn(__MODULE__, :welcome_block_breaker_game_process, [self(), 0])
    state = %__MODULE__{spi: spi, goverproc: new_proc, isgameover: true}
    :io.format("Init SPI and MAX7219 OK ~p ~n", [@cross_bar])
    {:ok, state}
  end

  @impl true
  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  # Update the LED matrix with all current game objects
  def handle_cast(:update_game, state) do
    {temp1, temp2} = update_data(state.crossbar, {state.data1, state.data2}, 0, 3)
    {temp3, temp4} = update_data(state.ball, {temp1, temp2}, 0, 1)
    {temp5, temp6} = update_data(state.point, {temp3, temp4}, 0, @max_point)
    write_digit(state.spi, @digit_0, temp5, :device_1)
    write_digit(state.spi, @digit_0, temp6, :device_2)
    {:noreply, %{state | data1: temp5, data2: temp6}}
  end

  # Reset all game state to defaults
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

  # Move the crossbar left (-1) or right (1) based on joystick input
  def handle_cast({:move_cross_bar, direc}, state) do
    if state.isgameover do
      {:noreply, state}
    else
      {new_cross_bar, flag} = update_cross_bar(state.crossbar, direc)
      new_state =
        if flag do
          temp1 = remove_current_crossbar(state.data1, 1)
          temp2 = remove_current_crossbar(state.data2, 1)
          {data1, data2} = update_data(new_cross_bar, {temp1, temp2}, 0, 3)
          write_digit(state.spi, @digit_0, data1, :device_1)
          write_digit(state.spi, @digit_0, data2, :device_2)
          %{state | data1: data1, data2: data2, crossbar: new_cross_bar}
        else
          state
        end
      {:noreply, new_state}
    end
  end

  # Advance the ball one step; handles game-over, win, and normal movement
  def handle_cast(:move_ball, state) do
    new_state =
      if state.isgameover do
        state
      else
        ball = state.ball[0]

        {new_ball, new_direc, game_over, new_point, new_score} =
          move_ball(ball, state.direction, state.crossbar, state.point, state.score)

        cond do
          game_over ->
            :io.format("GAME OVER ~n")
            :timer.sleep(500)
            {data1, data2} = handle_game_over(state.score)
            write_digit(state.spi, @digit_0, data1, :device_1)
            write_digit(state.spi, @digit_0, data2, :device_2)
            :timer.sleep(2000)
            new_proc = spawn(__MODULE__, :game_over_process, [self(), 0, 0])
            %{state | isgameover: true, goverproc: new_proc}

          new_score == @max_point ->
            :io.format("GAME WIN ~n")
            :timer.sleep(500)
            {data1, data2} = handle_game_over(new_score)
            write_digit(state.spi, @digit_0, data1, :device_1)
            write_digit(state.spi, @digit_0, data2, :device_2)
            :timer.sleep(2000)
            new_proc = spawn(__MODULE__, :game_win_process, [self(), 0])
            %{state | isgameover: true, goverproc: new_proc}

          true ->
            {data1, data2} = update_ball(new_ball, ball, state.data1, state.data2)
            write_digit(state.spi, @digit_0, data1, :device_1)
            write_digit(state.spi, @digit_0, data2, :device_2)
            %{state |
              ball: %{0 => new_ball},
              data1: data1,
              data2: data2,
              direction: new_direc,
              point: new_point,
              score: new_score
            }
        end
      end
    {:noreply, new_state}
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

  @impl true
  # Hardware button interrupt — reset the game
  def handle_info({:gpio_interrupt, @gpio_sw}, state) do
    :io.format("receive interrupt~n")
    if is_pid(state.goverproc), do: send(state.goverproc, :stop)
    GenServer.cast(self(), :reset_game)
    GenServer.cast(self(), :update_game)
    {:noreply, state}
  end

  def handle_info(:back_to_welcome, state) do
    :io.format("receive back_to_welcome~n")
    if is_pid(state.goverproc), do: send(state.goverproc, :stop)
    new_proc = spawn(__MODULE__, :welcome_block_breaker_game_process, [self(), 0])
    {:noreply, %{state | isgameover: true, goverproc: new_proc}}
  end

  @impl true
  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  @impl true
  def terminate(_reason, _state), do: :ok

  # ---------------------------------------------------------------------------
  # SPI / MAX7219 helpers
  # ---------------------------------------------------------------------------

  defp init_max7219(spi_settings) do
    spi = :spi.open(spi_settings)
    for device <- [:device_1, :device_2] do
      write_register(spi, @decode_mode, 0x0, device)   # No decoding
      write_register(spi, @intensity, 0x3, device)     # Brightness intensity
      write_register(spi, @scan_limit, 0x7, device)    # Scan limit = 8 LEDs
      write_register(spi, @shutdown, 0x1, device)      # Normal operation mode
      write_register(spi, @display_test, 0x0, device)  # No display test
    end
    {:ok, spi}
  end

  # Base case: all entries processed
  defp update_data(_map, data, len, len), do: data

  defp update_data(map, data, number, len) do
    {id, element} = map[number]
    device = get_device(id)
    previous_data = get_device_data(device, data)
    new_data =
      if element != {-1, -1} do
        write_element(element, previous_data)
      else
        previous_data
      end
    update_data(map, get_return_data(data, new_data, device), number + 1, len)
  end

  # Write a single {x, y} pixel into the row-data map
  defp write_element({x, y}, data) do
    new_bit = 128 >>> y
    current_row = data[x + 1]
    Map.put(data, x + 1, new_bit ||| current_row)
  end

  # Recursively write rows 1-8 to the MAX7219
  defp write_digit(spi, 8, data, device) do
    write_register(spi, 8, data[8], device)
    :ok
  end

  defp write_digit(spi, number, data, device) do
    write_register(spi, number, data[number], device)
    write_digit(spi, number + 1, data, device)
  end

  defp write_register(spi, address, data, device) do
    :spi.write_at(spi, device, address, @num_of_bits, data)
  end

  defp get_device(0), do: :device_1
  defp get_device(1), do: :device_2

  defp get_device_data(:device_1, {data1, _data2}), do: data1
  defp get_device_data(:device_2, {_data1, data2}), do: data2

  defp get_return_data({_data1, data2}, new_data, :device_1), do: {new_data, data2}
  defp get_return_data({data1, _data2}, new_data, :device_2), do: {data1, new_data}

  # ---------------------------------------------------------------------------
  # Crossbar control
  # ---------------------------------------------------------------------------

  defp update_cross_bar(cross_bar, direction) do
    {id1, {first, y1}} = cross_bar[0]
    {id2, {middle, y2}} = cross_bar[1]
    {id3, {last, y3}} = cross_bar[2]

    cond1 = first == 0 and direction == -1 and id1 == 0
    cond2 = last == 7  and direction == 1  and id3 == 1
    cond3 = first == 0 and direction == -1 and id1 == 1
    cond4 = last == 7  and direction == 1  and id3 == 0

    cond do
      # Already at the hard boundary — do not move
      cond1 or cond2 ->
        {cross_bar, false}

      # Crossbar crosses from LED1 boundary back into LED0
      cond3 ->
        new_cross_bar = %{
          0 => {0, {7, 0}},
          1 => {id1, {first, y1}},
          2 => {id2, {middle, y2}}
        }
        {new_cross_bar, true}

      # Crossbar crosses from LED0 boundary into LED1
      cond4 ->
        new_cross_bar = %{
          0 => {id2, {middle, y2}},
          1 => {id3, {last, y3}},
          2 => {1, {0, 0}}
        }
        {new_cross_bar, true}

      # Normal slide within the same display(s)
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

  # Clear the bottom pixel row used by the crossbar (row index 1..8)
  defp remove_current_crossbar(map, 9), do: map

  defp remove_current_crossbar(map, number) do
    row = map[number] &&& (~~~128)
    remove_current_crossbar(Map.put(map, number, row), number + 1)
  end

  # ---------------------------------------------------------------------------
  # Ball logic
  # ---------------------------------------------------------------------------

  defp move_ball({id, {x, y}}, {dir_x, dir_y}, cross_bar, point, score) do
    {flag, direction_x, direction_y, x1, y1, temp_id} =
      is_game_over({id, {x, y}}, {dir_x, dir_y}, cross_bar)

    {is_collision, pos} = is_collision(point, 0, {id, {x1, y1}})

    if is_collision do
      # Ball hit a block — reverse direction and remove the block
      new_x     = x1 - direction_x
      new_y     = y1 - direction_y
      new_dir_x = -direction_x
      new_dir_y = -direction_y
      new_point = Map.put(point, pos, {-1, -1})

      cond do
        new_x == -1 ->
          {{@led0, {7, new_y}}, {new_dir_x, new_dir_y}, flag, new_point, score + 1}
        new_x == 8 ->
          {{@led1, {0, new_y}}, {new_dir_x, new_dir_y}, flag, new_point, score + 1}
        true ->
          {{temp_id, {new_x, new_y}}, {new_dir_x, new_dir_y}, flag, new_point, score + 1}
      end
    else
      # No collision — advance position normally
      {new_x, new_dir_x, new_id} =
        cond do
          x1 == 7 and id == @led1               -> {6, -1, temp_id}
          x1 == 0 and id == @led0               -> {1, 1, temp_id}
          x1 == 7 and id == @led0 and direction_x == 1  -> {0, direction_x, @led1}
          x1 == 0 and id == @led1 and direction_x == -1 -> {7, direction_x, @led0}
          true                                  -> {x1 + direction_x, direction_x, temp_id}
        end

      {new_y, new_dir_y} =
        cond do
          y1 == 1 -> {2, 1}
          y1 == 7 -> {6, -1}
          true    -> {y1 + direction_y, direction_y}
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

  # Compare ball position against the crossbar and determine outcome.
  # Returns {game_over?, new_dir_x, new_dir_y, ball_x, ball_y, led_id}
  defp compare_crossbar({id, {ball_x, ball_y}} = ball, {dir_x, dir_y}, cross_bar) do
    temp0 = cross_bar[0]
    temp1 = cross_bar[1]
    temp2 = cross_bar[2]

    ball_1 = {id, {ball_x, ball_y - 1}}
    ball_2 = {id, {ball_x + dir_x, ball_y + dir_y}}

    # Corner case: ball crosses LED boundary outside the crossbar
    cond_a = ball == {@led1, {0, 1}} and temp2 == {@led0, {7, 0}} and {dir_x, dir_y} == {-1, -1}
    cond_0 = ball == {@led0, {7, 1}} and temp0 == {@led1, {0, 0}} and {dir_x, dir_y} == {1, -1}
    cond_1 = ball_1 == temp1                      # Hits centre of crossbar
    cond_2 = ball_1 == temp0 or ball_1 == temp2   # Hits left/right end of crossbar
    cond_3 = ball_2 == temp0 or ball_2 == temp2   # Outside edge of crossbar
    cond_4 =
      (ball_y == 1 and ball_x == 0 and {0, {ball_x + 1, ball_y - 1}} == temp0) or
      (ball_y == 1 and ball_x == 7 and {1, {ball_x - 1, ball_y - 1}} == temp2)

    cond do
      cond_a or cond_0 ->
        {false, -dir_x, -dir_y, ball_x - dir_x, ball_y, id}

      cond_1 ->
        {false, 0, 1, ball_x, ball_y, id}

      cond_2 ->
        {res1, res2} = handle_change_direc(dir_x, dir_y)
        {false, res1, res2, ball_x, ball_y, id}

      cond_3 ->
        new_ball_x = ball_x - dir_x
        cond do
          new_ball_x == 8  -> {false, -dir_x, -dir_y, 0, ball_y, @led1}
          new_ball_x == -1 -> {false, -dir_x, -dir_y, 7, ball_y, @led0}
          true             -> {false, -dir_x, -dir_y, new_ball_x, ball_y, id}
        end

      cond_4 ->
        {false, -dir_x, -dir_y, ball_x, ball_y, id}

      # Missed the crossbar — game over
      true ->
        {true, dir_x, dir_y, ball_x, ball_y, id}
    end
  end

  # When ball hits edge of crossbar and dir_x == 0, randomly pick a new x direction
  defp handle_change_direc(0, dir_y) do
    if :atomvm.random() > 0, do: {-1, dir_y}, else: {1, dir_y}
  end

  defp handle_change_direc(dir_x, dir_y), do: {dir_x, dir_y}

  defp is_collision(_point, @max_point, _ball), do: {false, -1}

  defp is_collision(point, current, ball) do
    if ball == point[current] do
      {true, current}
    else
      is_collision(point, current + 1, ball)
    end
  end

  defp update_ball({id, {x, y}}, {pre_id, {pre_x, pre_y}}, data1, data2) do
    pre_dev  = get_device(pre_id)
    pre_data = get_device_data(pre_dev, {data1, data2})

    # Erase old ball pixel
    erased_bit = (~~~(128 >>> pre_y)) &&& pre_data[pre_x + 1]
    new_data   = Map.put(pre_data, pre_x + 1, erased_bit)

    if id == pre_id do
      # Ball stays on the same LED matrix
      new_bit     = 128 >>> y
      current_row = new_data[x + 1]
      result      = Map.put(new_data, x + 1, new_bit ||| current_row)
      get_return_data({data1, data2}, result, pre_dev)
    else
      # Ball moved to the other LED matrix
      device      = get_device(id)
      data        = get_device_data(device, {data1, data2})
      new_bit     = 128 >>> y
      current_row = data[x + 1]
      result      = Map.put(data, x + 1, new_bit ||| current_row)
      if device == :device_1, do: {result, new_data}, else: {new_data, result}
    end
  end

  # ---------------------------------------------------------------------------
  # Joystick / ADC
  # ---------------------------------------------------------------------------

  defp init_sw_interrupt do
    :gpio.set_pin_mode(@gpio_sw, :input)
    :gpio.set_pin_pull(@gpio_sw, :up)
    gpio = :gpio.start()
    :gpio.set_int(gpio, @gpio_sw, :rising)
  end

  defp setup_adc do
    :ok = :esp_adc.start(@gpio_vrx)
    :ok = :esp_adc.start(@gpio_vry)
    {@gpio_vrx, @gpio_vry}
  end

  defp read_adc(adc) do
    case :esp_adc.read(adc) do
      {:ok, {raw, _milli_volts}} ->
        {:ok, raw}
      error ->
        :io.format("Error taking reading: ~p~n", [error])
    end
  end

  # Polling loop: reads X axis and sends crossbar-move casts
  def joystick(pid, adcx, adcy) do
    {:ok, x} = read_adc(adcx)
    cond do
      x < @low_range  -> GenServer.cast(pid, {:move_cross_bar, -1})
      x > @high_range -> GenServer.cast(pid, {:move_cross_bar, 1})
      true            -> :nothing_changed
    end
    :timer.sleep(@delay_read_adc)
    joystick(pid, adcx, adcy)
  end

  # ---------------------------------------------------------------------------
  # Score display
  # ---------------------------------------------------------------------------

  defp handle_game_over(score) do
    {get_num_macro(div(score, 10)), get_num_macro(rem(score, 10))}
  end

  defp get_num_macro(n) do
    case n do
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
    data1 = build_display_data(@empty_matrix, 1, times, command)
    data2 = build_display_data(@empty_matrix, 1, times + 8, command)
    write_digit(spi, @digit_0, data1, :device_1)
    write_digit(spi, @digit_0, data2, :device_2)
  end

  # Base case: all 8 rows have been written
  defp build_display_data(result, 9, _times, _command), do: result

  defp build_display_data(result, number, times, :welcome) do
    row = @breaker_game[number + times]
    build_display_data(Map.put(result, number, row), number + 1, times, :welcome)
  end

  defp build_display_data(result, number, times, :lose) do
    row = @game_over[number + times]
    build_display_data(Map.put(result, number, row), number + 1, times, :lose)
  end

  defp build_display_data(result, number, times, :win) do
    row = @game_win[number + times]
    build_display_data(Map.put(result, number, row), number + 1, times, :win)
  end

  # ---------------------------------------------------------------------------
  # Spawned process callbacks
  # ---------------------------------------------------------------------------

  # Scrolls the GAME OVER text; after two full loops sends back_to_welcome
  def game_over_process(p, times, count_reset_to_welcome) do
    receive do
      :stop -> :ok
    after 200 ->
      GenServer.cast(p, {:display_game_over, times})

      {new_times, new_count} =
        if times + 1 == 61 do
          {0, count_reset_to_welcome + 1}
        else
          {times + 1, count_reset_to_welcome}
        end

      # Check old count (before this iteration's increment)
      if count_reset_to_welcome == 1, do: send(p, :back_to_welcome)

      game_over_process(p, new_times, new_count)
    end
  end

  # Scrolls the BREAKER GAME welcome text indefinitely until stopped
  def welcome_block_breaker_game_process(p, times) do
    receive do
      :stop -> :ok
    after 200 ->
      GenServer.cast(p, {:display_breaker_game, times})
      new_times = if times + 1 == 75, do: 0, else: times + 1
      welcome_block_breaker_game_process(p, new_times)
    end
  end

  # Scrolls the GAME WIN text indefinitely until stopped
  def game_win_process(p, times) do
    receive do
      :stop -> :ok
    after 200 ->
      GenServer.cast(p, {:display_game_win, times})
      new_times = if times + 1 == 27, do: 0, else: times + 1
      game_win_process(p, new_times)
    end
  end

  # Reads the variable resistor and sends speed updates to the parent process
  def variable_resistor(parent, adc, previous_speed) do
    {:ok, speed} = read_adc(adc)
    mapped_speed = map_range(speed, 0, @bit_resolution, @max_speed, @min_speed)
    new_speed =
      if is_not_in_range(previous_speed, mapped_speed) do
        send(parent, {:newspeed, mapped_speed})
        mapped_speed
      else
        previous_speed
      end
    :timer.sleep(new_speed)
    variable_resistor(parent, adc, new_speed)
  end

  # Returns true when new_val falls outside the ±10 tolerance band of pre_val.
  # This filters out ADC noise on the potentiometer.
  defp is_not_in_range(pre_val, new_val) do
    not (new_val >= pre_val - 10 and new_val <= pre_val + 10)
  end

  defp map_range(value, in_low, in_high, out_low, out_high) do
    round((value - in_low) * (out_high - out_low) / (in_high - in_low) + out_low)
  end

  # Ball timing loop — listens for speed changes, then triggers a move
  def ball(pid, pre_speed) do
    new_speed =
      receive do
        {:newspeed, speed} -> speed
      after pre_speed ->
        pre_speed
      end
    GenServer.cast(pid, :move_ball)
    ball(pid, new_speed)
  end
end
