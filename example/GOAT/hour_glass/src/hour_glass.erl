-module(hour_glass).

-export([start/0, mpu_read_data/1, hour_glass/1, read/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
        terminate/2, code_change/3]).

-include("global.hrl").

start() ->
    erlang:system_flag(schedulers_online, 2),
    % Setup MPU
    I2C = i2c_init(),
    mpu_config(I2C),
    {ok, Pid} = gen_server:start(?MODULE, [], []),

    spawn(?MODULE, hour_glass, [Pid]),

    read(Pid, I2C, ?TOP).

init(_) ->
    {ok, SPI} = init_max7219(?SPISettings),

    % Currently we will turn of two led
    write_digit(SPI, ?DIGIT_0, ?EMPTY_MATRIX, device_1),
    write_digit(SPI, ?DIGIT_0, ?DEFAULT_MATRIX, device_2),

    State = #state{spi = SPI, data1 = ?EMPTY_MATRIX, data2 = ?DEFAULT_MATRIX, timer = 0,
                    predata1 = ?EMPTY_MATRIX, predata2 = ?EMPTY_MATRIX, direction = top, isstop = false},
    io:format("Init SPI and MAX7219 OK~n ~n"),
    {ok, State}.

handle_call(print_test, _From, State) ->
    if
        State#state.isstop ->
            {reply, ok, State};
        true ->
            T1 = erlang:system_time(microsecond),
            {NewData1, NewData2} = update_data(0, State#state.spi, State#state.data1, State#state.data2,
                State#state.direction),
            if
                State#state.timer == 1 ->
                    Timer = 0,
                    Flag = true,
                    {LastData1, LastData2} = drop_seed(State#state.spi, State#state.direction, NewData1, NewData2);
                true ->
                    Timer = State#state.timer + 1,
                    Flag = false,
                    {LastData1, LastData2} = {NewData1, NewData2}
            end,
            Condition = ((LastData1 == State#state.predata1) and (LastData2 == State#state.predata2)) and Flag,
            if
                Condition ->
                    io:format("END~n"),
                    NewState = State#state{data1 = LastData1, data2 = LastData2, timer = 0,
                            predata1 = ?EMPTY_MATRIX, predata2 = ?EMPTY_MATRIX, direction = State#state.direction, isstop = true};
                true ->
                    NewState = State#state{data1 = LastData1, data2 = LastData2,
                                            predata1 = State#state.data1, predata2 = State#state.data2, timer = Timer}
            end,
            T2 = erlang:system_time(microsecond),
            io:format("Delay ~p ~n", [T2 - T1]),
            {reply, ok, NewState}
    end;

handle_call(_Msg, _From, State) ->
    {reply, ok, State}.

handle_cast({change_direction, Dir}, State) ->
    NewState = State#state{direction = Dir, isstop = false, predata1 = ?EMPTY_MATRIX, predata2 = ?EMPTY_MATRIX},
    {noreply, NewState}.

handle_info(_Msg, State) ->
    {noreply, State}.

code_change(_OldVsn, State, _Extra) -> {ok, State}.

terminate(_Reason, _State) ->
    ok.

%%% Hour Glass Control %%%

get_left({X, Y}) ->
    {X - 1, Y}.

get_right({X, Y}) ->
    {X, Y + 1}.

get_down({X, Y}) ->
    {X - 1, Y + 1}.

% Get led {X, Y} turn on or off
get_x_y_raw(Data, {X, Y}) ->
    Row = maps:get(X + 1, Data),
    Temp = (Row bsl Y) band 128,
    if
        Temp == 128 ->
            ?YES;
        true ->
            ?NO
    end.

% Get led transform {X, Y} turn on or off
get_x_y(Data, {X, Y}, Dir) ->
    {NewX, NewY} = transform({X, Y}, Dir),
    get_x_y_raw(Data, {NewX, NewY}).

% Set led transform {X, Y} turn on / off
set_x_y(SPI, Device, Data, {X, Y}, Dir, ?YES) ->
    {NewX, NewY} = transform({X, Y}, Dir),
    set_x_y_raw(SPI, Device, Data, {NewX, NewY}, ?YES);
set_x_y(SPI, Device, Data, {X, Y}, Dir, ?NO) ->
    {NewX, NewY} = transform({X, Y}, Dir),
    set_x_y_raw(SPI, Device, Data, {NewX, NewY}, ?NO).

% Set led {X, Y} turn on / off
set_x_y_raw(SPI, Device, Data, {X, Y}, ?YES) ->
    Row = maps:get(X + 1, Data),
    Temp = (128 bsr Y) bor Row,
    write_register(SPI, X + 1, Temp, Device),
    Data#{X + 1 := Temp};
set_x_y_raw(SPI, Device, Data, {X, Y}, ?NO) ->
    Row = maps:get(X + 1, Data),
    Temp = (bnot (128 bsr Y)) band Row,
    write_register(SPI, X + 1, Temp, Device),
    Data#{X + 1 := Temp}.

% Transform {X, Y} according to current Direction
transform({X, Y}, Dir) ->
    if
        Dir == right ->
            rotate_right({X, Y});
        Dir == top ->
            rotate_top({X, Y});
        Dir == left ->
            rotate_left({X, Y});
        true ->
            {X, Y}
    end.

flip_horizontally({X, Y}) ->
    {7 - X, Y}.

flip_vertically({X, Y}) ->
    {X, 7 - Y}.

rotate_right({X, Y}) ->
    NewX = Y,
    NewY = X,
    flip_horizontally({NewX, NewY}).

rotate_top({X, Y}) ->
    flip_horizontally(flip_vertically({X, Y})).

rotate_left({X, Y}) ->
    rotate_top(rotate_right({X, Y})).

% Check if you can go to next positon or not
can_go_left(Data, {X, Y}, Dir) ->
    if
        X == 0 ->
            ?NO;
        true ->
            0 - get_x_y(Data, get_left({X, Y}), Dir)
    end.

can_go_right(Data, {X, Y}, Dir) ->
    if
        Y == 7 ->
            ?NO;
        true ->
            0 - get_x_y(Data, get_right({X, Y}), Dir)
    end.

can_go_down(Data, {X, Y}, Dir) ->
    Cond0 = can_go_left(Data, {X, Y}, Dir),
    Cond1 = can_go_right(Data, {X, Y}, Dir),
    if
        Y == 7 ->
            ?NO;
        X == 0 ->
            ?NO;
        Cond0 == ?NO ->
            ?NO;
        Cond1 == ?NO ->
            ?NO;
        true ->
            0 - get_x_y(Data, get_down({X, Y}), Dir)
    end.

% Change led's status according to the position you want to change
go_down(SPI, Dev, Data, {X, Y}, Dir) ->
    DelSeed = set_x_y(SPI, Dev, Data, {X, Y}, Dir, ?NO),
    NewData = set_x_y(SPI, Dev,DelSeed, get_down({X, Y}), Dir, ?YES),
    NewData.

go_left(SPI, Dev, Data, {X, Y}, Dir) ->
    DelSeed = set_x_y(SPI, Dev,Data, {X, Y}, Dir, ?NO),
    NewData = set_x_y(SPI, Dev,DelSeed, get_left({X, Y}), Dir, ?YES),
    NewData.

go_right(SPI, Dev, Data, {X, Y}, Dir) ->
    DelSeed = set_x_y(SPI, Dev,Data, {X, Y}, Dir, ?NO),
    NewData = set_x_y(SPI, Dev,DelSeed, get_right({X, Y}), Dir, ?YES),
    NewData.

toggle_x_y(SPI, Dev, Data, {X, Y}) ->
    NewData = set_x_y_raw(SPI, Dev, Data, {X, Y}, 0 - get_x_y_raw(Data, {X, Y})),
    NewData.

% Move seed to new position if it can move
move_seed(SPI, Dev, Data, {X, Y}, Dir) ->
    IsExit = get_x_y(Data, {X, Y}, Dir),
    Left = can_go_left(Data, {X, Y}, Dir),
    Right = can_go_right(Data, {X, Y}, Dir),
    Down = can_go_down(Data, {X, Y}, Dir),
    Cond0 = (Left == ?NO) and (Right == ?NO),
    Cond1 = (Left == ?NO) and (Right == ?YES),
    Cond2 = (Left == ?YES) and (Right == ?NO),
    Cond3 = rand_led() == 1,
    if
        IsExit == ?NO ->
            Data;
        Cond0 ->
            Data;
        Down == ?YES ->
            go_down(SPI, Dev, Data, {X, Y}, Dir);
        Cond1 ->
            go_right(SPI, Dev, Data, {X, Y}, Dir);
        Cond2 or Cond3 ->
            go_left(SPI, Dev, Data, {X, Y}, Dir);
        true ->
            go_right(SPI, Dev, Data, {X, Y}, Dir)
    end.

% Drop from top Led to Bottom Led
drop_seed(SPI, Dir, Data1, Data2) ->
    Cond0 = (Dir == ?TOP) or (Dir == ?BOTTOM),
    Temp0 = get_x_y_raw(Data1, {0, 7}),
    Temp1 = get_x_y_raw(Data2, {7, 0}),
    Cond1 = (Temp0 == ?YES) and (Temp1 == ?NO),
    Cond2 = (Temp0 == ?NO) and (Temp1 == ?YES),
    Condition = Cond0 and (Cond1 or Cond2),
    if
        Condition ->
            NewData1 = toggle_x_y(SPI, device_1, Data1, {0, 7}),
            NewData2 = toggle_x_y(SPI, device_2, Data2, {7, 0});
        true ->
            NewData1 = Data1,
            NewData2 = Data2
    end,
    {NewData1, NewData2}.

% Loop from bottom of 2 Led to the Top of Led, check each element if it can move or not
update_data(?MAX_ROW, _SPI, Data1, Data2, _Dir) ->
    {Data1, Data2};
update_data(Num, SPI, Data1, Data2, Dir) ->
    Rand = rand_led(),
    if
        Num < 8 ->
            It = 0;
        true ->
            It = Num - 7
    end,
    {NewData1, NewData2} = update_x_y(Num, Rand, It, Num - It + 1, SPI, Data1, Data2, Dir),
    update_data(Num + 1, SPI, NewData1, NewData2, Dir).

update_x_y(_Num, _Rand, It, It, _SPI, Data1, Data2, _Dir) ->
    {Data1, Data2};
update_x_y(Num, 1, Times, It, SPI, Data1, Data2, Dir) ->
    Y = Num - Times,
    X = 7 - Times,
    {{X1, Y1}, {X2, Y2}} = get_position({X, Y}, Dir),
    NewData1 = move_seed(SPI, device_1, Data1, {X1, Y1}, Dir),
    NewData2 = move_seed(SPI, device_2, Data2, {X2, Y2}, Dir),
    update_x_y(Num, 1, Times + 1, It, SPI, NewData1, NewData2, Dir);
update_x_y(Num, 0, Times, It, SPI, Data1, Data2, Dir) ->
    Y = Times,
    X = (7 - (Num - Times)),
    {{X1, Y1}, {X2, Y2}} = get_position({X, Y}, Dir),
    NewData1 = move_seed(SPI, device_1, Data1, {X1, Y1}, Dir),
    NewData2 = move_seed(SPI, device_2, Data2, {X2, Y2}, Dir),
    update_x_y(Num, 0, Times + 1, It, SPI, NewData1, NewData2, Dir).

% Random 0 or 1
rand_led() ->
    Value = atomvm:random(),
    if
        Value >= 0 ->
            1;
        true ->
            0
    end.

get_position({X, Y}, Dir) ->
    if
        Dir == ?TOP ->
            {{X, Y}, {Y, X}};
        Dir == ?BOTTOM ->
            {{Y, X}, {X, Y}};
        Dir == ?LEFT ->
            NewY = (Y + 7) rem 8,
            {{NewY, X}, {NewY, X}};
        true ->
            NewX = (X + 7) rem 8,
            {{Y, NewX}, {Y, NewX}}
    end.


%%% SPI and MAX7219 part %%%

init_max7219(SPISettings) ->
    SPI = spi:open(SPISettings),
    write_register(SPI, ?DECODE_MODE, 16#0, device_1),    % No decoding
    write_register(SPI, ?INTENSITY, 16#3, device_1),      % Brightness intensity
    write_register(SPI, ?SCAN_LIMIT, 16#7, device_1),     % Scan limit = 8 LEDs
    write_register(SPI, ?SHUTDOWN, 16#1, device_1),       % Power down = 0, Normal mode = 1
    write_register(SPI, ?DISPLAY_TEST, 16#0, device_1),   % No display Test

    write_register(SPI, ?DECODE_MODE, 16#0, device_2),    % No decoding
    write_register(SPI, ?INTENSITY, 16#3, device_2),      % Brightness intensity
    write_register(SPI, ?SCAN_LIMIT, 16#7, device_2),     % Scan limit = 8 LEDs
    write_register(SPI, ?SHUTDOWN, 16#1, device_2),       % Power down = 0, Normal mode = 1
    write_register(SPI, ?DISPLAY_TEST, 16#0, device_2),   % No display Test
    {ok, SPI}.

% Recursive to write Data from Digit 1 to 8
write_digit(SPI, 8, Data, Device) ->
    RegData = maps:get(8, Data),
    write_register(SPI, 8, RegData, Device),
    ok;
write_digit(SPI, Number, Data, Device) ->
    RegData = maps:get(Number, Data),
    write_register(SPI, Number, RegData, Device),
    write_digit(SPI, Number + 1, Data, Device).

write_register(SPI, Address, Data, Device) ->
    spi:write_at(SPI, Device, Address, ?NUM_OF_BITS, Data).

%%% MPU part %%%
% Read value from MPU and calculate current Angle
i2c_init() ->
    i2c:open([{scl, ?GPIO_SCL}, {sda, ?GPIO_SDA}, {clock_speed_hz, ?BASE_FREQ}]).

mpu_config(I2C) ->
    mpu_send_command(I2C, ?ACC_CONFIG_ADDR, ?ACC_FULL_SCALE_16_G).

mpu_send_command(I2C, Register, Command) ->
    i2c:begin_transmission(I2C, ?MPU9250_ADDR),
    i2c:write_byte(I2C, Register),
    i2c:write_byte(I2C, Command),
    i2c:end_transmission(I2C).

% Return bitstring, format: <<AccX and AccY>>
mpu_read_data(I2C) ->
    i2c:begin_transmission(I2C, ?MPU9250_ADDR),
    i2c:write_byte(I2C, ?ACC_ADDR),
    i2c:end_transmission(I2C),
    i2c:read_bytes(I2C, ?MPU9250_ADDR, ?NUM_BYTE).

read(Pid, I2C, Dir) ->
    {ok, Val} = mpu_read_data(I2C),
    % Extract bit with format <<Acc:48, Temp:16, Gyro:48>>
    <<AccX:16/integer-signed, AccY:16/integer-signed>> = Val,

    Angle = math:atan2(AccX * ?ACC_SCALE, AccY * ?ACC_SCALE) * ?RADIAN_TO_DEGREE,
    Direction = get_direction(Angle),
    Condition = (Dir =/= Direction) and (Direction =/= ?MIDDLE),
    if
        Condition ->
            io:format("Send Request~n"),
            gen_server:cast(Pid, {change_direction, Direction}),
            timer:sleep(100),
            read(Pid, I2C, Direction);
        true ->
            timer:sleep(100),
            read(Pid, I2C, Dir)
    end.

% Conver the Angle to the Direction
get_direction(Angle) ->
    Cond0 = (Angle =< -80) and (Angle >= -100),
    Cond1 = (Angle =< 180) and (Angle >= 160),
    Cond2 = (Angle =< 10) and (Angle >= -10),
    Cond3 = (Angle =< 90) and (Angle >= 80),
    if
        Cond0 ->
            ?TOP;
        Cond1 ->
            ?LEFT;
        Cond2 ->
            ?RIGHT;
        Cond3 ->
            ?BOTTOM;
        true ->
            ?MIDDLE
    end.

% Hour glass process function callback
hour_glass(Pid) ->
    ok = gen_server:call(Pid, print_test),
    hour_glass(Pid).
