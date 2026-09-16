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

defmodule PongGame2Led do
  @moduledoc """
  Pong (1-player vs AI) running on AtomVM, using 2 MAX7219 LED matrices
  controlled via SPI, combined into a 16x8 display.

  ## Overview
  Player controls the left paddle (x=0) with the joystick Y-axis.
  AI controls the right paddle (x=15) with prediction, reaction delay and
  prediction error (NORMAL difficulty). Ball bounces between paddles and off
  the top/bottom walls. First to 5 points wins.

  ## Display layout
      16 columns x 8 rows
      Player paddle: x=0,  y=0..5 (3 LEDs tall)
      AI paddle:     x=15, y=0..5 (3 LEDs tall)
      Ball:          x=1..14, y=0..7

  ## Controls
  - Joystick Y-axis (GPIO35) only: UP -> paddle y-1, DOWN -> paddle y+1.
    ADC < 1400 -> UP, ADC > 2600 -> DOWN, dead zone in between.
  - Short button press: reset game. Long press (> 2s): exit to clock.

  ## Ball-paddle collision
  Ball angle depends on where it hits the paddle:
  - Top third    -> ball_dy = -1 (ball goes up)
  - Middle third -> ball_dy =  0 (ball goes straight)
  - Bottom third -> ball_dy = +1 (ball goes down)

  ## AI (NORMAL)
  AI predicts ball y when it reaches x=15, applies a +-1 pixel error, reacts
  every 2 ticks, and moves at most 1 pixel per tick.

  ## Difficulty progression
  After each point the ball speeds up:
  Level 1: 120ms, Level 2: 100ms, Level 3: 80ms, Level 4+: 65ms (min).

  ## GPIO pinout
  - VRy (ADC) -> GPIO35
  - SW (button) -> GPIO32 (input, pull-up)
  - SPI: MISO=19, MOSI=27, SCLK=5, CS=18

  ## GenServer messages
  - Cast `{:change_direction, dir}` - set player paddle direction
  - Cast `:move` - advance game one tick
  - Cast `{:update_joystick_pid, pid}` / `{:update_loop_pid, pid}` - register helpers
  - Info `{:gpio_interrupt, pin}` - button press (short = reset/restart, long = exit to clock)
  - Info `:back_to_welcome` - return to the launcher menu
  - Message `{:newspeed, speed}` - internal level-based tick update
  """
  use GenServer
  use SnakeBlockbreakerClock.LedDisplay

  @gpio_vry 35
  @gpio_sw 32

  # ================ Tunable parameters ================
  # Joystick ADC thresholds (VRy axis): raw ADC below @adc_up => joystick up,
  # raw ADC above @adc_down => joystick down.
  # Tuning: if the paddle feels unresponsive at the ends, widen the dead zone
  # (lower @adc_up / raise @adc_down); if it barely moves, narrow it.
  @adc_up 1400
  @adc_down 2600
  # Milliseconds between joystick ADC reads (polling interval).
  # Tuning: smaller = smoother/lighter and more sensitive stick, more CPU.
  @delay_read_adc 20
  # Paddle moves 1 cell every N poll reads (throttles paddle speed).
  # Tuning: bigger = slower paddle; smaller (e.g. 2) = faster paddle.
  @paddle_move_div 4

  # Highest allowed player paddle row (bottom edge of the 8-row matrix).
  # Tuning: smaller = paddle can't reach the bottom; (max rows = 8 - height) is a safe cap.
  @paddle_max_y 5

  # Ball starting column in the 16-cell-wide playfield (2 LED devices side by side).
  @ball_start_x 7
  # Ball starting row. Tuning: only affects where the ball re-spawns vertically.
  @ball_start_y 3

  # Points needed by a side to win the match. Tuning: bigger = longer match.
  @max_score 3

  # AI reaction time: ticks the AI waits before re-predicting the ball target.
  # Tuning: bigger = dumber/slower AI; smaller = faster/better AI.
  @ai_reaction_delay 2

  # Loop tick (ms) at the start of a match and at each new level.
  # Tuning: smaller = faster ball; bigger = slower ball.
  @initial_tick 120
  # Fastest allowed loop tick (ms) at the highest level.
  # Tuning: smaller = hardest final level speed; this is also the floor for level ramp-up.
  @min_tick 65

  # Loop tick (ms) used right after a goal while the ball is launched (slower start).
  @launch_tick 120
  # Number of ticks the ball stays at @launch_tick before speeding up to the level tick.
  # Tuning: bigger = longer slow-launch phase; 0 = no slow launch.
  @launch_ticks 5
  # Ticks the game waits (ball out of bounds) before spawning the next ball (~1s).
  # Tuning: bigger = longer pause between balls (delay is @delay_ticks * @launch_tick ms).
  @delay_ticks 12

  # Number of ticks the ball stays boosted after hitting the middle of a paddle.
  # Tuning: bigger = boost lasts longer; 0 = no boost at all.
  # Typical range: 4-10 ticks. At @boost_tick 75ms that's ~0.3-0.75s of boost.
  # Combine with @boost_tick to fine-tune the feel.
  @boost_ticks 7
  # Loop tick (ms) during the boost (smaller = faster ball).
  # Tuning: smaller = stronger boost; 65-100 are good values.
  # @boost_tick 100 + level tick 120 (level 1) = moderate speed-up (~20% faster).
  # @boost_tick 75 + level tick 120 (level 1) = noticeable speed-up (~1.6x faster).
  # @boost_tick 65 + level tick 120 = hard boost (~almost 2x faster).
  # @boost_tick 75 + level tick 65 (high level) = barely noticeable (already fast).
  # Rule of thumb: if the boost feels too strong, raise @boost_tick toward the current level tick.
  # If too weak, lower @boost_tick or raise @boost_ticks for a longer effect.
  @boost_tick 75

  defstruct [
    :spi,
    :ball_x,
    :ball_y,
    :ball_dx,
    :ball_dy,
    :player_y,
    :ai_y,
    :player_score,
    :ai_score,
    :ai_target,
    :ai_timer,
    :game_state,
    :level,
    :tick_ms,
    :score_display_ticks,
    :goverproc,
    :joystick_pid,
    :loop_pid,
    :button_press_time,
    :last_data1,
    :last_data2,
    :launch_ticks_left,
    :delay_left,
    :boost_ticks_left
  ]

  def start(spi) do
    :erlang.system_flag(:schedulers_online, 2)
    {:ok, pid} = GenServer.start(__MODULE__, spi)
    :timer.sleep(500)
    joystick_pid = spawn(__MODULE__, :joystick, [pid, @gpio_vry])
    GenServer.cast(pid, {:update_joystick_pid, joystick_pid})
    GenServer.cast(pid, {:update_loop_pid, self()})
    loop(pid, @initial_tick)
  end

  def init(spi) do
    GPIO.set_pin_mode(@gpio_sw, :input)
    GPIO.set_pin_pull(@gpio_sw, :up)
    gpio = GPIO.open()
    GPIO.set_int(gpio, @gpio_sw, :both)
    IO.puts("Init SPI and MAX7219 OK\n")
    new_state = %__MODULE__{
      spi: spi,
      ball_x: @ball_start_x,
      ball_y: @ball_start_y,
      ball_dx: 1,
      ball_dy: 1,
      player_y: 2,
      ai_y: 2,
      player_score: 0,
      ai_score: 0,
      ai_target: 3,
      ai_timer: 0,
      game_state: :playing,
      level: 1,
      tick_ms: @initial_tick,
      score_display_ticks: 0,
      goverproc: nil,
      joystick_pid: nil,
      loop_pid: nil,
      button_press_time: nil,
      launch_ticks_left: 0,
      delay_left: 0,
      boost_ticks_left: 0
    }
    render_board(new_state)
    {:ok, new_state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:update_joystick_pid, pid}, state) do
    {:noreply, %{state | joystick_pid: pid}}
  end

  def handle_cast({:update_loop_pid, pid}, state) do
    {:noreply, %{state | loop_pid: pid}}
  end

  def handle_cast({:change_direction, dir}, state) do
    if state.game_state != :playing do
      {:noreply, state}
    else
      new_y =
        cond do
          dir == -1 -> max(state.player_y - 1, 0)
          dir == 1 -> min(state.player_y + 1, @paddle_max_y)
          true -> state.player_y
        end

      state = %{state | player_y: new_y}

      if state.game_state == :playing do
        {:noreply, render_board(state)}
      else
        {:noreply, state}
      end
    end
  end

  def handle_cast(:move, state) do
    case state.game_state do
      :playing ->
        state = update_ai(state)
        state = move_ball(state)
        state = check_all_collisions(state)

        state =
          if state.launch_ticks_left > 0 do
            new_left = state.launch_ticks_left - 1
            state = %{state | launch_ticks_left: new_left}

            if new_left == 0 do
              notify_new_speed(state)
            end

            state
          else
            state
          end

        state =
          if state.boost_ticks_left > 0 do
            new_left = state.boost_ticks_left - 1
            state = %{state | boost_ticks_left: new_left}

            if new_left == 0 do
              notify_new_speed(state)
            end

            state
          else
            state
          end

        cond do
          state.ball_x <= 0 ->
            handle_goal(state, :ai)

          state.ball_x >= 15 ->
            handle_goal(state, :player)

          true ->
            {:noreply, render_board(state)}
        end

      :out_of_bounds ->
        if state.delay_left <= 1 do
          {:noreply, render_board(%{state | game_state: :playing})}
        else
          {:noreply, %{state | delay_left: state.delay_left - 1}}
        end

      _ ->
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
            IO.puts("pong: long press -> exit to clock")
            if is_pid(state.goverproc), do: send(state.goverproc, :stop)
            if is_pid(state.joystick_pid), do: send(state.joystick_pid, :stop)
            GenServer.cast(:snake_blockbreaker_clock, {:exit_to_clock})
            {:stop, :normal, state}
          else
            IO.puts("pong: short press -> reset")
            if is_pid(state.goverproc), do: send(state.goverproc, :stop)
            if is_pid(state.joystick_pid), do: send(state.joystick_pid, :stop)
            joystick_pid = spawn(__MODULE__, :joystick, [self(), @gpio_vry])
            new_state = %{new_game(state.spi) | joystick_pid: joystick_pid, loop_pid: state.loop_pid}
            if is_pid(state.loop_pid), do: send(state.loop_pid, {:newspeed, @initial_tick})
            {:noreply, render_board(new_state)}
          end
        end
    end
  end

  def handle_info(:stop_peripherals, state) do
    if is_pid(state.joystick_pid), do: send(state.joystick_pid, :stop)
    {:noreply, state}
  end

  def handle_info(:back_to_welcome, state) do
    IO.puts("pong: receive back_to_welcome")
    if is_pid(state.goverproc), do: send(state.goverproc, :stop)
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
    if is_pid(state.joystick_pid), do: send(state.joystick_pid, :stop)
    IO.puts("pong genserver terminated")
    :ok
  end

  def joystick(pid, adc_pin, counter \\ 0) do
    receive do
      :stop -> :ok
    after
      @delay_read_adc ->
        dir =
          case read_adc(adc_pin) do
            {:ok, value} when value < @adc_up -> 1
            {:ok, value} when value > @adc_down -> -1
            _ -> 0
          end

        new_counter = counter + 1

        if dir != 0 and new_counter >= @paddle_move_div do
          GenServer.cast(pid, {:change_direction, dir})
          joystick(pid, adc_pin, 0)
        else
          joystick(pid, adc_pin, new_counter)
        end
    end
  end

  defp update_ai(state) do
    if state.ball_dx == 1 do
      if state.ai_timer > 0 do
        new_ai_y = step_ai(state.ai_y, state.ai_target)
        %{state | ai_y: new_ai_y, ai_timer: state.ai_timer - 1}
      else
        steps = 15 - state.ball_x
        predicted = predict_ball_y(state.ball_y, state.ball_dy, steps)
        target = max(0, min(@paddle_max_y, predicted - 1 + ai_error()))
        %{state | ai_y: step_ai(state.ai_y, target), ai_target: target, ai_timer: @ai_reaction_delay}
      end
    else
      center = 2
      %{state | ai_y: step_ai(state.ai_y, center), ai_target: center}
    end
  end

  defp step_ai(y, target) do
    cond do
      y < target -> min(y + 1, @paddle_max_y)
      y > target -> max(y - 1, 0)
      true -> y
    end
  end

  defp ai_error do
    rem(:erlang.unique_integer([:positive, :monotonic]), 3) - 1
  end

  defp predict_ball_y(y, _dy, 0), do: y

  defp predict_ball_y(y, dy, steps) do
    new_y = y + dy

    {ny, ndy} =
      cond do
        new_y <= 0 -> {0, abs(dy)}
        new_y >= 7 -> {7, -abs(dy)}
        true -> {new_y, dy}
      end

    predict_ball_y(ny, ndy, steps - 1)
  end

  defp move_ball(state) do
    new_x = state.ball_x + state.ball_dx
    new_y = state.ball_y + state.ball_dy

    new_dy =
      cond do
        new_y <= 0 -> abs(state.ball_dy)
        new_y >= 7 -> -abs(state.ball_dy)
        true -> state.ball_dy
      end

    %{state | ball_x: new_x, ball_y: new_y, ball_dy: new_dy}
  end

  defp check_all_collisions(state) do
    state
    |> check_player_paddle_collision()
    |> check_ai_paddle_collision()
  end

  defp check_player_paddle_collision(state) do
    if state.ball_x == 1 and state.ball_dx == -1 do
      hit_y = paddle_hit_y(state.ball_y, state.ball_dy, state.player_y)
      if hit_y != nil do
        offset = hit_y - state.player_y - 1
        state = %{state | ball_dx: 1, ball_dy: offset}
        if offset == 0 do
          notify_new_speed(%{state | tick_ms: @boost_tick})
          %{state | boost_ticks_left: @boost_ticks}
        else
          state
        end
      else
        state
      end
    else
      state
    end
  end

  defp paddle_hit_y(ball_y, ball_dy, paddle_y) do
    prev_y = ball_y - ball_dy
    cond do
      ball_y >= paddle_y and ball_y <= paddle_y + 2 -> ball_y
      prev_y >= paddle_y and prev_y <= paddle_y + 2 -> prev_y
      true -> nil
    end
  end

  defp check_ai_paddle_collision(state) do
    if state.ball_x == 14 and state.ball_dx == 1 do
      hit_y = paddle_hit_y(state.ball_y, state.ball_dy, state.ai_y)
      if hit_y != nil do
        offset = hit_y - state.ai_y - 1
        state = %{state | ball_dx: -1, ball_dy: offset}
        if offset == 0 do
          notify_new_speed(%{state | tick_ms: @boost_tick})
          %{state | boost_ticks_left: @boost_ticks}
        else
          state
        end
      else
        state
      end
    else
      state
    end
  end

  defp handle_goal(state, :ai) do
    new_ai_score = state.ai_score + 1

    if new_ai_score >= @max_score do
      IO.puts("pong: AI WINS #{state.player_score}-#{new_ai_score}")
      SnakeBlockbreakerClock.NVS.update_high_score(:pong, state.player_score)
      show_score_display(state.spi, state.player_score, new_ai_score)
      new_state = start_game_over(state)
      {:noreply, %{new_state | ai_score: new_ai_score, game_state: :game_over}}
    else
      IO.puts("pong: AI scores #{state.player_score}-#{new_ai_score}")
      {new_level, new_tick} = next_level(state.level)
      state = reset_ball(%{state | ai_score: new_ai_score, level: new_level, tick_ms: new_tick})
      notify_new_speed(%{state | tick_ms: @launch_tick})
      {:noreply, %{state | game_state: :out_of_bounds, delay_left: @delay_ticks}}
    end
  end

  defp handle_goal(state, :player) do
    new_player_score = state.player_score + 1

    if new_player_score >= @max_score do
      IO.puts("pong: PLAYER WINS #{new_player_score}-#{state.ai_score}")
      SnakeBlockbreakerClock.NVS.update_high_score(:pong, new_player_score)
      show_score_display(state.spi, new_player_score, state.ai_score)
      new_state = start_game_over(state)
      {:noreply, %{new_state | player_score: new_player_score, game_state: :game_over}}
    else
      IO.puts("pong: Player scores #{new_player_score}-#{state.ai_score}")
      {new_level, new_tick} = next_level(state.level)
      state = reset_ball(%{state | player_score: new_player_score, ball_dx: -1, level: new_level, tick_ms: new_tick})
      notify_new_speed(%{state | tick_ms: @launch_tick})
      {:noreply, %{state | game_state: :out_of_bounds, delay_left: @delay_ticks}}
    end
  end

  defp start_game_over(state) do
    if is_pid(state.goverproc), do: send(state.goverproc, :stop)
    new_proc = spawn(__MODULE__, :game_over_process, [self()])
    %{state | goverproc: new_proc}
  end

  defp notify_new_speed(state) do
    if is_pid(state.loop_pid), do: send(state.loop_pid, {:newspeed, state.tick_ms})
  end

  defp reset_ball(state) do
    new_y = rem(:erlang.unique_integer([:positive, :monotonic]), 6) + 1
    new_dy = if :atomvm.random() > 0, do: 1, else: -1

    %{state |
      ball_x: @ball_start_x,
      ball_y: new_y,
      ball_dy: new_dy,
      player_y: 2,
      ai_y: 2,
      ai_target: 3,
      ai_timer: 0,
      last_data1: nil,
      last_data2: nil,
      launch_ticks_left: @launch_ticks,
      boost_ticks_left: 0
    }
  end

  defp next_level(level) do
    new_level = level + 1

    new_tick =
      case new_level do
        2 -> 100
        3 -> 80
        4 -> 65
        _ -> max(@min_tick, @initial_tick - new_level * 15)
      end

    {new_level, new_tick}
  end

  defp render_board(state) do
    board = empty_board()
    board = draw_paddle(board, 0, state.player_y)
    board = draw_paddle(board, 15, state.ai_y)
    board = draw_ball(board, state.ball_x, state.ball_y)

    {data1, data2} = board_to_matrices(board)
    write_digit_diff(state.spi, @digit_0, data1, :device_1, state.last_data1)
    write_digit_diff(state.spi, @digit_0, data2, :device_2, state.last_data2)
    %{state | last_data1: data1, last_data2: data2}
  end

  defp show_score_display(spi, player_score, ai_score) do
    data1 = number_left(player_score)
    data2 = number_right(ai_score)
    write_digit(spi, @digit_0, data1, :device_1)
    write_digit(spi, @digit_0, data2, :device_2)
  end

  defp empty_board do
    %{
      0 => 0,
      1 => 0,
      2 => 0,
      3 => 0,
      4 => 0,
      5 => 0,
      6 => 0,
      7 => 0
    }
  end

  defp draw_paddle(board, x, y) do
    mask = (0b111 <<< y) &&& 0xFF

    Enum.reduce(0..7, board, fn row, acc ->
      if ((mask >>> row) &&& 1) == 1 do
        current = Map.get(acc, row, 0)
        Map.put(acc, row, current ||| (1 <<< x))
      else
        acc
      end
    end)
  end

  defp draw_ball(board, x, y) do
    if x >= 0 and x <= 15 and y >= 0 and y <= 7 do
      current = Map.get(board, y, 0)
      Map.put(board, y, current ||| (1 <<< x))
    else
      board
    end
  end

  defp board_to_matrices(board) do
    left = build_left(board, 0, %{})
    right = build_right(board, 8, %{})
    {left, right}
  end

  defp build_left(_board, col, acc) when col >= 8, do: acc

  defp build_left(board, col, acc) do
    byte = column_bits(board, col, 7, 0)
    build_left(board, col + 1, Map.put(acc, col + 1, byte))
  end

  defp build_right(_board, col, acc) when col >= 16, do: acc

  defp build_right(board, col, acc) do
    byte = column_bits(board, col, 7, 0)
    build_right(board, col + 1, Map.put(acc, col - 7, byte))
  end

  defp column_bits(_board, _col, -1, acc), do: acc

  defp column_bits(board, col, row, acc) do
    if (Map.get(board, row, 0) &&& (1 <<< col)) != 0 do
      column_bits(board, col, row - 1, acc ||| (1 <<< row))
    else
      column_bits(board, col, row - 1, acc)
    end
  end

  def game_over_process(p) do
    receive do
      :stop -> :ok
    after
      100 ->
        game_over_process(p)
    end
  end

  defp write_digit_diff(spi, 8, data, device, last_data) do
    reg_data = Map.get(data, 8)
    if is_nil(last_data) or Map.get(last_data, 8) != reg_data do
      write_register(spi, 8, reg_data, device)
    end

    :ok
  end

  defp write_digit_diff(spi, number, data, device, last_data) do
    reg_data = Map.get(data, number)
    if is_nil(last_data) or Map.get(last_data, number) != reg_data do
      write_register(spi, number, reg_data, device)
    end

    write_digit_diff(spi, number + 1, data, device, last_data)
  end

  defp new_game(spi) do
    %__MODULE__{
      spi: spi,
      ball_x: @ball_start_x,
      ball_y: @ball_start_y,
      ball_dx: 1,
      ball_dy: 1,
      player_y: 2,
      ai_y: 2,
      player_score: 0,
      ai_score: 0,
      ai_target: 3,
      ai_timer: 0,
      game_state: :playing,
      level: 1,
      tick_ms: @initial_tick,
      score_display_ticks: 0,
      goverproc: nil,
      joystick_pid: nil,
      loop_pid: nil,
      button_press_time: nil,
      launch_ticks_left: 0,
      delay_left: 0,
      boost_ticks_left: 0
    }
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