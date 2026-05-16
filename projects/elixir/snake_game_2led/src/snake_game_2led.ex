defmodule SnakeGame2Led do
  @moduledoc """
  Snake game for a dual LED matrix (2x MAX7219) driven over SPI.
  Translated from Erlang to Elixir.

  NOTE: The constants below originate from led_matrix.hrl.
  Fill in the real values that match your hardware wiring and font maps.
  """

  use GenServer
  import Bitwise

  # ---------------------------------------------------------------------------
  # Constants (replace with real values from your led_matrix.hrl equivalent)
  # ---------------------------------------------------------------------------

  # GPIO pins
  @gpio_sw 0
  @gpio_vrx 34
  @gpio_vry 35
  # @gpio_resistor 32   # uncomment when variable resistor support is re-enabled

  # ADC thresholds
  @low_range 1000
  @high_range 3000
  @bit_resolution 4095

  # Timing (ms)
  @max_speed 500
  @min_speed 100
  @blink_rate 300
  @delay_read_adc 50

  # LED matrix identifiers
  @led0 0
  @led1 1

  # MAX7219 register addresses
  @decode_mode 0x09
  @intensity 0x0A
  @scan_limit 0x0B
  @shutdown 0x0C
  @display_test 0x0F
  @num_of_bits 16

  # First digit register index used in write_digit/4 calls
  @digit_0 1

  # SPI settings map – fill in bus/device/speed for your hardware
  @spi_settings %{bus: "spi2", device: 0, speed: 10_000_000}

  # Snake defaults
  @snake_length 2
  @direction {1, 0}

  # Default snake head: {matrix_id, {row, col}}
  @head {0, {3, 3}}

  # Default snake body: map of index => {matrix_id, {row, col}}
  # Key 0 = segment nearest head; use {matrix_id, {-1, -1}} for empty slots
  @body %{
    0 => {0, {3, 2}},
    1 => {0, {-1, -1}}
  }

  # Empty 8-row matrix – keys are MAX7219 digit registers 1..8
  @empty_matrix %{1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0}

  # Number bitmaps for score display (8 rows each, keys 1..8)
  # Replace these stubs with your real 8×8 font data
  @number_0 @empty_matrix
  @number_1 @empty_matrix
  @number_2 @empty_matrix
  @number_3 @empty_matrix
  @number_4 @empty_matrix
  @number_5 @empty_matrix
  @number_6 @empty_matrix
  @number_7 @empty_matrix
  @number_8 @empty_matrix
  @number_9 @empty_matrix

  # Scrolling text bitmaps (keys 1..N, 8 rows each strip)
  # Replace with your real scrolling font data
  @snake_game %{}
  @game_over %{}

  # ---------------------------------------------------------------------------
  # Public API / entry point
  # ---------------------------------------------------------------------------

  def start do
    :erlang.system_flag(:schedulers_online, 2)

    {:ok, pid} = GenServer.start(__MODULE__, [], [])

    # Start joystick ADC reader in its own process
    {adc_x, adc_y} = setup_adc()
    spawn(__MODULE__, :joystick, [pid, adc_x, adc_y])

    # Uncomment when variable-resistor support is stable:
    # :ok = :esp_adc.start(@gpio_resistor)
    # spawn(__MODULE__, :variable_resistor, [self(), @gpio_resistor, @max_speed])

    # Start food-blink process
    spawn(__MODULE__, :blink_food, [pid])

    loop(pid, @max_speed)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_args) do
    {:ok, spi} = init_max7219(@spi_settings)
    init_sw_interrupt()
    IO.puts("Init SPI and MAX7219 OK\n")
    new_proc = spawn(__MODULE__, :welcome_snake_game_process, [self(), 0])

    state = %{
      spi: spi,
      gameover: true,
      goverproc: new_proc,
      snakehead: nil,
      snakebody: %{},
      snakelen: 0,
      food: nil,
      direction: @direction,
      data1: @empty_matrix,
      data2: @empty_matrix
    }

    {:ok, state}
  end

  @impl true
  def handle_call(_msg, _from, state), do: {:reply, :ok, state}

  # Change direction – ignore if game over or it would reverse the snake
  @impl true
  def handle_cast({:change_direction, x, y}, state) do
    new_state =
      if state.gameover or is_backward(state, {x, y}) do
        state
      else
        %{state | direction: {x, y}}
      end

    {:noreply, new_state}
  end

  # Advance the snake by one step
  def handle_cast(:move, state) do
    new_state = if state.gameover, do: state, else: move_snake(state)
    {:noreply, new_state}
  end

  # Scroll "GAME OVER" text across the matrices
  def handle_cast({:display_game_over, times}, state) do
    display_game_text(state.spi, times, :lose)
    {:noreply, state}
  end

  # Scroll "SNAKE GAME" text across the matrices
  def handle_cast({:display_snake_game, times}, state) do
    display_game_text(state.spi, times, :welcome)
    {:noreply, state}
  end

  # Blink food – turn off
  def handle_cast(:turn_off_food, state) do
    unless state.gameover do
      turn_off_food(state.spi, state.food, {state.data1, state.data2})
    end

    {:noreply, state}
  end

  # Blink food – turn on
  def handle_cast(:turn_on_food, state) do
    unless state.gameover do
      turn_on_food(state.spi, state.food, {state.data1, state.data2})
    end

    {:noreply, state}
  end

  # Physical button press → reset / start new game
  @impl true
  def handle_info({:gpio_interrupt, @gpio_sw}, state) do
    IO.puts("receive interrupt")
    if is_pid(state.goverproc), do: send(state.goverproc, :stop)

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

  # Return to welcome screen after game-over animation finishes
  def handle_info(:back_to_welcome, state) do
    IO.puts("receive back_to_welcome")
    if is_pid(state.goverproc), do: send(state.goverproc, :stop)

    new_proc = spawn(__MODULE__, :welcome_snake_game_process, [self(), 0])
    {:noreply, %{state | gameover: true, goverproc: new_proc}}
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
      write_register(spi, @decode_mode, 0x0, device)   # No BCD decoding
      write_register(spi, @intensity, 0x3, device)     # Brightness level 3
      write_register(spi, @scan_limit, 0x7, device)    # All 8 digits active
      write_register(spi, @shutdown, 0x1, device)      # Normal operation
      write_register(spi, @display_test, 0x0, device)  # No display test
    end

    {:ok, spi}
  end

  # Write rows 1..8 from a data map into a MAX7219 digit registers.
  # Base case: last row (8)
  defp write_digit(spi, 8, data, device) do
    write_register(spi, 8, Map.get(data, 8), device)
    :ok
  end

  defp write_digit(spi, number, data, device) do
    write_register(spi, number, Map.get(data, number), device)
    write_digit(spi, number + 1, data, device)
  end

  defp write_register(spi, address, data, device) do
    :spi.write_at(spi, device, address, @num_of_bits, data)
  end

  # Map LED index (0 | 1) to device atom
  defp get_device(0), do: :device_1
  defp get_device(1), do: :device_2

  # Extract a single device's data from the pair tuple
  defp get_data(:device_1, {data1, _data2}), do: data1
  defp get_data(:device_2, {_data1, data2}), do: data2

  # Rebuild the pair tuple after updating one device's data
  defp get_return_data({_data1, data2}, new_data, :device_1), do: {new_data, data2}
  defp get_return_data({data1, _data2}, new_data, :device_2), do: {data1, new_data}

  # ---------------------------------------------------------------------------
  # GPIO / interrupt setup
  # ---------------------------------------------------------------------------

  defp init_sw_interrupt do
    :gpio.set_pin_mode(@gpio_sw, :input)
    :gpio.set_pin_pull(@gpio_sw, :up)
    gpio = :gpio.start()
    :gpio.set_int(gpio, @gpio_sw, :rising)
  end

  # ---------------------------------------------------------------------------
  # ADC helpers
  # ---------------------------------------------------------------------------

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
        IO.puts("Error taking ADC reading: #{inspect(error)}")
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Process callbacks (public so spawn/3 can reach them)
  # ---------------------------------------------------------------------------

  # Continuously read joystick and cast direction changes
  def joystick(pid, adc_x, adc_y) do
    {:ok, x} = read_adc(adc_x)
    {:ok, y} = read_adc(adc_y)

    cond do
      x < @low_range  -> GenServer.cast(pid, {:change_direction, -1,  0})
      y < @low_range  -> GenServer.cast(pid, {:change_direction,  0, -1})
      x > @high_range -> GenServer.cast(pid, {:change_direction,  1,  0})
      y > @high_range -> GenServer.cast(pid, {:change_direction,  0,  1})
      true            -> :nothing_changed
    end

    :timer.sleep(@delay_read_adc)
    joystick(pid, adc_x, adc_y)
  end

  # Repeatedly blink the food pixel
  def blink_food(pid) do
    GenServer.cast(pid, :turn_off_food)
    :timer.sleep(@blink_rate)
    GenServer.cast(pid, :turn_on_food)
    :timer.sleep(@blink_rate)
    blink_food(pid)
  end

  # Scroll "GAME OVER" until CountResetToWelcome reaches 1, then go back to welcome
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

      # Check OLD count (before potential increment) – mirrors Erlang logic
      if count_reset_to_welcome == 1, do: send(p, :back_to_welcome)

      game_over_process(p, new_times, new_count)
    end
  end

  # Scroll "SNAKE GAME" indefinitely until stopped
  def welcome_snake_game_process(p, times) do
    receive do
      :stop -> :ok
    after 200 ->
      GenServer.cast(p, {:display_snake_game, times})
      new_times = if times + 1 == 66, do: 0, else: times + 1
      welcome_snake_game_process(p, new_times)
    end
  end

  # Read variable resistor and send speed updates to parent (disabled in start/0)
  def variable_resistor(parent, adc, previous_speed) do
    {:ok, speed} = read_adc(adc)
    mapped = map_range(speed, 0, @bit_resolution, @max_speed, @min_speed)

    new_speed =
      if is_not_in_range(previous_speed, mapped) do
        send(parent, {:newspeed, mapped})
        mapped
      else
        previous_speed
      end

    :timer.sleep(new_speed)
    variable_resistor(parent, adc, new_speed)
  end

  # ---------------------------------------------------------------------------
  # Snake initialisation
  # ---------------------------------------------------------------------------

  defp init_snake(spi, body) do
    {_id, {head_x, head_y}} = @head

    data1 =
      @empty_matrix
      |> Map.put(head_x + 1, 128 >>> head_y)
      |> Map.put(head_x,     128 >>> head_y)

    data2 = @empty_matrix

    {food_id, {food_x, food_y}} = spawn_new_food(body, @snake_length)
    device = get_device(food_id)
    temp_data = get_data(device, {data1, data2})
    row = Map.get(temp_data, food_x + 1) ||| (128 >>> food_y)
    new_data = Map.put(temp_data, food_x + 1, row)

    {res1, res2} = get_return_data({data1, data2}, new_data, device)
    write_digit(spi, @digit_0, res1, :device_1)
    write_digit(spi, @digit_0, res2, :device_2)
    IO.puts("First Food is #{inspect({food_id, {food_x, food_y}})}")

    {@head, @body, {food_id, {food_x, food_y}}, {res1, res2}}
  end

  # ---------------------------------------------------------------------------
  # Snake movement
  # ---------------------------------------------------------------------------

  defp move_snake(state) do
    {id, {x, y}} = state.snakehead
    {dir_x, dir_y} = state.direction
    new_snake_head = handle_border(id, {x + dir_x, y + dir_y})

    {new_len, new_body, new_food} =
      if new_snake_head == state.food do
        # Snake eats food: grow by one and spawn new food
        len  = state.snakelen + 1
        body = update_snake_body(state.snakebody, len, state.food)
        food = spawn_new_food(body, len)
        {len, body, food}
      else
        # Normal move: shift body forward
        len  = state.snakelen
        body = shift_snake(state.snakebody, new_snake_head, len - 1, %{}, 0)
        {len, body, state.food}
      end

    if is_game_over(new_snake_head, new_body, new_len - 1, 0) do
      :timer.sleep(500)
      {data1, data2} = handle_game_over(state.snakelen)
      write_digit(state.spi, @digit_0, data1, :device_1)
      write_digit(state.spi, @digit_0, data2, :device_2)
      :timer.sleep(2000)
      new_proc = spawn(__MODULE__, :game_over_process, [self(), 0, 0])
      %{state | gameover: true, goverproc: new_proc}
    else
      {data1, data2} =
        update_data(new_body, {@empty_matrix, @empty_matrix}, new_food, 0, new_len)

      write_digit(state.spi, @digit_0, data1, :device_1)
      write_digit(state.spi, @digit_0, data2, :device_2)

      %{state |
        snakehead: new_snake_head,
        snakebody: new_body,
        snakelen: new_len,
        food: new_food,
        data1: data1,
        data2: data2
      }
    end
  end

  # Wrap coordinates at matrix borders; crossing right/left also switches matrix
  defp handle_border(id, {x, y}) do
    cond do
      x > 7 and id == @led0 -> {@led1, {0, y}}
      x > 7 and id == @led1 -> {@led0, {0, y}}
      x < 0 and id == @led0 -> {@led1, {7, y}}
      x < 0 and id == @led1 -> {@led0, {7, y}}
      y > 7                  -> {id, {x, 0}}
      y < 0                  -> {id, {x, 7}}
      true                   -> {id, {x, y}}
    end
  end

  # Append the eaten food position to the tail of the snake body
  defp update_snake_body(snake_body, snake_len, food) do
    Map.put(snake_body, snake_len - 1, food)
  end

  # Shift all body segments forward; new head becomes index 0
  # Base case: we have filled up to snake_len
  defp shift_snake(_snake_body, snake_head, snake_len, previous_body, snake_len) do
    Map.put(previous_body, snake_len, snake_head)
  end

  defp shift_snake(snake_body, snake_head, snake_len, previous_body, number) do
    next_ele    = Map.get(snake_body, number + 1)
    new_body    = Map.put(previous_body, number, next_ele)
    shift_snake(snake_body, snake_head, snake_len, new_body, number + 1)
  end

  # ---------------------------------------------------------------------------
  # Matrix data builders
  # ---------------------------------------------------------------------------

  # Base case: all body segments written, now write the food pixel
  defp update_data(_map, data, {id, {x, y}}, len, len) do
    device   = get_device(id)
    temp     = get_data(device, data)
    new_data = write_element({x, y}, temp)
    get_return_data(data, new_data, device)
  end

  defp update_data(map, data, food, number, len) do
    {id, element} = Map.get(map, number)
    device        = get_device(id)
    prev_data     = get_data(device, data)

    new_data =
      if element != {-1, -1},
        do: write_element(element, prev_data),
        else: prev_data

    return_data = get_return_data(data, new_data, device)
    update_data(map, return_data, food, number + 1, len)
  end

  # Set a single pixel in a row-data map
  defp write_element({x, y}, data) do
    mask        = 128 >>> y
    current_row = Map.get(data, x + 1)
    Map.put(data, x + 1, mask ||| current_row)
  end

  # ---------------------------------------------------------------------------
  # Game-over detection
  # ---------------------------------------------------------------------------

  # Base case: checked all segments without collision
  defp is_game_over(_head, _body, snake_len, snake_len), do: false

  defp is_game_over(snake_head, snake_body, snake_len, number) do
    if Map.get(snake_body, number) == snake_head do
      true
    else
      is_game_over(snake_head, snake_body, snake_len, number + 1)
    end
  end

  # ---------------------------------------------------------------------------
  # Score display
  # ---------------------------------------------------------------------------

  defp handle_game_over(score) do
    {get_num_macro(div(score, 10)), get_num_macro(rem(score, 10))}
  end

  defp get_num_macro(0), do: @number_0
  defp get_num_macro(1), do: @number_1
  defp get_num_macro(2), do: @number_2
  defp get_num_macro(3), do: @number_3
  defp get_num_macro(4), do: @number_4
  defp get_num_macro(5), do: @number_5
  defp get_num_macro(6), do: @number_6
  defp get_num_macro(7), do: @number_7
  defp get_num_macro(8), do: @number_8
  defp get_num_macro(9), do: @number_9

  # ---------------------------------------------------------------------------
  # Scrolling text display
  # ---------------------------------------------------------------------------

  defp display_game_text(spi, times, command) do
    data1 = build_display_data(@empty_matrix, 1, times,     command)
    data2 = build_display_data(@empty_matrix, 1, times + 8, command)
    write_digit(spi, @digit_0, data1, :device_1)
    write_digit(spi, @digit_0, data2, :device_2)
  end

  # Base case: 8 rows filled (rows 1..8, stop at 9)
  defp build_display_data(result, 9, _times, _command), do: result

  defp build_display_data(result, number, times, :welcome) do
    row        = Map.get(@snake_game, number + times, 0)
    new_result = Map.put(result, number, row)
    build_display_data(new_result, number + 1, times, :welcome)
  end

  defp build_display_data(result, number, times, :lose) do
    row        = Map.get(@game_over, number + times, 0)
    new_result = Map.put(result, number, row)
    build_display_data(new_result, number + 1, times, :lose)
  end

  # ---------------------------------------------------------------------------
  # Direction helpers
  # ---------------------------------------------------------------------------

  # True if the requested direction would move the snake backward into itself
  defp is_backward(state, direction) do
    {_id_body, {pre_x, pre_y}} = Map.get(state.snakebody, state.snakelen - 2)
    {_id_head, {head_x, head_y}} = state.snakehead
    dx = head_x - pre_x
    dy = head_y - pre_y

    # Handle the edge case where the head has just wrapped a border
    sub =
      if abs(dx) + abs(dy) != 1,
        do: {rem(dx, 6), rem(dy, 6)},
        else: {-dx, -dy}

    sub == direction
  end

  # ---------------------------------------------------------------------------
  # Food helpers
  # ---------------------------------------------------------------------------

  defp spawn_new_food(body, size) do
    food_x  = random_coord()
    food_y  = random_coord()
    food_id = random_led()
    food    = {food_id, {food_x, food_y}}

    if is_exits(body, food, size, 0) do
      spawn_new_food(body, size)   # Collision – try again
    else
      food
    end
  end

  # Base case: no collision found
  defp is_exits(_body, _food, size, size), do: false

  defp is_exits(body, food, size, number) do
    if Map.get(body, number) == food do
      true
    else
      is_exits(body, food, size, number + 1)
    end
  end

  defp turn_off_food(spi, {food_id, {food_x, food_y}}, data) do
    dev  = get_device(food_id)
    temp = get_data(dev, data)
    row  = Map.get(temp, food_x + 1)
    write_register(spi, food_x + 1, row &&& ~~~(128 >>> food_y), dev)
  end

  defp turn_on_food(spi, {food_id, {food_x, food_y}}, data) do
    dev  = get_device(food_id)
    temp = get_data(dev, data)
    row  = Map.get(temp, food_x + 1)
    write_register(spi, food_x + 1, row ||| (128 >>> food_y), dev)
  end

  # ---------------------------------------------------------------------------
  # RNG helpers (AtomVM specific)
  # ---------------------------------------------------------------------------

  # Returns 0..7
  defp random_coord do
    value = rem(:atomvm.random(), 8)
    if value >= 0, do: value, else: random_coord()
  end

  # Returns 0 or 1 (which LED matrix)
  defp random_led do
    if :atomvm.random() >= 0, do: 1, else: 0
  end

  # ---------------------------------------------------------------------------
  # Variable-resistor helpers
  # ---------------------------------------------------------------------------

  # True when new_val falls outside the ±10 tolerance band around pre_val
  defp is_not_in_range(pre_val, new_val) do
    not (new_val >= pre_val - 10 and new_val <= pre_val + 10)
  end

  # Linear map from [in_low, in_high] → [out_low, out_high]
  defp map_range(value, in_low, in_high, out_low, out_high) do
    round((value - in_low) * (out_high - out_low) / (in_high - in_low) + out_low)
  end

  # ---------------------------------------------------------------------------
  # Main game loop – triggers a move cast every `pre_speed` ms
  # ---------------------------------------------------------------------------

  defp loop(pid, pre_speed) do
    new_speed =
      receive do
        {:newspeed, speed} -> speed
      after pre_speed ->
        pre_speed
      end

    GenServer.cast(pid, :move)
    loop(pid, new_speed)
  end
end
