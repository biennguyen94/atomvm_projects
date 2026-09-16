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
  @moduledoc """
  Snake Game running on AtomVM, using 2 MAX7219 LED matrices controlled via SPI.

  ## Overview
  This module is a GenServer managing the full snake game logic displayed on two 8x8 LED matrix
  modules (MAX7219), combined into a single 8x16 display. The player controls the snake using an
  analog joystick (ADC via GPIO), eats food to increase score and length. Game speed is adjustable
  via a variable resistor.

  ## Features
  - Display on 2 daisy-chained MAX7219 LED matrices (8x16 pixels)
  - 2-axis joystick control (VRx, VRy) + push button (SW)
  - Speed adjustment via remote DistErl command (`:snake_speed` registered process)
  - Blinking food
  - Border wrapping – snake crosses from one LED to the other
  - Score display as 7-segment digits on LED matrix at game over
  - Scrolling text effects "SNAKE GAME" and "GAME OVER"
  - Random food that never spawns on the snake body

  ## Joystick thresholds
  - `low_range = 800` – lower threshold
  - `high_range = 3000` – upper threshold
  - ADC value range 0–4095 (12-bit)

  ## Speed
  - Default speed: 200ms per tick
  - Speed is controlled remotely via DistErl: send `{:set_speed, milliseconds}` to
    `{:snake_speed, target_node}` from any node sharing the cookie `"AtomVM"`

  ## GPIO pinout
  ### Joystick
  - VRx (ADC) → GPIO34
  - VRy (ADC) → GPIO35
  - SW (push button) → GPIO32 (input, pull-up, rising edge interrupt)

  ### SPI (MAX7219)
  - MISO → GPIO19
  - MOSI → GPIO27
  - SCLK → GPIO5
  - CS → GPIO18

  ## Key module attributes
  - `@head` – initial snake head position: `{0, {2, 4}}` (LED 0, row 2, col 4)
  - `@body` – initial snake body: 2 segments
  - `@snake_length` – initial length = 2
  - `@direction` – initial movement direction: `{1, 0}` (right)

  ## Bitmap data structure
  Each 8x8 LED matrix is represented as an 8-entry map (keys are digit_0..digit_7 row numbers,
  values are 8-bit bytes, each bit corresponding to a column). Both LEDs are stored as a tuple
  `{data1, data2}`.

  The game uses digit bitmaps provided by `SnakeBlockbreakerClock.LedDisplay` (used for score display):
  - Center digits via `number/1`
  - Left-side version for LED 0 via `number_left/1`
  - Right-side version for LED 1 via `number_right/1`

  ## Flow
  1. `start/1` – initialize GenServer, spawn joystick process, enter main loop
  2. `init/1` – setup GPIO, SPI, display "SNAKE GAME" welcome screen
  3. Joystick button press → `handle_info(:gpio_interrupt)` → reset game
  4. Main loop `loop/2` – send `:move` at current speed
  5. `move_snake/1` – compute new position, check food collision, check self-collision
  6. Game over → display score → return to welcome screen

  ## GenServer messages
  - Cast `{:change_direction, x, y}` – change snake direction
  - Cast `:move` – advance snake one step
  - Cast `{:display_game_over, times}` / `{:display_snake_game, times}` – text animation
  - Cast `:turn_off_food` / `:turn_on_food` – food blinking
  - Info `{:gpio_interrupt, pin}` – joystick button press
  - Info `:stop_peripherals` – stop GPIO
  - Info `:back_to_welcome` – return to welcome screen
   - Message `{:newspeed, speed}` – speed update from DistErl speed control (remote)
  """
  use GenServer
  use SnakeBlockbreakerClock.LedDisplay

  @gpio_vrx 34
  @gpio_vry 35
  @gpio_sw 32

  @low_range 800
  @high_range 3000

  @delay_read_adc 20
  @max_speed 200
  @blink_rate 200

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
    :joystick_pid,
    :blink_pid,
    :button_press_time
  ]

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
    blink_pid = spawn(__MODULE__, :blink_food, [pid])
    GenServer.cast(pid, {:update_blink_pid, blink_pid})
    SnakeBlockbreakerClock.DistErl.register_loop(self())
    loop(pid, @max_speed)
  end

  def init(spi) do
    GPIO.set_pin_mode(@gpio_sw, :input)
    GPIO.set_pin_pull(@gpio_sw, :up)
    gpio = GPIO.open()
    GPIO.set_int(gpio, @gpio_sw, :both)
    IO.puts("Init SPI and MAX7219 OK\n")
    {snake_head, snake_body, food, {data1, data2}} = init_snake(spi, @body)
    new_state = %__MODULE__{
      spi: spi,
      snakehead: snake_head,
      snakebody: snake_body,
      snakelen: @snake_length,
      food: food,
      direction: @direction,
      data1: data1,
      data2: data2,
      gameover: false,
      goverproc: nil,
      joystick_pid: nil,
      blink_pid: nil,
      button_press_time: nil
    }
    {:ok, new_state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:update_joystick_pid, pid}, state) do
    {:noreply, %{state | joystick_pid: pid}}
  end

  def handle_cast({:update_blink_pid, pid}, state) do
    {:noreply, %{state | blink_pid: pid}}
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
    if state.gameover do
      {:noreply, state}
    else
      case move_snake(state) do
        {:stop, new_state} -> {:stop, :normal, new_state}
        {:ok, new_state} -> {:noreply, new_state}
      end
    end
  end

  def handle_cast({:display_game_over, times}, state) do
    if state.gameover do
      display_game_text(state.spi, times, :lose)
    end
    {:noreply, state}
  end

  def handle_cast({:display_snake_game, times}, state) do
    if state.gameover do
      display_game_text(state.spi, times, :welcome)
    end
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
    case GPIO.digital_read(@gpio_sw) do
      :low ->
        {:noreply, %{state | button_press_time: :erlang.system_time(:millisecond)}}
      :high ->
        press_ms = state.button_press_time
        if is_nil(press_ms) do
          {:noreply, state}
        else
          elapsed = :erlang.system_time(:millisecond) - press_ms
          state = %{state | button_press_time: nil}
          if elapsed > 1000 do
            IO.puts("long press: exit to clock")
            if is_pid(state.goverproc) do
              send(state.goverproc, :stop)
            end
            if is_pid(state.joystick_pid) do
              send(state.joystick_pid, :stop)
            end
            GenServer.cast(:snake_blockbreaker_clock, {:exit_to_clock})
            {:stop, :normal, state}
          else
            IO.puts("short press: reset game")
            if is_pid(state.goverproc) do
              send(state.goverproc, :stop)
            end
            if is_pid(state.joystick_pid) do
              send(state.joystick_pid, :stop)
            end
            if is_pid(state.blink_pid) do
              send(state.blink_pid, :stop)
            end
            joystick_pid = spawn(__MODULE__, :joystick, [self(), @gpio_vrx, @gpio_vry])
            blink_pid = spawn(__MODULE__, :blink_food, [self()])
            {snake_head, snake_body, food, {data1, data2}} = init_snake(state.spi, @body)
            new_state = %{state |
              snakehead: snake_head,
              snakebody: snake_body,
              snakelen: @snake_length,
              food: food,
              direction: @direction,
              data1: data1,
              data2: data2,
              joystick_pid: joystick_pid,
              blink_pid: blink_pid,
              gameover: false,
              goverproc: nil,
              button_press_time: nil
            }
            {:noreply, new_state}
          end
        end
    end
  end

  def handle_info(:stop_peripherals, state) do
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
    if is_pid(state.blink_pid) do
      send(state.blink_pid, :stop)
    end
    GenServer.cast(:snake_blockbreaker_clock, :game_over)
    {:stop, :normal, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, state) do
    GPIO.stop()
    if is_pid(state.joystick_pid) do
      send(state.joystick_pid, :stop)
    end
    if is_pid(state.blink_pid) do
      send(state.blink_pid, :stop)
    end
    IO.puts("snake genserver terminated")
    :ok
  end

  def joystick(pid, adcx, adcy) do
    joystick_loop(pid, adcx, adcy, nil)
  end

  defp joystick_loop(pid, adcx, adcy, last_dir) do
    receive do
      :stop -> :ok
    after
      @delay_read_adc ->
        x = read_adc_value(adcx)
        y = read_adc_value(adcy)

        new_dir =
          cond do
            x < @low_range -> {-1, 0}
            y < @low_range -> {0, -1}
            x > @high_range -> {1, 0}
            y > @high_range -> {0, 1}
            true -> nil
          end

        if new_dir != nil and new_dir != last_dir do
          GenServer.cast(pid, {:change_direction, elem(new_dir, 0), elem(new_dir, 1)})
        end

        joystick_loop(pid, adcx, adcy, new_dir)
    end
  end

  defp read_adc_value(adc) do
    case read_adc(adc) do
      {:ok, value} -> value
      :error -> -1
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
      IO.puts("snake: GAME OVER")
      SnakeBlockbreakerClock.NVS.update_high_score(:snake, state.snakelen)
      if is_pid(state.blink_pid) do
        send(state.blink_pid, :stop)
      end
      {data1, data2} = handle_game_over(state.snakelen)
      write_digit(state.spi, @digit_0, data1, :device_1)
      write_digit(state.spi, @digit_0, data2, :device_2)
      {:ok, %{state | gameover: true, blink_pid: nil}}
    else
      old_tail = Map.get(state.snakebody, 0)

      {data1, data2} =
        if new_snake_len == state.snakelen do
          clear_led(
            state.spi,
            old_tail,
            {state.data1, state.data2}
          )
        else
          {state.data1, state.data2}
        end

      {data1, data2} =
        set_led(
          state.spi,
          new_snake_head,
          {data1, data2}
        )

      {data1, data2} =
        if new_snake_len > state.snakelen do
          set_led(
            state.spi,
            new_food,
            {data1, data2}
          )
        else
          {data1, data2}
        end
      {:ok,
       %{
         state |
         snakehead: new_snake_head,
         snakebody: new_snake_body,
         snakelen: new_snake_len,
         food: new_food,
         data1: data1,
         data2: data2
       }}
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
    IO.puts("RANDOM LED = #{value}")
    rem(abs(value), 2)
  end

  defp spawn_new_food(body, size) do
    food_x = rand()
    food_y = rand()
    food_id = rand_led()

    food = {food_id, {food_x, food_y}}

    IO.puts("TRY FOOD = #{inspect(food)}")

    flag = is_exits(body, food, size, 0)

    IO.puts("FOOD EXISTS = #{inspect(flag)}")

    if flag do
      spawn_new_food(body, size)
    else
      IO.puts("NEW FOOD = #{inspect(food)}")
      food
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
          :ok
        else
          game_over_process(p, new_times, new_count_reset_to_welcome)
        end
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
    receive do
      :stop -> :ok
    after
      0 ->
        GenServer.cast(pid, :turn_off_food)
        :timer.sleep(@blink_rate)
        GenServer.cast(pid, :turn_on_food)
        :timer.sleep(@blink_rate)
        blink_food(pid)
    end
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
  defp set_led(spi, {id, {x, y}}, {data1, data2}) do
    device = get_device(id)
    data = get_data(device, {data1, data2})

    row = Map.get(data, x + 1)
    new_row = row ||| (128 >>> y)
    
    write_register(spi, x + 1, new_row, device)

    get_return_data(
      {data1, data2},
      Map.put(data, x + 1, new_row),
      device
    )
  end

  defp clear_led(spi, {id, {x, y}}, {data1, data2}) do
    device = get_device(id)
    data = get_data(device, {data1, data2})

    row = Map.get(data, x + 1)
    new_row = row &&& (~~~(128 >>> y))

    write_register(spi, x + 1, new_row, device)

    get_return_data(
      {data1, data2},
      Map.put(data, x + 1, new_row),
      device
    )
  end
end