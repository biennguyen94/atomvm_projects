defmodule Calculator do
  @moduledoc false

  import Bitwise
  @behaviour GenServer

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

  defstruct i2c: nil,
            mode: @mode_cal,
            data: "",
            exp: [0],
            ans: 0,
            pointer: 0,
            history: [],
            size: 0,
            x: 0,
            y: 0

  def start do
    :erlang.system_flag(:schedulers_online, 2)
    keypad_init()
    {:ok, pid} = GenServer.start_link(__MODULE__, [], [])
    :ok = GenServer.call(pid, :display)
    IO.puts("Init I2C, LCD and Keypad OK")
    read_keypad(pid)
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(_) do
    i2c = i2c_init()
    lcd_init(i2c)

    state = %__MODULE__{i2c: i2c}
    {:ok, state}
  end

  @impl true
  def handle_call(:display, _from, state) do
    case state.mode do
      @mode_cal ->
        display_calculate(state)

      @mode_clr ->
        display_clear(state)

      @mode_his ->
        display_history(state)

      _ ->
        IO.puts("Something wrong!")
    end

    {:reply, :ok, state}
  end

  def handle_call({:new_character, char}, _from, state) do
    new_state =
      case state.mode do
        @mode_cal ->
          data = put_element_end(char, state.data)
          exp = create_infix_list(char, state.exp)
          x = state.x
          y = state.y
          display_new_char(state.i2c, x, y, char)

          {new_x, new_y} =
            cond do
              x == 1 and y == 19 ->
                {x, y}

              y + 1 > 19 ->
                {x + 1, 0}

              true ->
                {x, y + 1}
            end

          %__MODULE__{state | data: data, exp: exp, x: new_x, y: new_y}

        @mode_his ->
          if state.size != 0 do
            {new_data, new_exp, new_ans, new_pointer, x, y} = handle_change_pointer(char, state)

            if char == @five do
              new_state = %__MODULE__{state | pointer: new_pointer, mode: @mode_cal, data: new_data, ans: new_ans, exp: new_exp, x: x, y: y}
              display_calculate(new_state)
              new_state
            else
              display_current_history(state.i2c, new_pointer, state.history)
              %__MODULE__{state | pointer: new_pointer}
            end
          else
            state
          end

        @mode_clr ->
          state
      end

    {:reply, :ok, new_state}
  end

  def handle_call(:delete_character, _from, state) do
    data = delete_last_element(state.data)
    exp = delete_infix_list(state.exp)
    x = state.x
    y = state.y

    {new_x, new_y} =
      cond do
        x == 0 and y == 0 ->
          {x, y}

        y - 1 < 0 ->
          {0, 19}

        true ->
          {x, y - 1}
      end

    display_delete_character(state.i2c, new_x, new_y)
    new_state = %__MODULE__{state | data: data, exp: exp, x: new_x, y: new_y}
    {:reply, :ok, new_state}
  end

  def handle_call(:press_equal, _from, state) do
    new_state =
      case state.mode do
        @mode_cal ->
          posfix = get_posfix(Enum.reverse(state.exp), [], [])

          ans =
            try do
              calculate_posfix(posfix, [])
            rescue
              _ ->
                :error
            end

          condition0 = ans != :error and validate_string(posfix, false, false) == false
          condition1 = ans != :error and ans > :math.pow(10, 15)

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
              new_history = [{ans, state.data, state.exp, state.x, state.y} | state.history]
              display_ans(state.i2c, ans)
              %__MODULE__{state | ans: ans, history: new_history, size: state.size + 1}

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
          new_state = %__MODULE__{state | mode: @mode_cal, data: "", exp: [0], ans: 0, pointer: 0, history: [], size: 0, x: 0, y: 0}
          display_calculate_clear(new_state)
          new_state

        _ ->
          IO.puts("Something wrong!")
          state
      end

    {:reply, :ok, new_state}
  end

  def handle_call(:change_mode, _from, state) do
    new_state =
      if state.mode == @mode_his do
        %__MODULE__{state | mode: @mode_cal}
      else
        %__MODULE__{state | mode: state.mode + 1}
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

  defp i2c_init do
    :i2c.open([{:scl, @gpio_scl}, {:sda, @gpio_sda}, {:clock_speed_hz, @i2c_base_freq}])
  end

  defp lcd_send_command(i2c, command) do
    data_u = command &&& 0xF0
    data_l = (command <<< 4) &&& 0xF0

    data1 = data_u ||| 0x0C
    data2 = data_u ||| 0x08
    data3 = data_l ||| 0x0C
    data4 = data_l ||| 0x08

    :i2c.begin_transmission(i2c, @lcd_addr)
    :i2c.write_byte(i2c, data1)
    :i2c.write_byte(i2c, data2)
    :i2c.write_byte(i2c, data3)
    :i2c.write_byte(i2c, data4)
    :i2c.end_transmission(i2c)
  end

  defp lcd_send_data(i2c, data) do
    data_u = data &&& 0xF0
    data_l = (data <<< 4) &&& 0xF0

    data1 = data_u ||| 0x0D
    data2 = data_u ||| 0x09
    data3 = data_l ||| 0x0D
    data4 = data_l ||| 0x09

    :i2c.begin_transmission(i2c, @lcd_addr)
    :i2c.write_byte(i2c, data1)
    :i2c.write_byte(i2c, data2)
    :i2c.write_byte(i2c, data3)
    :i2c.write_byte(i2c, data4)
    :i2c.end_transmission(i2c)
  end

  defp lcd_clear(i2c) do
    lcd_send_command(i2c, 0x01)
    :timer.sleep(50)
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

  defp delay, do: :timer.sleep(100)

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

  defp lcd_send_string(i2c, string) when is_binary(string) do
    lcd_send_string(i2c, String.to_charlist(string))
  end

  defp lcd_send_string(_i2c, []), do: :ok

  defp lcd_send_string(i2c, [head | tail]) do
    lcd_send_data(i2c, head)
    lcd_send_string(i2c, tail)
  end

  defp keypad_init do
    :gpio.set_pin_mode(@gpio_r1, :output)
    :gpio.set_pin_mode(@gpio_r2, :output)
    :gpio.set_pin_mode(@gpio_r3, :output)
    :gpio.set_pin_mode(@gpio_r4, :output)

    :gpio.set_pin_mode(@gpio_c1, :input)
    :gpio.set_pin_mode(@gpio_c2, :input)
    :gpio.set_pin_mode(@gpio_c3, :input)
    :gpio.set_pin_mode(@gpio_c4, :input)

    :gpio.set_pin_pull(@gpio_c1, :up)
    :gpio.set_pin_pull(@gpio_c2, :up)
    :gpio.set_pin_pull(@gpio_c3, :up)
    :gpio.set_pin_pull(@gpio_c4, :up)
  end

  defp keypad_set_col_low(gpiol, gpih1, gpih2, gpih3) do
    :gpio.digital_write(gpiol, :low)
    :gpio.digital_write(gpih1, :high)
    :gpio.digital_write(gpih2, :high)
    :gpio.digital_write(gpih3, :high)
  end

  defp keypad_wait_release(gpio) do
    value = :gpio.digital_read(gpio)

    if value == :high do
      :ok
    else
      keypad_wait_release(gpio)
    end
  end

  defp keypad_scan(pid) do
    keypad_set_col_low(@gpio_r1, @gpio_r2, @gpio_r3, @gpio_r4)
    {r1c1, r1c2, r1c3, r1c4} = read_col()

    cond do
      r1c1 == :low ->
        keypad_wait_release(@gpio_c1)
        :ok = GenServer.call(pid, {:new_character, @one})
        IO.puts("You press 1")

      r1c2 == :low ->
        keypad_wait_release(@gpio_c2)
        :ok = GenServer.call(pid, {:new_character, @two})
        IO.puts("You press 2")

      r1c3 == :low ->
        keypad_wait_release(@gpio_c3)
        :ok = GenServer.call(pid, {:new_character, @three})
        IO.puts("You press 3")

      r1c4 == :low ->
        t1 = :erlang.system_time(:microsecond)
        keypad_wait_release(@gpio_c4)
        total1 = :erlang.system_time(:microsecond) - t1

        if total1 < 500_000 do
          :ok = GenServer.call(pid, {:new_character, @add})
        else
          :ok = GenServer.call(pid, {:new_character, @open_bracket})
        end

        IO.puts("You press A")

      true ->
        :ok
    end

    keypad_set_col_low(@gpio_r2, @gpio_r1, @gpio_r3, @gpio_r4)
    {r2c1, r2c2, r2c3, r2c4} = read_col()

    cond do
      r2c1 == :low ->
        keypad_wait_release(@gpio_c1)
        :ok = GenServer.call(pid, {:new_character, @four})
        IO.puts("You press 4")

      r2c2 == :low ->
        keypad_wait_release(@gpio_c2)
        :ok = GenServer.call(pid, {:new_character, @five})
        IO.puts("You press 5")

      r2c3 == :low ->
        keypad_wait_release(@gpio_c3)
        :ok = GenServer.call(pid, {:new_character, @six})
        IO.puts("You press 6")

      r2c4 == :low ->
        t2 = :erlang.system_time(:microsecond)
        keypad_wait_release(@gpio_c4)
        total2 = :erlang.system_time(:microsecond) - t2

        if total2 < 500_000 do
          :ok = GenServer.call(pid, {:new_character, @sub})
        else
          :ok = GenServer.call(pid, {:new_character, @close_bracket})
        end

        IO.puts("You press B")

      true ->
        :ok
    end

    keypad_set_col_low(@gpio_r3, @gpio_r1, @gpio_r2, @gpio_r4)
    {r3c1, r3c2, r3c3, r3c4} = read_col()

    cond do
      r3c1 == :low ->
        keypad_wait_release(@gpio_c1)
        :ok = GenServer.call(pid, {:new_character, @seven})
        IO.puts("You press 7")

      r3c2 == :low ->
        keypad_wait_release(@gpio_c2)
        :ok = GenServer.call(pid, {:new_character, @eight})
        IO.puts("You press 8")

      r3c3 == :low ->
        keypad_wait_release(@gpio_c3)
        :ok = GenServer.call(pid, {:new_character, @nine})
        IO.puts("You press 9")

      r3c4 == :low ->
        t3 = :erlang.system_time(:microsecond)
        keypad_wait_release(@gpio_c4)
        total3 = :erlang.system_time(:microsecond) - t3

        if total3 < 500_000 do
          :ok = GenServer.call(pid, {:new_character, @mul})
        else
          :ok = GenServer.call(pid, {:new_character, @pow})
        end

        IO.puts("You press C")

      true ->
        :ok
    end

    keypad_set_col_low(@gpio_r4, @gpio_r1, @gpio_r2, @gpio_r1)
    {r4c1, r4c2, r4c3, r4c4} = read_col()

    cond do
      r4c1 == :low ->
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

      r4c2 == :low ->
        keypad_wait_release(@gpio_c2)
        :ok = GenServer.call(pid, {:new_character, @zero})
        IO.puts("You press 0")

      r4c3 == :low ->
        keypad_wait_release(@gpio_c3)
        :ok = GenServer.call(pid, :press_equal)
        IO.puts("You press #")

      r4c4 == :low ->
        t5 = :erlang.system_time(:microsecond)
        keypad_wait_release(@gpio_c4)
        total5 = :erlang.system_time(:microsecond) - t5

        if total5 < 500_000 do
          :ok = GenServer.call(pid, {:new_character, @dev})
        else
          :ok = GenServer.call(pid, {:new_character, @rem})
        end

        IO.puts("You press D")

      true ->
        :ok
    end
  end

  defp read_col do
    c1 = :gpio.digital_read(@gpio_c1)
    c2 = :gpio.digital_read(@gpio_c2)
    c3 = :gpio.digital_read(@gpio_c3)
    c4 = :gpio.digital_read(@gpio_c4)
    {c1, c2, c3, c4}
  end

  defp read_keypad(pid) do
    keypad_scan(pid)
    :timer.sleep(50)
    read_keypad(pid)
  end

  defp display_calculate(state) do
    i2c = state.i2c
    lcd_set_cursor(i2c, {0, 0})
    lcd_send_string(i2c, "                    ")
    lcd_set_cursor(i2c, {1, 0})
    lcd_send_string(i2c, "                    ")

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
    lcd_send_string(i2c, "MODE: CALCULATE")
    state
  end

  defp display_clear(state) do
    i2c = state.i2c
    lcd_set_cursor(i2c, {3, 0})
    lcd_send_string(i2c, "MODE: CLEAR    ")
    state
  end

  defp display_history(state) do
    i2c = state.i2c
    lcd_set_cursor(i2c, {3, 0})
    lcd_send_string(i2c, "MODE: HISTORY  ")
    state
  end

  defp display_ans(i2c, ans) do
    lcd_set_cursor(i2c, {2, 0})
    lcd_send_string(i2c, "                   ")
    temp = put_list_end(Integer.to_string(round(ans)), "Ans: ")
    lcd_set_cursor(i2c, {2, 0})
    lcd_send_string(i2c, temp)
  end

  defp display_error(i2c) do
    lcd_clear(i2c)
    lcd_send_string(i2c, "Syntax ERROR !")
    :timer.sleep(1000)
  end

  defp display_overflow(i2c) do
    lcd_clear(i2c)
    lcd_send_string(i2c, "Overflow ERROR!")
    :timer.sleep(1000)
  end

  defp display_current_history(i2c, pointer, history) do
    lcd_set_cursor(i2c, {0, 0})
    lcd_send_string(i2c, "                    ")
    lcd_set_cursor(i2c, {1, 0})
    lcd_send_string(i2c, "                    ")

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
    lcd_send_string(i2c, "                   ")
    temp = put_list_end(Integer.to_string(round(ans)), "Ans: ")
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
    lcd_send_string(i2c, "                   ")
    temp = put_list_end(Integer.to_string(round(ans)), "Ans: ")
    lcd_set_cursor(i2c, {2, 0})
    lcd_send_string(i2c, temp)
    lcd_set_cursor(i2c, {3, 0})
    lcd_send_string(i2c, "MODE: CALCULATE")
  end

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
        get_posfix(tail, [head | output], operator)

      head == "(" ->
        get_posfix(tail, output, [head | operator])

      head == ")" ->
        case handle_parentheses_close(output, operator) do
          :error ->
            :error

          {new_output, new_operator} ->
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
        hd(operator)
      else
        nil
      end

    cond do
      top_operator != nil and top_operator != "(" ->
        new_output = [top_operator | output]
        [_ | new_operator] = operator
        handle_parentheses_close(new_output, new_operator)

      operator != [] ->
        if top_operator != "(" do
          :error
        else
          [_ | new_operator] = operator
          {output, new_operator}
        end

      true ->
        :error
    end
  end

  defp add_new_element(head, output, operator) do
    top_operator = if operator != [], do: hd(operator), else: nil

    cond do
      top_operator != nil and get_precendence(top_operator) >= get_precendence(head) ->
        new_output = [top_operator | output]
        [_ | new_operator] = operator
        add_new_element(head, new_output, new_operator)

      true ->
        {output, [head | operator]}
    end
  end

  defp get_precendence(operator) do
    cond do
      operator == "^" -> 4
      operator in ["*", "/"] -> 3
      operator in ["+", "-"] -> 2
      true -> 1
    end
  end

  defp calculate_posfix([], [head | _]), do: head

  defp calculate_posfix([h | t], stack) do
    if is_integer(h) do
      calculate_posfix(t, [h | stack])
    else
      [h2, h1 | stack_temp] = stack
      result = get_result(h1, h2, h)
      calculate_posfix(t, [result | stack_temp])
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
    special_cond = list == [0] and char == @open_bracket

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
            [div(head, 10) | tail]
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
    cond do
      num == @one -> 1
      num == @two -> 2
      num == @three -> 3
      num == @four -> 4
      num == @five -> 5
      num == @six -> 6
      num == @seven -> 7
      num == @eight -> 8
      num == @nine -> 9
      num == @zero -> 0
      true -> :nan
    end
  end

  defp put_element_end(ele, list) do
    list
    |> reverse_list([])
    |> prepend(ele)
    |> reverse_list([])
  end

  defp prepend(list, ele), do: [ele | list]

  defp reverse_list([], list), do: list
  defp reverse_list([h | t], list), do: reverse_list(t, [h | list])

  defp delete_last_element([]), do: []

  defp delete_last_element(list) do
    list |> reverse_list([]) |> tl() |> reverse_list([])
  end

  defp put_list_end([], list), do: list

  defp put_list_end([h | t], list) do
    new_list = put_element_end(h, list)
    put_list_end(t, new_list)
  end

  defp get_list_size([]), do: 0
  defp get_list_size([_ | tail]), do: get_list_size(tail) + 1

  defp split_list(res1, res2, len, len), do: {Enum.reverse(res2), res1}

  defp split_list([head | tail], res, number, len) do
    split_list(tail, [head | res], number + 1, len)
  end

  defp get_element_list(_pos, []), do: :null

  defp get_element_list(pos, list) do
    size = get_list_size(list)

    if size <= pos do
      :null
    else
      {_, list2} = split_list(list, [], 0, pos)
      [res | _] = list2
      res
    end
  end

  defp handle_change_pointer(char, state) do
    pointer = state.pointer
    size = state.size
    history = state.history

    temp_pointer =
      cond do
        char == @two -> pointer + 1
        char == @eight -> pointer - 1
        true -> pointer
      end

    new_pointer =
      cond do
        temp_pointer > size - 1 -> size - 1
        temp_pointer < 0 -> 0
        true -> temp_pointer
      end

    {ans, data, exp, x, y} = get_element_list(pointer, history)
    {data, exp, ans, new_pointer, x, y}
  end

  defp validate_string([last], _flag1, flag2) do
    if last == "%" and flag2 do
      false
    else
      true
    end
  end

  defp validate_string([head | tail], flag1, flag2) do
    condition1 = flag1 and flag2
    condition2 = not is_integer(head) and head != "%"

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
