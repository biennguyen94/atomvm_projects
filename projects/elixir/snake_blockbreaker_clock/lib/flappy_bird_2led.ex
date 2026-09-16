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

# Flappy Bird for 2x MAX7219 8x8 LED matrices (combined 8x16 display)
defmodule FlappyBird2Led do
  @moduledoc """
  Flappy Bird mini game for an 8x16 LED display built from 2 MAX7219 8x8 matrices.

  Controls:
  - Joystick Y axis (push up): flap the bird upward
  - Joystick button: short press resets game or starts a new run
  - Long press (> 2s): return to clock mode
  """

  use GenServer
  use SnakeBlockbreakerClock.LedDisplay

  @gpio_vry 35
  @gpio_sw 32

  @high_range 3000
  @delay_read_adc 20

  # ==== Game speed ====
  @tick_ms 220

  # ==== Bird physics ====
  @bird_x 2
  @gravity_step 1
  @max_fall_velocity 1
  @flap_velocity -2
  @flap_lift 1
  @floor_y 8

  # ==== Pipe layout ====
  @gap_height 3
  @gap_top_min 1
  @gap_top_max 5
  @pipe_start_x 15
  @pipe_spacing 6
  @pipe_remove_x -1
  @initial_pipe_x 12

  defstruct [
    :spi,
    :bird_y,
    :velocity,
    :pipes,
    :score,
    :gameover,
    :goverproc,
    :joystick_pid,
    :button_press_time,
    :last_data1,
    :last_data2
  ]

  def start(spi) do
    :erlang.system_flag(:schedulers_online, 2)
    IO.puts("flappy: starting game (bird_x=#{@bird_x}, tick=#{@tick_ms}ms)")
    {:ok, pid} = GenServer.start(__MODULE__, spi)
    :timer.sleep(200)

    joystick_pid = spawn(__MODULE__, :joystick, [pid, @gpio_vry])
    GenServer.cast(pid, {:update_joystick_pid, joystick_pid})

    game_loop(pid, @tick_ms)
  end

  def init(spi) do
    GPIO.set_pin_mode(@gpio_sw, :input)
    GPIO.set_pin_pull(@gpio_sw, :up)

    gpio = GPIO.open()
    GPIO.set_int(gpio, @gpio_sw, :both)

    state = render_board(new_game_state(spi))
    {:ok, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:update_joystick_pid, pid}, state) do
    {:noreply, %{state | joystick_pid: pid}}
  end

  def handle_cast(:flap, state) do
    if state.gameover do
      {:noreply, state}
    else
      IO.puts("flappy: FLAP y=#{state.bird_y} vel=#{state.velocity}")
      {:noreply, %{state | velocity: @flap_velocity, bird_y: max(0, state.bird_y - @flap_lift)}}
    end
  end

  def handle_cast(:move, state) do
    if state.gameover do
      {:noreply, state}
    else
      next_velocity = min(state.velocity + @gravity_step, @max_fall_velocity)
      next_bird_y = max(0, state.bird_y + next_velocity)

      pipes =
        move_pipes(state.pipes)

      pipes = maybe_spawn_pipe(pipes)

      IO.puts(
        "flappy: move bird_y=#{next_bird_y} vel=#{next_velocity} pipes=[#{pipe_summary(pipes)}] score=#{state.score}"
      )

      collision = pipe_collision?(next_bird_y, pipes, @bird_x)

      if collision or next_bird_y >= @floor_y do
        IO.puts("flappy: GAME OVER score=#{state.score} bird_y=#{next_bird_y} collision=#{collision}")
        SnakeBlockbreakerClock.NVS.update_high_score(:flappy, state.score)
        render_game_over(state.spi, state.score)
        {:noreply, %{state | gameover: true}}
      else
        new_score =
          count_score(pipes, state.score)

        pipes =
          mark_pipes_passed(pipes)

        if new_score != state.score do
          IO.puts("flappy: SCORE +#{new_score - state.score} -> #{new_score}")
        end

        next_state = %{state | bird_y: next_bird_y, velocity: next_velocity, pipes: pipes, score: new_score}
        {:noreply, render_board(next_state)}
      end
    end
  end

  def handle_cast(:reset_game, state) do
    new_state = new_game_state(state.spi)
    {:noreply, render_board(new_state)}
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
            IO.puts("flappy: long press -> exit to clock")
            if is_pid(state.goverproc), do: send(state.goverproc, :stop)
            if is_pid(state.joystick_pid), do: send(state.joystick_pid, :stop)
            GenServer.cast(:snake_blockbreaker_clock, {:exit_to_clock})
            {:stop, :normal, state}
          else
            IO.puts("flappy: short press -> reset")
            if is_pid(state.joystick_pid), do: send(state.joystick_pid, :stop)
            new_joystick = spawn(__MODULE__, :joystick, [self(), @gpio_vry])
            new_state = %{new_game_state(state.spi) | joystick_pid: new_joystick}
            {:noreply, render_board(new_state)}
          end
        end
    end
  end

  def handle_info(:stop_peripherals, state) do
    if is_pid(state.joystick_pid), do: send(state.joystick_pid, :stop)
    {:noreply, state}
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
    IO.puts("flappy bird genserver terminated")
    :ok
  end

  def joystick(pid, adc_pin) do
    joystick(pid, adc_pin, false)
  end

  defp joystick(pid, adc_pin, prev_up) do
    receive do
      :stop -> :ok
    after
      @delay_read_adc ->
        up? =
          case read_adc(adc_pin) do
            {:ok, value} -> value > @high_range
            _ -> false
          end

        if up? and not prev_up do
          GenServer.cast(pid, :flap)
        end

        joystick(pid, adc_pin, up?)
    end
  end

  defp game_loop(pid, delay) do
    receive do
      {:newspeed, new_delay} -> game_loop(pid, new_delay)
    after
      delay ->
        GenServer.cast(pid, :move)
        game_loop(pid, delay)
    end
  end

  defp new_game_state(spi) do
    %__MODULE__{
      spi: spi,
      bird_y: 3,
      velocity: 0,
      pipes: [%{x: @initial_pipe_x, gap_top: 2, passed: false}],
      score: 0,
      gameover: false,
      goverproc: nil,
      joystick_pid: nil,
      button_press_time: nil,
      last_data1: nil,
      last_data2: nil
    }
  end

  defp render_board(state) do
    {data1, data2} = build_display(state)
    write_digit_diff(state.spi, @digit_0, data1, :device_1, state.last_data1)
    write_digit_diff(state.spi, @digit_0, data2, :device_2, state.last_data2)
    %{state | last_data1: data1, last_data2: data2}
  end

  defp render_game_over(spi, score) do
    {data1, data2} = handle_game_over(score)
    write_digit(spi, @digit_0, data1, :device_1)
    write_digit(spi, @digit_0, data2, :device_2)
    :ok
  end

  defp build_display(state) do
    left = @empty_matrix
    right = @empty_matrix

    board = empty_board()
    board = draw_bird(board, @bird_x, state.bird_y)
    board = draw_pipes(board, state.pipes)

    {left, right} =
      build_matrix_rows(board, 0, {left, right})

    {left, right}
  end

  defp draw_bird(board, x, y) do
    draw_bird_loop(board, x, y, 0)
  end

  defp draw_bird_loop(board, x, y, offset) when offset > 1 do
    board
  end

  defp draw_bird_loop(board, x, y, offset) do
    px = x + offset
    py = y

    next_board =
      if px >= 0 and px < 16 and py >= 0 and py < 8 do
        set_board_pixel(board, py, px)
      else
        board
      end

    draw_bird_loop(next_board, x, y, offset + 1)
  end

  defp draw_pipe(board, x, gap_top) do
    draw_pipe_loop(board, x, gap_top, 0)
  end

  defp draw_pipe_loop(board, x, gap_top, row) when row > 7 do
    board
  end

  defp draw_pipe_loop(board, x, gap_top, row) do
    next_board =
      if row < gap_top or row > gap_top + @gap_height - 1 do
        if x >= 0 and x < 16 do
          set_board_pixel(board, row, x)
        else
          board
        end
      else
        board
      end

    draw_pipe_loop(next_board, x, gap_top, row + 1)
  end

  defp set_board_pixel(board, row, col) do
    current_row = Map.get(board, row, List.duplicate(0, 16))
    updated_row = replace_at(current_row, col, 1)
    Map.put(board, row, updated_row)
  end

  defp replace_at(list, index, value) do
    replace_at(list, index, value, 0)
  end

  defp replace_at([], _index, _value, _current) do
    []
  end

  defp replace_at([_head | tail], index, value, current) when current == index do
    [value | tail]
  end

  defp replace_at([head | tail], index, value, current) do
    [head | replace_at(tail, index, value, current + 1)]
  end

  defp build_matrix_rows(board, col, {left, right}) when col >= 16 do
    {left, right}
  end

  defp build_matrix_rows(board, col, {left, right}) do
    column_bits = board_column_bits(board, col, 7, 0)

    if col < 8 do
      build_matrix_rows(board, col + 1, {Map.put(left, col + 1, column_bits), right})
    else
      build_matrix_rows(board, col + 1, {left, Map.put(right, col - 7, column_bits)})
    end
  end

  defp board_column_bits(_board, _col, -1, acc), do: acc

  defp board_column_bits(board, col, row, acc) do
    case get_board_pixel(board, row, col) do
      1 -> board_column_bits(board, col, row - 1, acc ||| 1 <<< row)
      _ -> board_column_bits(board, col, row - 1, acc)
    end
  end

  defp empty_board do
    empty_board_loop(0, %{})
  end

  defp empty_board_loop(row, board) when row >= 8 do
    board
  end

  defp empty_board_loop(row, board) do
    empty_board_loop(row + 1, Map.put(board, row, create_empty_row(0, [])))
  end

  defp create_empty_row(col, acc) when col >= 16 do
    acc
  end

  defp create_empty_row(col, acc) do
    create_empty_row(col + 1, acc ++ [0])
  end

  defp draw_pipes(board, pipes) do
    draw_pipes_loop(board, pipes)
  end

  defp draw_pipes_loop(board, []), do: board
  defp draw_pipes_loop(board, [pipe | rest]) do
    draw_pipes_loop(draw_pipe(board, pipe.x, pipe.gap_top), rest)
  end

  defp maybe_spawn_pipe(pipes) do
    if is_empty_list(pipes) or pipe_front_x(pipes) < @pipe_start_x - @pipe_spacing do
      new_pipe = %{
        x: @pipe_start_x,
        gap_top: rem(:erlang.unique_integer([:positive, :monotonic]), @gap_top_max) + @gap_top_min,
        passed: false
      }

      IO.puts(
        "flappy: spawn pipe x=#{@pipe_start_x} gap_top=#{new_pipe.gap_top} active=#{length(pipes) + 1}"
      )

      [new_pipe | pipes]
    else
      pipes
    end
  end

  defp is_empty_list([]), do: true
  defp is_empty_list(_), do: false

  defp pipe_front_x([pipe | _]), do: pipe.x
  defp pipe_front_x([]), do: 999

  defp pipe_collision?(bird_y, pipes, bird_x) do
    pipe_collision_loop(pipes, bird_y, bird_x)
  end

  defp pipe_collision_loop([], _bird_y, _bird_x), do: false

  defp pipe_collision_loop([pipe | rest], bird_y, bird_x) do
    if (pipe.x == bird_x or pipe.x == bird_x + 1) and
         (bird_y < pipe.gap_top or bird_y > pipe.gap_top + @gap_height - 1) do
      true
    else
      pipe_collision_loop(rest, bird_y, bird_x)
    end
  end

  defp move_pipes(pipes) do
    move_pipes_loop([], pipes)
  end

  defp pipe_summary([]), do: ""

  defp pipe_summary([pipe]) do
    "#{pipe.x}/#{pipe.gap_top}"
  end

  defp pipe_summary([pipe | rest]) do
    "#{pipe.x}/#{pipe.gap_top}, " <> pipe_summary(rest)
  end

  defp move_pipes_loop(acc, []) do
    reverse_list(acc)
  end

  defp move_pipes_loop(acc, [pipe | rest]) do
    moved = %{pipe | x: pipe.x - 1}
    if moved.x >= @pipe_remove_x do
      move_pipes_loop([moved | acc], rest)
    else
      move_pipes_loop(acc, rest)
    end
  end

  defp reverse_list(list) do
    reverse_list(list, [])
  end

  defp reverse_list([], acc), do: acc
  defp reverse_list([head | tail], acc), do: reverse_list(tail, [head | acc])

  defp count_score([], acc), do: acc
  defp count_score([pipe | rest], acc) do
    next_acc =
      if pipe.x == @bird_x - 1 and pipe.passed != true do
        acc + 1
      else
        acc
      end

    count_score(rest, next_acc)
  end

  defp mark_pipes_passed([]), do: []
  defp mark_pipes_passed([pipe | rest]) do
    if pipe.x < @bird_x and pipe.passed != true do
      [%{pipe | passed: true} | mark_pipes_passed(rest)]
    else
      [pipe | mark_pipes_passed(rest)]
    end
  end

  defp get_board_pixel(board, row, col) do
    row_data = Map.get(board, row, [])
    get_pixel_in_row(row_data, col, 0)
  end

  defp get_pixel_in_row([], _col, _idx), do: 0
  defp get_pixel_in_row([value | _rest], col, idx) when idx == col, do: value
  defp get_pixel_in_row([_value | rest], col, idx), do: get_pixel_in_row(rest, col, idx + 1)
end
