-module(calculator).
-behaviour(gen_server).

-export([start/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
        terminate/2, code_change/3]).

-define(GPIO_SCL, 22).
-define(GPIO_SDA, 21).
-define(I2C_BASE_FREQ, 1000000).
-define(LCD_ADDR, 16#27).

-define(GPIO_R4, 23).
-define(GPIO_R3, 19).
-define(GPIO_R2, 18).
-define(GPIO_R1, 4).
-define(GPIO_C1, 14).
-define(GPIO_C2, 15).
-define(GPIO_C3, 5).
-define(GPIO_C4, 27).

-define(ADD, 2#00101011).
-define(SUB, 2#00101101).
-define(MUL, 2#00101010).
-define(DEV, 2#11111101).

-define(ZERO,   2#00110000).
-define(ONE,    2#00110001).
-define(TWO,    2#00110010).
-define(THREE,  2#00110011).
-define(FOUR,   2#00110100).
-define(FIVE,   2#00110101).
-define(SIX,    2#00110110).
-define(SEVEN,  2#00110111).
-define(EIGHT,  2#00111000).
-define(NINE,   2#00111001).

-define(OPEN_BRACKET, 2#00101000).
-define(CLOSE_BRACKET, 2#00101001).
-define(POW, 2#01011110).
-define(REM, 2#00100101).

-define(MODE_CAL, 0).
-define(MODE_CLR, 1).
-define(MODE_HIS, 2).

-define(DEFAULT, #{}).

-define(SPEC, 0).
-define(NOR, 1).

% X, Y: current pointer of LCD
% pointer: point to position which History is displaying
-record(state, {i2c, mode, data, exp, ans, pointer, history, size, x, y}).

start() ->
    erlang:system_flag(schedulers_online, 2),
    keypad_init(),
    {ok, Pid} = gen_server:start_link(?MODULE, [], []),
    ok = gen_server:call(Pid, display),
    io:format("Init I2C, LCD and Keypad OK~n"),
    read_keypad(Pid).

%%% Gen server Part %%%

init(_) ->
    I2C = i2c_init(),
    lcd_init(I2C),
    NewState = #state{i2c = I2C, mode = ?MODE_CAL, data = "", exp = [0], ans = 0,
                        pointer = 0, history = [], size = 0, x = 0, y = 0},
    {ok, NewState}.

handle_call(display, _From, State) ->
    case State#state.mode of
        ?MODE_CAL ->
            display_calculate(State);
        ?MODE_CLR ->
            display_clear(State);
        ?MODE_HIS ->
            display_history(State);
        true ->
            io:format("Something wrong!~n")
    end,
    {reply, ok, State};

handle_call({new_character, Char}, _From, State) ->
    Mode = State#state.mode,
    case Mode of
        ?MODE_CAL ->
            % Add new character to expression and data (use to display on LCD)
            Data = put_element_end(Char, State#state.data),
            NewExp = create_infix_list(Char, State#state.exp),
            X = State#state.x,
            Y = State#state.y,
            display_new_char(State#state.i2c, X, Y , Char),

            % Update new pointer of LCD
            Cond = (X == 1) and (Y == 19),
            if
                Cond ->
                    NewX = X,
                    NewY = Y;
                (Y + 1) > 19 ->
                    NewX = X + 1,
                    NewY = 0;
                true ->
                    NewX = X,
                    NewY = Y + 1
            end,
            NewState = State#state{data = Data, exp = NewExp, x = NewX, y = NewY};
        ?MODE_HIS ->
            if
                State#state.size =/= 0 ->
                    % Change to the next History if user press "2" or "8"
                    {NewData, NewExp, NewAns, NewPointer, X, Y} = handle_change_pointer(Char, State),

                    % if the character is "5", select that History, else display History
                    if
                        Char == ?FIVE ->
                            NewState = State#state{pointer = NewPointer, mode = ?MODE_CAL,
                                data = NewData, ans = NewAns, exp = NewExp, x = X, y = Y},
                            display_calculate(NewState);
                        true ->
                            display_current_history(State#state.i2c, NewPointer, State#state.history),
                            NewState = State#state{pointer = NewPointer}
                    end;
                true ->
                    NewState = State
            end;
        ?MODE_CLR ->
            NewState = State
    end,
    {reply, ok, NewState};

handle_call(delete_character,  _From, State) ->
    % Delete character from Exp and Data
    Data = delete_last_element(State#state.data),
    NewExp = delete_infix_list(State#state.exp),

    % Update new pointer of LCD
    X = State#state.x,
    Y = State#state.y,
    Cond = (X == 0) and (Y == 0),
    if
        Cond ->
            NewX = X,
            NewY = Y;
        (Y - 1) < 0 ->
            NewY = 19,
            NewX = 0;
        true ->
            NewY = Y - 1,
            NewX = X
    end,

    display_delete_character(State#state.i2c, NewX, NewY),
    NewState = State#state{data = Data, exp = NewExp, x = NewX, y = NewY},
    {reply, ok, NewState};

handle_call(press_equal,  _From, State) ->
    case State#state.mode of
        ?MODE_CAL ->
            % Get Posfix expression from infix expression
            PosFix = get_posfix(lists:reverse(State#state.exp), [], []),

            % Try to calculate if that expression is valid
            Ans =
                try calculate_posfix(PosFix, []) of
                    Temp -> Temp
                catch
                    _:_ -> error
                end,

            % Some condtion to choose which way to display LCD
            Condition0 = (Ans =/= error) andalso (validate_string(PosFix, false, false) == false),
            Condition1 = (Ans =/= error) andalso (Ans > math:pow(10,15)),
            if
                Condition0 ->
                    display_error(State#state.i2c),
                    display_calculate(State),
                    NewState = State;
                Condition1 ->
                    display_overflow(State#state.i2c),
                    display_calculate(State),
                    NewState = State;
                Ans =/= error ->
                    % Store current data to History List
                    History = State#state.history,
                    Size = State#state.size,
                    NewHistory = [{Ans, State#state.data, State#state.exp, State#state.x, State#state.y} | History],
                    NewSize = Size + 1,

                    % Display new answear
                    display_ans(State#state.i2c, Ans),
                    NewState = State#state{ans = Ans, history = NewHistory, size = NewSize};
                true ->
                    display_error(State#state.i2c),
                    display_calculate(State),
                    NewState = State
            end;
        ?MODE_HIS ->
            display_current_history(State#state.i2c, State#state.pointer, State#state.history),
            NewState = State;
        ?MODE_CLR ->
            % Clear the LCD and reset the State of Gen server
            lcd_clear(State#state.i2c),
            NewState = State#state{mode = ?MODE_CAL, data = "", exp = [0], ans = 0,
                    pointer = 0, history = [], size = 0, x = 0, y = 0},
            display_calculate_clear(NewState);
        _ ->
            io:format("Something wrong!~n"),
            NewState = State
    end,
    {reply, ok, NewState};

handle_call(change_mode, _From, State) ->
    Mode = State#state.mode,
    if
        Mode == ?MODE_HIS ->
            NewState = State#state{mode = ?MODE_CAL};
        true ->
            NewState = State#state{mode = Mode + 1}
    end,
    {reply, ok, NewState}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Msg, State) ->
    {noreply, State}.

code_change(_OldVsn, State, _Extra) -> {ok, State}.

terminate(_Reason, _State) ->
    ok.

%%% LCD Part %%%

i2c_init() ->
    i2c:open([{scl, ?GPIO_SCL}, {sda, ?GPIO_SDA}, {clock_speed_hz, ?I2C_BASE_FREQ}]).

lcd_send_command(I2C, Command) ->
    DataU = Command band 16#F0,
    DataL = (Command bsl 4) band 16#F0,

    Data1 = DataU bor 16#0C,
    Data2 = DataU bor 16#08,
    Data3 = DataL bor 16#0C,
    Data4 = DataL bor 16#08,

    i2c:begin_transmission(I2C, ?LCD_ADDR),
    i2c:write_byte(I2C, Data1),
    i2c:write_byte(I2C, Data2),
    i2c:write_byte(I2C, Data3),
    i2c:write_byte(I2C, Data4),
    i2c:end_transmission(I2C).

lcd_send_data(I2C, Data) ->
    DataU = Data band 16#F0,
    DataL = (Data bsl 4) band 16#F0,

    Data1 = DataU bor 16#0D,
    Data2 = DataU bor 16#09,
    Data3 = DataL bor 16#0D,
    Data4 = DataL bor 16#09,

    i2c:begin_transmission(I2C, ?LCD_ADDR),
    i2c:write_byte(I2C, Data1),
    i2c:write_byte(I2C, Data2),
    i2c:write_byte(I2C, Data3),
    i2c:write_byte(I2C, Data4),
    i2c:end_transmission(I2C).

lcd_clear(I2C) ->
    lcd_send_command(I2C, 16#01),
    timer:sleep(50).

lcd_init(I2C) ->
	% 4 bit initialisation

	delay(),  % wait for >40ms
	lcd_send_command(I2C, 16#30),
	delay(),  % wait for >4.1ms
	lcd_send_command(I2C, 16#30),
	delay(),  % wait for >100us
	lcd_send_command(I2C, 16#30),
	delay(),
    % 4 bit mode
	lcd_send_command(I2C, 16#20),
	delay(),

	% Dislay initialisation

    % Function set --> DL=0 (4 bit mode), N = 1 (2 line display) F = 0 (5x8 characters)
	lcd_send_command(I2C, 16#28),
	delay(),
    % Display on/off control --> D=0,C=0, B=0  ---> display off
	lcd_send_command(I2C, 16#08),
	delay(),
    % Clear display
	lcd_send_command(I2C, 16#01),
	delay(),
    % Entry mode set --> I/D = 1 (increment cursor) & no shift
	lcd_send_command(I2C, 16#06),
	delay(),
    % Display on/off control --> D = 1, C and B = 0. (Cursor and blink, last two bits)
	lcd_send_command(I2C, 16#0C).

delay() ->
    % Hardcode delay 100ms to make sure everything done before go to the next instruction
    timer:sleep(100).

lcd_set_cursor(I2C, {X, Y}) ->
    Col = case X of
        0 ->
            16#00;
        1 ->
            16#40;
        2 ->
            16#14;
        3 ->
            16#54;
        _ ->
            16#00
    end,
    if
        Y < 20 ->
            Position = Col + Y;
        true ->
            Position = Col
    end,
    lcd_send_command(I2C, 16#80 bor Position).

lcd_send_string(_I2C, []) ->
    ok;
lcd_send_string(I2C, [Head|Str]) ->
    lcd_send_data(I2C, Head),
    lcd_send_string(I2C, Str).

%%% KEYPAD Part %%%

keypad_init() ->
    gpio:set_pin_mode(?GPIO_R1, output),
    gpio:set_pin_mode(?GPIO_R2, output),
    gpio:set_pin_mode(?GPIO_R3, output),
    gpio:set_pin_mode(?GPIO_R4, output),

    gpio:set_pin_mode(?GPIO_C1, input),
    gpio:set_pin_mode(?GPIO_C2, input),
    gpio:set_pin_mode(?GPIO_C3, input),
    gpio:set_pin_mode(?GPIO_C4, input),

    gpio:set_pin_pull(?GPIO_C1, up),
    gpio:set_pin_pull(?GPIO_C2, up),
    gpio:set_pin_pull(?GPIO_C3, up),
    gpio:set_pin_pull(?GPIO_C4, up).


keypad_set_col_low(GPIOL, GPIOH1, GPIOH2, GPIOH3) ->
    gpio:digital_write(GPIOL, low),
    gpio:digital_write(GPIOH1, high),
    gpio:digital_write(GPIOH2, high),
    gpio:digital_write(GPIOH3, high).

keypad_wait_release(GPIO) ->
    Value = gpio:digital_read(GPIO),
    if
        Value == high ->
            ok;
        true ->
            keypad_wait_release(GPIO)
    end.

keypad_scan(Pid) ->
    % Scan Column R1
    keypad_set_col_low(?GPIO_R1, ?GPIO_R2, ?GPIO_R3, ?GPIO_R4),
    {R1C1_value, R1C2_value, R1C3_value, R1C4_value} = read_col(),
    if
        R1C1_value == low ->
            keypad_wait_release(?GPIO_C1),
            ok = gen_server:call(Pid, {new_character, ?ONE}),
            io:format("You press 1~n");
        R1C2_value == low ->
            keypad_wait_release(?GPIO_C2),
            ok = gen_server:call(Pid, {new_character, ?TWO}),
            io:format("You press 2~n");
        R1C3_value == low ->
            keypad_wait_release(?GPIO_C3),
            ok = gen_server:call(Pid, {new_character, ?THREE}),
            io:format("You press 3~n");
        R1C4_value == low ->
            T1 = erlang:system_time(microsecond),
            keypad_wait_release(?GPIO_C4),
            Total1 = erlang:system_time(microsecond) - T1,
            if
                Total1 < 500000 ->
                    ok = gen_server:call(Pid, {new_character, ?ADD});
                true ->
                    ok = gen_server:call(Pid, {new_character, ?OPEN_BRACKET})
            end,
            io:format("You press A~n");

        true ->
            ok
    end,

    % Scan Column R2
    keypad_set_col_low(?GPIO_R2, ?GPIO_R1, ?GPIO_R3, ?GPIO_R4),
    {R2C1_value, R2C2_value, R2C3_value, R2C4_value} = read_col(),
    if
        R2C1_value == low ->
            keypad_wait_release(?GPIO_C1),
            ok = gen_server:call(Pid, {new_character, ?FOUR}),
            io:format("You press 4~n");
        R2C2_value == low ->
            keypad_wait_release(?GPIO_C2),
            ok = gen_server:call(Pid, {new_character, ?FIVE}),
            io:format("You press 5~n");
        R2C3_value == low ->
            keypad_wait_release(?GPIO_C3),
            ok = gen_server:call(Pid, {new_character, ?SIX}),
            io:format("You press 6~n");
        R2C4_value == low ->
            T2 = erlang:system_time(microsecond),
            keypad_wait_release(?GPIO_C4),
            Total2 = erlang:system_time(microsecond) - T2,
            if
                Total2 < 500000 ->
                    ok = gen_server:call(Pid, {new_character, ?SUB});
                true ->
                    ok = gen_server:call(Pid, {new_character, ?CLOSE_BRACKET})
            end,
            io:format("You press B~n");
        true ->
            ok
    end,

    % Scan Column R3
    keypad_set_col_low(?GPIO_R3, ?GPIO_R1, ?GPIO_R2, ?GPIO_R4),
    {R3C1_value, R3C2_value, R3C3_value, R3C4_value} = read_col(),
    if
        R3C1_value == low ->
            keypad_wait_release(?GPIO_C1),
            ok = gen_server:call(Pid, {new_character, ?SEVEN}),
            io:format("You press 7~n");
        R3C2_value == low ->
            keypad_wait_release(?GPIO_C2),
            ok = gen_server:call(Pid, {new_character, ?EIGHT}),
            io:format("You press 8~n");
        R3C3_value == low ->
            keypad_wait_release(?GPIO_C3),
            ok = gen_server:call(Pid, {new_character, ?NINE}),
            io:format("You press 9~n");
        R3C4_value == low ->
            T3 = erlang:system_time(microsecond),
            keypad_wait_release(?GPIO_C4),
            Total3 = erlang:system_time(microsecond) - T3,
            if
                Total3 < 500000 ->
                    ok = gen_server:call(Pid, {new_character, ?MUL});
                true ->
                    ok = gen_server:call(Pid, {new_character, ?POW})
            end,
            io:format("You press C~n");
        true ->
            ok
    end,

    % Scan Column R4
    keypad_set_col_low(?GPIO_R4, ?GPIO_R1, ?GPIO_R2, ?GPIO_R1),
    {R4C1_value, R4C2_value, R4C3_value, R4C4_value} = read_col(),
    if
        R4C1_value == low ->
            T4 = erlang:system_time(microsecond),
            keypad_wait_release(?GPIO_C1),
            Total4 = erlang:system_time(microsecond) - T4,
            if
                Total4 < 500000 ->
                    ok = gen_server:call(Pid, delete_character);
                true ->
                    ok = gen_server:call(Pid, change_mode),
                    ok = gen_server:call(Pid, display)
            end,
            io:format("You press *~n");
        R4C2_value == low ->
            keypad_wait_release(?GPIO_C2),
            ok = gen_server:call(Pid, {new_character, ?ZERO}),
            io:format("You press 0~n");
        R4C3_value == low ->
            keypad_wait_release(?GPIO_C3),
            ok = gen_server:call(Pid, press_equal),
            io:format("You press #~n");
        R4C4_value == low ->
            T5 = erlang:system_time(microsecond),
            keypad_wait_release(?GPIO_C4),
            Total5 = erlang:system_time(microsecond) - T5,
            if
                Total5 < 500000 ->
                    ok = gen_server:call(Pid, {new_character, ?DEV});
                true ->
                    ok = gen_server:call(Pid, {new_character, ?REM})
            end,
            io:format("You press D~n");
        true ->
            ok
    end.

read_col()->
    C1_value = gpio:digital_read(?GPIO_C1),
    C2_value = gpio:digital_read(?GPIO_C2),
    C3_value = gpio:digital_read(?GPIO_C3),
    C4_value = gpio:digital_read(?GPIO_C4),
    {C1_value, C2_value, C3_value, C4_value}.

read_keypad(Pid) ->
    keypad_scan(Pid),
    timer:sleep(50),
    read_keypad(Pid).

% Some display LCD option
display_calculate(State) ->
    I2C = State#state.i2c,
    % Delete current row
    lcd_set_cursor(I2C, {0, 0}),
    lcd_send_string(I2C, "                    "),
    lcd_set_cursor(I2C, {1, 0}),
    lcd_send_string(I2C, "                    "),

    % Display current data
    DataSize = get_list_size(State#state.data),
    if
        DataSize =< 20 ->
            lcd_set_cursor(I2C, {0, 0}),
            lcd_send_string(I2C, State#state.data);
        true ->
            {Data1, Data2} = split_list(State#state.data, [], 0, 20),
            lcd_set_cursor(I2C, {0, 0}),
            lcd_send_string(I2C, Data1),
            lcd_set_cursor(I2C, {1, 0}),
            lcd_send_string(I2C, Data2)
    end,

    % Diplay current Ans
    display_ans(I2C, State#state.ans),

    % Display current mode
    lcd_set_cursor(I2C, {3, 0}),
    lcd_send_string(I2C, "MODE: CALCULATE"),
    State.

display_clear(State) ->
    I2C = State#state.i2c,
    lcd_set_cursor(I2C, {3, 0}),
    lcd_send_string(I2C, "MODE: CLEAR    "),
    State.

display_history(State) ->
    I2C = State#state.i2c,
    lcd_set_cursor(I2C, {3, 0}),
    lcd_send_string(I2C, "MODE: HISTORY  "),
    State.

display_ans(I2C, Ans) ->
    lcd_set_cursor(I2C, {2, 0}),
    lcd_send_string(I2C, "                   "),
    Temp = put_list_end(integer_to_list(round(Ans)), "Ans: "),
    lcd_set_cursor(I2C, {2, 0}),
    lcd_send_string(I2C, Temp).

display_error(I2C) ->
    lcd_clear(I2C),
    lcd_send_string(I2C, "Syntax ERROR !"),
    timer:sleep(1000).

display_overflow(I2C) ->
    lcd_clear(I2C),
    lcd_send_string(I2C, "Overflow ERROR!"),
    timer:sleep(1000).

display_current_history(I2C, Pointer, History) ->
    % Delete current row
    lcd_set_cursor(I2C, {0, 0}),
    lcd_send_string(I2C, "                    "),
    lcd_set_cursor(I2C, {1, 0}),
    lcd_send_string(I2C, "                    "),

    {Ans, Data, _Exp, _X, _Y} = get_element_list(Pointer, History),
    % Display current data
    DataSize = get_list_size(Data),
    if
        DataSize =< 20 ->
            lcd_set_cursor(I2C, {0, 0}),
            lcd_send_string(I2C, Data);
        true ->
            {Data1, Data2} = split_list(Data, [], 0, 20),
            lcd_set_cursor(I2C, {0, 0}),
            lcd_send_string(I2C, Data1),
            lcd_set_cursor(I2C, {1, 0}),
            lcd_send_string(I2C, Data2)
    end,

    % Display current Ans
    lcd_set_cursor(I2C, {2, 0}),
    lcd_send_string(I2C, "                   "),
    Temp = put_list_end(integer_to_list(round(Ans)), "Ans: "),
    lcd_set_cursor(I2C, {2, 0}),
    lcd_send_string(I2C, Temp).

display_new_char(I2C, X, Y, Char) ->
    lcd_set_cursor(I2C, {X, Y}),
    lcd_send_data(I2C, Char).

display_delete_character(I2C, X, Y) ->
    lcd_set_cursor(I2C, {X, Y}),
    lcd_send_data(I2C, 32).

display_calculate_clear(State) ->
    I2C = State#state.i2c,
    Ans = State#state.ans,
    lcd_set_cursor(I2C, {2, 0}),
    lcd_send_string(I2C, "                   "),
    Temp = put_list_end(integer_to_list(round(Ans)), "Ans: "),
    lcd_set_cursor(I2C, {2, 0}),
    lcd_send_string(I2C, Temp),

    lcd_set_cursor(I2C, {3, 0}),
    lcd_send_string(I2C, "MODE: CALCULATE").

% Calculate the Expression

% Calculate the Posfix exp from Infix exp
% You can read Shunting yard algorithm for more detail
get_posfix([], Output, Operator) ->
    Flag = find_open_brackets(Operator),
    if
        Flag ->
            error;
        true ->
            put_list_end(Operator, lists:reverse(Output))
    end;
get_posfix([Head|Tail], Output, Operator) ->
    if
        is_integer(Head) ->
            NewOutput = [Head|Output],
            get_posfix(Tail, NewOutput, Operator);
        Head == "(" ->
            NewOperator = [Head | Operator],
            get_posfix(Tail, Output, NewOperator);
        Head == ")" ->
            GetData = handle_parentheses_close(Output, Operator),
            if
                GetData == error ->
                    error;
                true ->
                    {NewOutput, NewOperator} = GetData,
                    get_posfix(Tail, NewOutput, NewOperator)
            end;
        true ->
            {NewOutput, NewOperator} = add_new_element(Head, Output, Operator),
            get_posfix(Tail, NewOutput, NewOperator)
    end.


handle_parentheses_close(Output, Operator) ->
    if
        Operator =/= [] ->
            [TopOperator | _] = Operator;
        true ->
            TopOperator = null
    end,

    Cond = (TopOperator =/= null) and (TopOperator =/= "("),
    if
        Cond ->
            NewOutput = [TopOperator|Output],
            [_|NewOperator] = Operator,
            handle_parentheses_close(NewOutput, NewOperator);
        true ->
            IsValid = (Operator =/= []),
            if
                IsValid ->
                    if
                        TopOperator =/= "(" ->
                            error;
                        true ->
                            [_|NewOperator] = Operator,
                            {Output, NewOperator}
                    end;
                true ->
                    error
            end
    end.

add_new_element(Head, Output, Operator) ->
    if
        Operator =/= [] ->
            [TopOperator| _] = Operator;
        true ->
            TopOperator = null
    end,
    Cond = (TopOperator =/= null) and (get_precendence(TopOperator) >= get_precendence(Head)),
    if
        Cond ->
            NewOutput = [TopOperator|Output],
            [_|NewOperator] = Operator,
            add_new_element(Head, NewOutput, NewOperator);
        true ->
            NewOperator = [Head | Operator],
            {Output, NewOperator}
    end.

get_precendence(Operator) ->
    Cond0 = (Operator == "*") or (Operator == "/"),
    Cond1 = (Operator == "+") or (Operator == "-"),
    if
        Operator == "^" ->
            4;
        Cond0 ->
            3;
        Cond1 ->
            2;
        true ->
            1
    end.

% Calculate the Ans from Posfix exp
% If current Element is Number -> add to stack
% Otherwise get two element from stack, calculate the expession and push back to the stack
% Last element in Stack when Posfix is null is the Ans
calculate_posfix([], Stack) ->
    [Head|_] = Stack,
    Head;
calculate_posfix([H|T], Stack) ->
    if
        is_integer(H) ->
            NewStack = [H | Stack],
            calculate_posfix(T, NewStack);
        true ->
            [H2, H1 | StackTemp] = Stack,
            Result = get_result(H1, H2, H),
            NewStack = [Result | StackTemp],
            calculate_posfix(T, NewStack)
    end.

get_result(H1, H2, Operator) ->
    if
        Operator == "+" ->
            H1 + H2;
        Operator == "-" ->
            H1 - H2;
        Operator == "*" ->
            H1 * H2;
        Operator == "/" ->
            H1 / H2;
        Operator == "^" ->
            math:pow(H1, H2);
        Operator == "%" ->
            H1 rem H2;
        true ->
            0
    end.

create_infix_list(Char, List) ->
    SpecialCond = (List == [0]) and (Char == ?OPEN_BRACKET),
    if
        SpecialCond ->
            [0, "("];
        true ->
            case Char of
                ?ADD ->
                    ["+" | List];
                ?SUB ->
                    ["-" | List];
                ?MUL ->
                    ["*" | List];
                ?DEV ->
                    ["/" | List];
                ?POW ->
                    ["^" | List];
                ?REM ->
                    ["%" | List];
                ?OPEN_BRACKET ->
                    ["(" | List];
                ?CLOSE_BRACKET ->
                    [")" | List];
                _ ->
                    [Top | Tail] = List,
                    if
                        is_integer(Top) ->
                            Number =
                                try get_number(Char) + Top * 10 of
                                    Data -> Data
                                catch
                                    _:_ -> Top
                                end,
                            [Number | Tail];
                        true ->
                            [get_number(Char) | List]
                    end
            end
    end.

delete_infix_list(List) ->
    if
        List == [0] ->
            Res = List;
        true ->
            [Head | Tail] = List,
            if
                is_integer(Head) ->
                    if
                        Head < 10 ->
                            Res = Tail;
                        true ->
                            NewHead = Head div 10,
                            Res = [NewHead | Tail]
                    end;
                true ->
                    Res = Tail
            end
    end,
    if
        Res == [] ->
            [0];
        true ->
            Res
    end.


get_number(Num) ->
    case Num of
        ?ONE ->
            1;
        ?TWO ->
            2;
        ?THREE ->
            3;
        ?FOUR ->
            4;
        ?FIVE ->
            5;
        ?SIX ->
            6;
        ?SEVEN ->
            7;
        ?EIGHT ->
            8;
        ?NINE ->
            9;
        ?ZERO ->
            0;
        _ ->
            nan
    end.

% Helper function
put_element_end(Ele, List) ->
    TempList1 = reverse_list(List, []),
    TempList2 = [Ele|TempList1],
    reverse_list(TempList2, []).

reverse_list([], List) ->
    List;
reverse_list([H|T], List) ->
    reverse_list(T, [H|List]).

delete_last_element([]) ->
    [];
delete_last_element(List) ->
    TempList1 = reverse_list(List,[]),
    [_|TempList2] = TempList1,
    reverse_list(TempList2, []).

put_list_end([], List) ->
    List;
put_list_end([H|T], List) ->
    NewList = put_element_end(H, List),
    put_list_end(T, NewList).

get_list_size([]) ->
    0;
get_list_size([_H | Tail]) ->
    get_list_size(Tail) + 1.

split_list(Res1, Res2, Len, Len) ->
    {lists:reverse(Res2), Res1};
split_list([Head | Tail], Res, Number, Len) ->
    split_list(Tail, [Head|Res], Number + 1, Len).

get_element_list(_Pos, []) ->
    null;
get_element_list(Pos, List) ->
    Size = get_list_size(List),
    if
        Size =< Pos ->
            null;
        true ->
            {_, List2} = split_list(List, [], 0, Pos),
            [Res | _] = List2,
            Res
    end.

handle_change_pointer(Char, State) ->
    Pointer = State#state.pointer,
    Size = State#state.size,
    History = State#state.history,
    if
        Char == ?TWO ->
            TempPointer = Pointer + 1;
        Char == ?EIGHT ->
            TempPointer = Pointer - 1;
        true ->
            TempPointer = Pointer
    end,

    if
        TempPointer > (Size - 1) ->
            NewPointer = Size - 1;
        TempPointer < 0 ->
            NewPointer = 0;
        true ->
            NewPointer = TempPointer
    end,

    {Ans, Data, Exp, X, Y} = get_element_list(Pointer, History),
    {Data, Exp, Ans, NewPointer, X, Y}.

% Check if string contain % and the other operator or not
validate_string([Last], _Flag1, Flag2) ->
    if
        (Last == "%") and (Flag2 == true) ->
            false;
        true ->
            true
    end;
validate_string([Head | Tail], Flag1, Flag2) ->
    Condition1 = Flag1 and Flag2,
    Condition2 = (is_integer(Head) == false) and (Head =/= "%"),
    if
        Condition1 ->
            false;
        Condition2 ->
           validate_string(Tail, Flag1, true);
        Head == "%" ->
            validate_string(Tail, true, Flag2);
        true ->
            validate_string(Tail, Flag1, Flag2)
    end.

find_open_brackets([]) ->
    false;
find_open_brackets([Head | Tail]) ->
    if
        Head == "(" ->
            true;
        true ->
            find_open_brackets(Tail)
    end.

