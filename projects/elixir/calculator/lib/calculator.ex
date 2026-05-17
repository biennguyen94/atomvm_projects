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

defmodule Calculator do
  use GenServer
  use Bitwise

  @gpio_scl 22
  @gpio_sda 21
  @i2c_base_freq 1_000_000
  @lcd_addr 0x27

  @gpio_r4 23
  @gpio_r3 19
  @gpio_r2 18
  @gpio_r1 4
  @gpio_c1 14
  @gpio_c2 15
  @gpio_c3 5
  @gpio_c4 27

  @add 0b00101011
  @sub 0b00101101
  @mul 0b00101010
  @dev 0b11111101

  @zero 0b00110000
  @one 0b00110001
  @two 0b00110010
  @three 0b00110011
  @four 0b00110100
  @five 0b00110101
  @six 0b00110110
  @seven 0b00110111
  @eight 0b00111000
  @nine 0b00111001

  @open_bracket 0b00101000
  @close_bracket 0b00101001
  @pow 0b01011110
  @rem 0b00100101

  @mode_cal 0
  @mode_clr 1
  @mode_his 2

  @default %{}

  @spec 0
  @nor 1

  defstruct [:i2c, :mode, :data, :exp, :ans, :pointer, :history, :size, :x, :y]

  def start do
    :erlang.system_flag(:schedulers_online, 2)
    keypad_init()
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
    :ok = GenServer.call(pid, :display)
    IO.puts("Init I2C, LCD and Keypad OK")
    read_keypad(pid)
  end

  @impl true
  def init(_) do
    i2c = i2c_init()
    lcd_init(i2c)
    new_state = %__MODULE__{i2c: i2c, mode: @mode_cal, data: "", exp: [0], ans: 0, pointer: 0, history: [], size: 0, x: 0, y: 0}
    {:ok, new_state}
  end

  @impl true
  def handle_call(:display, _from, state) do
    case state.mode do
      @mode_cal -> display_calculate(state)
      @mode_clr -> display_clear(state)
      @mode_his -> display_history(state)
      _ -> IO.puts("Something wrong!")
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:new_character, char}, _from, state) do
    mode = state.mode

    new_state =
      case mode do
        @mode_cal ->
          data = put_element_end(char, state.data)
          new_exp = create_infix_list(char, state.exp)
          x = state.x
          y = state.y
          display_new_char(state.i2c, x, y, char)

          {new_x, new_y} =
            cond do
              (x == 1) and (y == 19) -> {x, y}
              (y + 1) > 19 -> {x + 1, 0}
              true -> {x, y + 1}
            end

          %{state | data: data, exp: new_exp, x: new_x, y: new_y}

        @mode_his ->
          if state.size != 0 do
            {new_data, new_exp, new_ans, new_pointer, x, y} = handle_change_pointer(char, state)

            if char == @five do
              new_state = %{state | pointer: new_pointer, mode: @mode_cal, data: new_data, ans: new_ans, exp: new_exp, x: x, y: y}
              display_calculate(new_state)
              new_state
            else
              display_current_history(state.i2c, new_pointer, state.history)
              %{state | pointer: new_pointer}
            end
          else
            state
          end

        @mode_clr ->
          state
      end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:delete_character, _from, state) do
    data = delete_last_element(state.data)
    new_exp = delete_infix_list(state.exp)
    x = state.x
    y = state.y

    {new_x, new_y} =
      cond do
        (x == 0) and (y == 0) -> {x, y}
        (y - 1) < 0 -> {0, 19}
        true -> {x, y - 1}
      end

    display_delete_character(state.i2c, new_x, new_y)
    new_state = %{state | data: data, exp: new_exp, x: new_x, y: new_y}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:press_equal, _from, state) do
    new_state =
      case state.mode do
        @mode_cal ->
          pos_fix = get_posfix(Enum.reverse(state.exp), [], [])

          ans =
            try do
              calculate_posfix(pos_fix, [])
            rescue
              _ -> :error
            end

          condition0 = (ans != :error) and (validate_string(pos_fix, false, false) == false)
          condition1 = (ans != :error) and (ans > :math.pow(10, 15))

          cond do
            condition0 ->
              display_error(state.i2c)
              display_calculate(state)
              state

            condition1 ->
              display_overflow(state.i2c)
              display_calculate(state)
              state

            ans != :error ->
              history = state.history
              size = state.size
              new_history = [{ans, state.data, state.exp, state.x, state.y} | history]
              new_size = size + 1
              display_ans(state.i2c, ans)
              %{state | ans: ans, history: new_history, size: new_size}

            true ->
              display_error(state.i2c)
              display_calculate(state)
              state
          end

        @mode_his ->
          display_current_history(state.i2c, state.pointer, state.history)
          state

        @mode_clr ->
          lcd_clear(state.i2c)
          new_state = %{state | mode: @mode_cal, data: "", exp: [0], ans: 0, pointer: 0, history: [], size: 0, x: 0, y: 0}
          display_calculate_clear(new_state)
          new_state

        _ ->
          IO.puts("Something wrong!")
          state
      end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:change_mode, _from, state) do
    mode = state.mode

    new_state =
      if mode == @mode_his do
        %{state | mode: @mode_cal}
      else
        %{state | mode: mode + 1}
      end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast(_msg, state), do: {:noreply, state}

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  @impl true
  def terminate(_reason, _state), do: :ok

  # LCD Part

  defp i2c_init do
    I2C.open(scl: @gpio_scl, sda: @gpio_sda, clock_speed_hz: @i2c_base_freq)
  end

  defp lcd_send_command(i2c, command) do
    data_u = command &&& 0xF0
    data_l = (command <<< 4) &&& 0xF0

    data1 = data_u ||| 0x0C
    data2 = data_u ||| 0x08
    data3 = data_l ||| 0x0C
    data4 = data_l ||| 0x08

    I2C.begin_transmission(i2c, @lcd_addr)
    I2C.write_byte(i2c, data1)
    I2C.write_byte(i2c, data2)
    I2C.write_byte(i2c, data3)
    I2C.write_byte(i2c, data4)
    I2C.end_transmission(i2c)
  end

  defp lcd_send_data(i2c, data) do
    data_u = data &&& 0xF0
    data_l = (data <<< 4) &&& 0xF0

    data1 = data_u ||| 0x0D
    data2 = data_u ||| 0x09
    data3 = data_l ||| 0x0D
    data4 = data_l ||| 0x09

    I2C.begin_transmission(i2c, @lcd_addr)
    I2C.write_byte(i2c, data1)
    I2C.write_byte(i2c, data2)
    I2C.write_byte(i2c, data3)
    I2C.write_byte(i2c, data4)
    I2C.end_transmission(i2c)
  end

  defp lcd_clear(i2c) do
    lcd_send_command(i2c, 0x01)
    Process.sleep(50)
  end

  defp lcd_init(i2c) do
    delay()
    lcd_send_command(i2c, 0x30)
    delay()
    lcd_send_command(i2c, 0x30)
    delay()
    lcd_send_command(i2c, 0x30)
    delay()
    lcd_send_command(i2c, 0x20)
    delay()
    lcd_send_command(i2c, 0x28)
    delay()
    lcd_send_command(i2c, 0x08)
    delay()
    lcd_send_command(i2c, 0x01)
    delay()
    lcd_send_command(i2c, 0x06)
    delay()
    lcd_send_command(i2c, 0x0C)
  end

  defp delay do
    Process.sleep(100)
  end

  defp lcd_set_cursor(i2c, {x, y}) do
    col =
      case x do
        0 -> 0x00
        1 -> 0x40
        2 -> 0x14
        3 -> 0x54
        _ -> 0x00
      end

    position = if y < 20, do: col + y, else: col
    lcd_send_command(i2c, 0x80 ||| position)
  end

  defp lcd_send_string(_i2c, []), do: :ok

  defp lcd_send_string(i2c, [head | str]) do
    lcd_send_data(i2c, head)
    lcd_send_string(i2c, str)
  end

  # Keypad Part

  defp keypad_init do
    GPIO.set_pin_mode(@gpio_r1, :output)
    GPIO.set_pin_mode(@gpio_r2, :output)
    GPIO.set_pin_mode(@gpio_r3, :output)
    GPIO.set_pin_mode(@gpio_r4, :output)
    GPIO.set_pin_mode(@gpio_c1, :input)
    GPIO.set_pin_mode(@gpio_c2, :input)
    GPIO.set_pin_mode(@gpio_c3, :input)
    GPIO.set_pin_mode(@gpio_c4, :input)
    GPIO.set_pin_pull(@gpio_c1, :up)
    GPIO.set_pin_pull(@gpio_c2, :up)
    GPIO.set_pin_pull(@gpio_c3, :up)
    GPIO.set_pin_pull(@gpio_c4, :up)
  end

  defp keypad_set_col_low(gpiol, gpioh1, gpioh2, gpioh3) do
    GPIO.digital_write(gpiol, :low)
    GPIO.digital_write(gpioh1, :high)
    GPIO.digital_write(gpioh2, :high)
    GPIO.digital_write(gpioh3, :high)
  end

  defp keypad_wait_release(gpio) do
    value = GPIO.digital_read(gpio)

    if value == :high do
      :ok
    else
      keypad_wait_release(gpio)
    end
  end

  defp keypad_scan(pid) do
    keypad_set_col_low(@gpio_r1, @gpio_r2, @gpio_r3, @gpio_r4)
    {r1c1_value, r1c2_value, r1c3_value, r1c4_value} = read_col()

    if r1c1_value == :low do
      keypad_wait_release(@gpio_c1)
      :ok = GenServer.call(pid, {:new_character, @one})
      IO.puts("You press 1")
    else
      if r1c2_value == :low do
        keypad_wait_release(@gpio_c2)
        :ok = GenServer.call(pid, {:new_character, @two})
        IO.puts("You press 2")
      else
        if r1c3_value == :low do
          keypad_wait_release(@gpio_c3)
          :ok = GenServer.call(pid, {:new_character, @three})
          IO.puts("You press 3")
        else
          if r1c4_value == :low do
            t1 = :erlang.system_time(:microsecond)
            keypad_wait_release(@gpio_c4)
            total1 = :erlang.system_time(:microsecond) - t1

            if total1 < 500_000 do
              :ok = GenServer.call(pid, {:new_character, @add})
            else
              :ok = GenServer.call(pid, {:new_character, @open_bracket})
            end

            IO.puts("You press A")
          else
            :ok
          end
        end
      end
    end

    keypad_set_col_low(@gpio_r2, @gpio_r1, @gpio_r3, @gpio_r4)
    {r2c1_value, r2c2_value, r2c3_value, r2c4_value} = read_col()

    if r2c1_value == :low do
      keypad_wait_release(@gpio_c1)
      :ok = GenServer.call(pid, {:new_character, @four})
      IO.puts("You press 4")
    else
      if r2c2_value == :low do
        keypad_wait_release(@gpio_c2)
        :ok = GenServer.call(pid, {:new_character, @five})
        IO.puts("You press 5")
      else
        if r2c3_value == :low do
          keypad_wait_release(@gpio_c3)
          :ok = GenServer.call(pid, {:new_character, @six})
          IO.puts("You press 6")
        else
          if r2c4_value == :low do
            t2 = :erlang.system_time(:microsecond)
            keypad_wait_release(@gpio_c4)
            total2 = :erlang.system_time(:microsecond) - t2

            if total2 < 500_000 do
              :ok = GenServer.call(pid, {:new_character, @sub})
            else
              :ok = GenServer.call(pid, {:new_character, @close_bracket})
            end

            IO.puts("You press B")
          else
            :ok
          end
        end
      end
    end

    keypad_set_col_low(@gpio_r3, @gpio_r1, @gpio_r2, @gpio_r4)
    {r3c1_value, r3c2_value, r3c3_value, r3c4_value} = read_col()

    if r3c1_value == :low do
      keypad_wait_release(@gpio_c1)
      :ok = GenServer.call(pid, {:new_character, @seven})
      IO.puts("You press 7")
    else
      if r3c2_value == :low do
        keypad_wait_release(@gpio_c2)
        :ok = GenServer.call(pid, {:new_character, @eight})
        IO.puts("You press 8")
      else
        if r3c3_value == :low do
          keypad_wait_release(@gpio_c3)
          :ok = GenServer.call(pid, {:new_character, @nine})
          IO.puts("You press 9")
        else
          if r3c4_value == :low do
            t3 = :erlang.system_time(:microsecond)
            keypad_wait_release(@gpio_c4)
            total3 = :erlang.system_time(:microsecond) - t3

            if total3 < 500_000 do
              :ok = GenServer.call(pid, {:new_character, @mul})
            else
              :ok = GenServer.call(pid, {:new_character, @pow})
            end

            IO.puts("You press C")
          else
            :ok
          end
        end
      end
    end

    keypad_set_col_low(@gpio_r4, @gpio_r1, @gpio_r2, @gpio_r1)
    {r4c1_value, r4c2_value, r4c3_value, r4c4_value} = read_col()

    if r4c1_value == :low do
      t4 = :erlang.system_time(:microsecond)
      keypad_wait_release(@gpio_c1)
      total4 = :erlang.system_time(:microsecond) - t4

      if total4 < 500_000 do
        :ok = GenServer.call(pid, :delete_character)
      else
        :ok = GenServer.call(pid, :change_mode)
        :ok = GenServer.call(pid, :display)
      end

      IO.puts("You press *")
    else
      if r4c2_value == :low do
        keypad_wait_release(@gpio_c2)
        :ok = GenServer.call(pid, {:new_character, @zero})
        IO.puts("You press 0")
      else
        if r4c3_value == :low do
          keypad_wait_release(@gpio_c3)
          :ok = GenServer.call(pid, :press_equal)
          IO.puts("You press #")
        else
          if r4c4_value == :low do
            t5 = :erlang.system_time(:microsecond)
            keypad_wait_release(@gpio_c4)
            total5 = :erlang.system_time(:microsecond) - t5

            if total5 < 500_000 do
              :ok = GenServer.call(pid, {:new_character, @dev})
            else
              :ok = GenServer.call(pid, {:new_character, @rem})
            end

            IO.puts("You press D")
          else
            :ok
          end
        end
      end
    end
  end

  defp read_col do
    c1_value = GPIO.digital_read(@gpio_c1)
    c2_value = GPIO.digital_read(@gpio_c2)
    c3_value = GPIO.digital_read(@gpio_c3)
    c4_value = GPIO.digital_read(@gpio_c4)
    {c1_value, c2_value, c3_value, c4_value}
  end

  defp read_keypad(pid) do
    keypad_scan(pid)
    Process.sleep(50)
    read_keypad(pid)
  end

  # Display LCD options

  defp display_calculate(state) do
    i2c = state.i2c
    lcd_set_cursor(i2c, {0, 0})
    lcd_send_string(i2c, '                    ')
    lcd_set_cursor(i2c, {1, 0})
    lcd_send_string(i2c, '                    ')

    data_size = get_list_size(state.data)

    if data_size <= 20 do
      lcd_set_cursor(i2c, {0, 0})
      lcd_send_string(i2c, state.data)
    else
      {data1, data2} = split_list(state.data, [], 0, 20)
      lcd_set_cursor(i2c, {0, 0})
      lcd_send_string(i2c, data1)
      lcd_set_cursor(i2c, {1, 0})
      lcd_send_string(i2c, data2)
    end

    display_ans(i2c, state.ans)
    lcd_set_cursor(i2c, {3, 0})
    lcd_send_string(i2c, 'MODE: CALCULATE')
    state
  end

  defp display_clear(state) do
    i2c = state.i2c
    lcd_set_cursor(i2c, {3, 0})
    lcd_send_string(i2c, 'MODE: CLEAR    ')
    state
  end

  defp display_history(state) do
    i2c = state.i2c
    lcd_set_cursor(i2c, {3, 0})
    lcd_send_string(i2c, 'MODE: HISTORY  ')
    state
  end

  defp display_ans(i2c, ans) do
    lcd_set_cursor(i2c, {2, 0})
    lcd_send_string(i2c, '                   ')
    temp = put_list_end(Integer.to_string(round(ans)), 'Ans: ')
    lcd_set_cursor(i2c, {2, 0})
    lcd_send_string(i2c, temp)
  end

  defp display_error(i2c) do
    lcd_clear(i2c)
    lcd_send_string(i2c, 'Syntax ERROR !')
    Process.sleep(1000)
  end

  defp display_overflow(i2c) do
    lcd_clear(i2c)
    lcd_send_string(i2c, 'Overflow ERROR!')
    Process.sleep(1000)
  end

  defp display_current_history(i2c, pointer, history) do
    lcd_set_cursor(i2c, {0, 0})
    lcd_send_string(i2c, '                    ')
    lcd_set_cursor(i2c, {1, 0})
    lcd_send_string(i2c, '                    ')

    {ans, data, _exp, _x, _y} = get_element_list(pointer, history)
    data_size = get_list_size(data)

    if data_size <= 20 do
      lcd_set_cursor(i2c, {0, 0})
      lcd_send_string(i2c, data)
    else
      {data1, data2} = split_list(data, [], 0, 20)
      lcd_set_cursor(i2c, {0, 0})
      lcd_send_string(i2c, data1)
      lcd_set_cursor(i2c, {1, 0})
      lcd_send_string(i2c, data2)
    end

    lcd_set_cursor(i2c, {2, 0})
    lcd_send_string(i2c, '                   ')
    temp = put_list_end(Integer.to_string(round(ans)), 'Ans: ')
    lcd_set_cursor(i2c, {2, 0})
    lcd_send_string(i2c, temp)
  end

  defp display_new_char(i2c, x, y, char) do
    lcd_set_cursor(i2c, {x, y})
    lcd_send_data(i2c, char)
  end

  defp display_delete_character(i2c, x, y) do
    lcd_set_cursor(i2c, {x, y})
    lcd_send_data(i2c, 32)
  end

  defp display_calculate_clear(state) do
    i2c = state.i2c
    ans = state.ans
    lcd_set_cursor(i2c, {2, 0})
    lcd_send_string(i2c, '                   ')
    temp = put_list_end(Integer.to_string(round(ans)), 'Ans: ')
    lcd_set_cursor(i2c, {2, 0})
    lcd_send_string(i2c, temp)
    lcd_set_cursor(i2c, {3, 0})
    lcd_send_string(i2c, 'MODE: CALCULATE')
  end

  # Calculate the Expression

  defp get_posfix([], output, operator) do
    flag = find_open_brackets(operator)

    if flag do
      :error
    else
      put_list_end(operator, Enum.reverse(output))
    end
  end

  defp get_posfix([head | tail], output, operator) do
    cond do
      is_integer(head) ->
        new_output = [head | output]
        get_posfix(tail, new_output, operator)

      head == "(" ->
        new_operator = [head | operator]
        get_posfix(tail, output, new_operator)

      head == ")" ->
        get_data = handle_parentheses_close(output, operator)

        if get_data == :error do
          :error
        else
          {new_output, new_operator} = get_data
          get_posfix(tail, new_output, new_operator)
        end

      true ->
        {new_output, new_operator} = add_new_element(head, output, operator)
        get_posfix(tail, new_output, new_operator)
    end
  end

  defp handle_parentheses_close(output, operator) do
    top_operator =
      if operator != [] do
        [top_operator | _] = operator
        top_operator
      else
        nil
      end

    cond_val = (top_operator != nil) and (top_operator != "(")

    if cond_val do
      new_output = [top_operator | output]
      [_ | new_operator] = operator
      handle_parentheses_close(new_output, new_operator)
    else
      is_valid = operator != []

      if is_valid do
        if top_operator != "(" do
          :error
        else
          [_ | new_operator] = operator
          {output, new_operator}
        end
      else
        :error
      end
    end
  end

  defp add_new_element(head, output, operator) do
    top_operator =
      if operator != [] do
        [top_operator | _] = operator
        top_operator
      else
        nil
      end

    cond_val = (top_operator != nil) and (get_precendence(top_operator) >= get_precendence(head))

    if cond_val do
      new_output = [top_operator | output]
      [_ | new_operator] = operator
      add_new_element(head, new_output, new_operator)
    else
      new_operator = [head | operator]
      {output, new_operator}
    end
  end

  defp get_precendence(operator) do
    cond0 = (operator == "*") or (operator == "/")
    cond1 = (operator == "+") or (operator == "-")

    cond do
      operator == "^" -> 4
      cond0 -> 3
      cond1 -> 2
      true -> 1
    end
  end

  defp calculate_posfix([], stack) do
    [head | _] = stack
    head
  end

  defp calculate_posfix([h | t], stack) do
    if is_integer(h) do
      new_stack = [h | stack]
      calculate_posfix(t, new_stack)
    else
      [h2, h1 | stack_temp] = stack
      result = get_result(h1, h2, h)
      new_stack = [result | stack_temp]
      calculate_posfix(t, new_stack)
    end
  end

  defp get_result(h1, h2, operator) do
    cond do
      operator == "+" -> h1 + h2
      operator == "-" -> h1 - h2
      operator == "*" -> h1 * h2
      operator == "/" -> h1 / h2
      operator == "^" -> :math.pow(h1, h2)
      operator == "%" -> rem(h1, h2)
      true -> 0
    end
  end

  defp create_infix_list(char, list) do
    special_cond = (list == [0]) and (char == @open_bracket)

    if special_cond do
      [0, "("]
    else
      case char do
        @add -> ["+" | list]
        @sub -> ["-" | list]
        @mul -> ["*" | list]
        @dev -> ["/" | list]
        @pow -> ["^" | list]
        @rem -> ["%" | list]
        @open_bracket -> ["(" | list]
        @close_bracket -> [")" | list]
        _ ->
          [top | tail] = list

          if is_integer(top) do
            number =
              try do
                get_number(char) + top * 10
              rescue
                _ -> top
              end

            [number | tail]
          else
            [get_number(char) | list]
          end
      end
    end
  end

  defp delete_infix_list(list) do
    res =
      if list == [0] do
        list
      else
        [head | tail] = list

        if is_integer(head) do
          if head < 10 do
            tail
          else
            new_head = div(head, 10)
            [new_head | tail]
          end
        else
          tail
        end
      end

    if res == [] do
      [0]
    else
      res
    end
  end

  defp get_number(num) do
    case num do
      @one -> 1
      @two -> 2
      @three -> 3
      @four -> 4
      @five -> 5
      @six -> 6
      @seven -> 7
      @eight -> 8
      @nine -> 9
      @zero -> 0
      _ -> :nan
    end
  end

  # Helper functions

  defp put_element_end(ele, list) do
    temp_list1 = reverse_list(list, [])
    temp_list2 = [ele | temp_list1]
    reverse_list(temp_list2, [])
  end

  defp reverse_list([], list), do: list
  defp reverse_list([h | t], list), do: reverse_list(t, [h | list])

  defp delete_last_element([]), do: []
  defp delete_last_element(list) do
    temp_list1 = reverse_list(list, [])
    [_ | temp_list2] = temp_list1
    reverse_list(temp_list2, [])
  end

  defp put_list_end([], list), do: list
  defp put_list_end([h | t], list) do
    new_list = put_element_end(h, list)
    put_list_end(t, new_list)
  end

  defp get_list_size([]), do: 0
  defp get_list_size([_h | tail]), do: get_list_size(tail) + 1

  defp split_list(res1, res2, len, len), do: {Enum.reverse(res2), res1}
  defp split_list([head | tail], res, number, len), do: split_list(tail, [head | res], number + 1, len)

  defp get_element_list(_pos, []), do: nil
  defp get_element_list(pos, list) do
    size = get_list_size(list)

    if size <= pos do
      nil
    else
      {_, list2} = split_list(list, [], 0, pos)
      [res | _] = list2
      res
    end
  end

  defp handle_change_pointer(char, state) do
    pointer = state.pointer
    size = state.size

    temp_pointer =
      cond do
        char == @two -> pointer + 1
        char == @eight -> pointer - 1
        true -> pointer
      end

    new_pointer =
      cond do
        temp_pointer > (size - 1) -> size - 1
        temp_pointer < 0 -> 0
        true -> temp_pointer
      end

    {ans, data, exp, x, y} = get_element_list(pointer, state.history)
    {data, exp, ans, new_pointer, x, y}
  end

  defp validate_string([last], _flag1, flag2) do
    if (last == "%") and (flag2 == true) do
      false
    else
      true
    end
  end

  defp validate_string([head | tail], flag1, flag2) do
    condition1 = flag1 and flag2
    condition2 = (is_integer(head) == false) and (head != "%")

    cond do
      condition1 ->
        false

      condition2 ->
        validate_string(tail, flag1, true)

      head == "%" ->
        validate_string(tail, true, flag2)

      true ->
        validate_string(tail, flag1, flag2)
    end
  end

  defp find_open_brackets([]), do: false
  defp find_open_brackets([head | tail]) do
    if head == "(" do
      true
    else
      find_open_brackets(tail)
    end
  end
end
