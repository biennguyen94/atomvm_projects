-module(block_breaker_2led).

-include("global.hrl").

-export([start/0, joystick/3, variable_resistor/3, game_over_process/2, game_win_process/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
        terminate/2, code_change/3]).

-define(DELAY_READ_ADC, 100).
-define(MAX_SPEED, 100).
-define(MIN_SPEED, 1000).
-define(BIT_RESOLUTION, 4095).

-define(LED0, 0).
-define(LED1, 1).

-record(state, {spi, crossbar, ball, direction, point, data1, data2, isgameover, goverproc, score}).

-define(NUM_OF_BITS, 8).

-define(DEVICE_NAME, device_1).

-define(SPISettings, [
    {bus_config, [
        {miso_io_num, 19},
        {mosi_io_num, 27},
        {sclk_io_num, 5}
    ]},
    {device_config, [
        {device_1, [
            {spi_clock_hz, 1000000},
            {mode, 0},
            {spi_cs_io_num, 18},
            {address_len_bits, 8}
        ]},
        {device_2, [
            {spi_clock_hz, 1000000},
            {mode, 0},
            {spi_cs_io_num, 23},
            {address_len_bits, 8}
        ]}
    ]}
]).

start() ->
    % Start gen server and spi peripheral
    {ok, P} = gen_server:start(?MODULE, [], []),
    gen_server:cast(P, update_game),

    % % Setup ADC to read Joystick
    {ADCX, ADCY} = setup_adc(),
    spawn(?MODULE, joystick, [P, ADCX, ADCY]),

    % Setup ADC to read polimeter
    {ok, VRes} = adc:start(?GPIO_RESISTOR, [{attenuation, db_11}, {bit_width, bit_12}]),
    spawn(?MODULE, variable_resistor, [self(), VRes, ?MAX_SPEED]),

    % io:format("INIT OK ~n"),
    % % move ball
    ball(P, 150).

init(_) ->
    {ok, SPI} = init_max7219(?SPISettings),
    init_sw_interrupt(),
    % Default setup when start the game
    State = #state{spi = SPI, crossbar = ?CROSS_BAR, data1 = ?EMPTY_MATRIX, data2 = ?EMPTY_MATRIX, score = 0, goverproc = undefined,
                point = ?DEFAULT_POINT, ball = ?BALL, direction = {-1, 1}, isgameover = false},
    io:format("Init SPI and MAX7219 OK ~p ~n", [?CROSS_BAR]),
    {ok, State}.

handle_call(_Msg, _From, State) ->
    {reply, ok, State}.

% Update game with current State of Gen server
handle_cast(update_game, State) ->
    % Add cross bar to Data
    {Temp1, Temp2} = update_data(State#state.crossbar, {State#state.data1, State#state.data2}, 0, 3),

    % Add ball to data
    {Temp3, Temp4} = update_data(State#state.ball, {Temp1, Temp2}, 0, 1),

    % Add Point to data
    {Temp5, Temp6} = update_data(State#state.point, {Temp3, Temp4}, 0, ?MAX_POINT),

    % Print data to led matrix
    write_digit(State#state.spi, ?DIGIT_0, Temp5, device_1),
    write_digit(State#state.spi, ?DIGIT_0, Temp6, device_2),
    NewState = State#state{data1 = Temp5, data2 = Temp6},
    {noreply, NewState};

% Handle reset game
handle_cast(reset_game, State) ->
    NewState = State#state{crossbar = ?CROSS_BAR, data1 = ?EMPTY_MATRIX, data2 = ?EMPTY_MATRIX, score = 0, goverproc = undefined,
                point = ?DEFAULT_POINT, ball = ?BALL, direction = {-1, 1}, isgameover = false},
    {noreply, NewState};

% Move cross bar according to the controll by Joystick
% Delete current coross bar then print the new one
handle_cast({move_cross_bar, Direc}, State) ->
    if
        State#state.isgameover ->
            {noreply, State};
        true ->
            {NewCrossBar, Flag} = update_cross_bar(State#state.crossbar, Direc),
            if
                Flag ->
                    % Remove current cross bar in each led matrix
                    Temp1 = remove_current_crossbar(State#state.data1, 1),
                    Temp2 = remove_current_crossbar(State#state.data2, 1),
                    % Create new crossbar then write to led matrix
                    {Data1, Data2} = update_data(NewCrossBar, {Temp1, Temp2}, 0, 3),
                    write_digit(State#state.spi, ?DIGIT_0, Data1, device_1),
                    write_digit(State#state.spi, ?DIGIT_0, Data2, device_2),

                    NewState = State#state{data1 = Data1, data2 = Data2, crossbar = NewCrossBar};
                true ->
                    NewState = State
            end,
            {noreply, NewState}
    end;

% Move ball
handle_cast(move_ball, State) ->
    % If game over stop execute
    if
        State#state.isgameover ->
            NewState = State;
        true ->
            Ball = maps:get(0, State#state.ball),
            % Move ball to the new position then return some information
            {NewBall, NewDirec, GameOver, NewPoint, NewScore} = move_ball(Ball, State#state.direction,
                                                                State#state.crossbar, State#state.point, State#state.score),
            if
                GameOver ->
                    io:format("GAME OVER ~n"),
                    timer:sleep(500),
                    % Display Score
                    {Data1, Data2} = handle_game_over(State#state.score),
                    write_digit(State#state.spi, ?DIGIT_0, Data1, device_1),
                    write_digit(State#state.spi, ?DIGIT_0, Data2, device_2),
                    timer:sleep(2000),
                    % Spawn new process to send display_game_over request
                    NewProc = spawn(?MODULE, game_over_process, [self(), 0]),
                    NewState = State#state{isgameover = true, goverproc = NewProc};
                NewScore == ?MAX_POINT ->
                    io:format("GAME WIN ~n"),
                    timer:sleep(500),
                    % Display Score
                    {Data1, Data2} = handle_game_over(NewScore),
                    write_digit(State#state.spi, ?DIGIT_0, Data1, device_1),
                    write_digit(State#state.spi, ?DIGIT_0, Data2, device_2),
                    timer:sleep(2000),
                    % Spawn new process to send display_game_win request
                    NewProc = spawn(?MODULE, game_win_process, [self(), 0]),
                    NewState = State#state{isgameover = true, goverproc = NewProc};
                true ->
                    % Normal case, move ball to the next position
                    {Data1, Data2} = update_ball(NewBall, Ball ,State#state.data1, State#state.data2),
                    write_digit(State#state.spi, ?DIGIT_0, Data1, device_1),
                    write_digit(State#state.spi, ?DIGIT_0, Data2, device_2),
                    NewState = State#state{ball = #{0 => NewBall}, data1 = Data1, data2 = Data2, direction = NewDirec, point = NewPoint, score = NewScore}
            end
        end,
    {noreply, NewState};

handle_cast({display_game_win, Times}, State) ->
    display_game_text(State#state.spi, Times, win),
    {noreply, State};

handle_cast({display_game_over, Times}, State) ->
    display_game_text(State#state.spi, Times, lose),
    {noreply, State}.

% Handle interrupt signel to reset the game
handle_info({gpio_interrupt, ?GPIO_SW}, State) ->
    io:format("receive interrupt~n"),
    case is_pid(State#state.goverproc) of
        true ->
            State#state.goverproc ! stop;
        false ->
            ok
    end,
    gen_server:cast(self(), reset_game),
    gen_server:cast(self(), update_game),
    {noreply, State}.

code_change(_OldVsn, State, _Extra) -> {ok, State}.
terminate(_Reason, _State) ->
    ok.

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

% Update the Data store in MAX7219 with the new Data
update_data(_Map, Data, Len, Len) ->
    Data;
update_data(Map, Data, Number, Len) ->
    {Id, Element} = maps:get(Number, Map),
    Device = get_device(Id),
    PreviousData = get_data(Device, Data),
    if
        Element =/= {-1, -1} ->
            NewData = write_element(Element, PreviousData);
        true ->
            NewData = PreviousData
    end,
    ReturnData = get_return_data(Data, NewData, Device),
    update_data(Map, ReturnData, Number + 1, Len).

% Helper function to write single element to the Data Maps
write_element({X, Y}, Data) ->
    NewX = 128 bsr Y,
    CurrentRow = maps:get(X + 1, Data),
    NewRow = NewX bor CurrentRow,
    Data#{X + 1 := NewRow}.

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

get_device(Num) ->
    case Num of
        0 ->
            device_1;
        1 ->
            device_2
    end.

get_data(Device, {Data1, Data2}) ->
    case Device of
        device_1 ->
            Data1;
        device_2 ->
            Data2
    end.

get_return_data({Data1, Data2}, NewData, Device) ->
    case Device of
        device_1 ->
            {NewData, Data2};
        device_2 ->
            {Data1, NewData}
    end.

%%% CrossBar Controll %%%
update_cross_bar(CrossBar, Direction) ->
    {Id1, {First, Y1}} = maps:get(0, CrossBar),
    {Id2, {Middle, Y2}} = maps:get(1, CrossBar),
    {Id3, {Last, Y3}} = maps:get(2, CrossBar),
    Cond1 = (((First == 0) and (Direction == -1))) and (Id1 == 0),
    Cond2 = ((Last == 7) and (Direction == 1)) and (Id3 == 1),
    Cond3 = (((First == 0) and (Direction == -1))) and (Id1 == 1),
    Cond4 = ((Last == 7) and (Direction == 1)) and (Id3 == 0),
    if
        Cond1 or Cond2 ->
            {CrossBar, false};
        Cond3 ->
            NewCrossBar = #{
                0 => {0, {7, 0}},
                1 => {Id1, {First, Y1}},
                2 => {Id2, {Middle, Y2}}
            },
            {NewCrossBar, true};
        Cond4 ->
            NewCrossBar = #{
                0 => {Id2, {Middle, Y2}},
                1 => {Id3, {Last, Y3}},
                2 => {1, {0, 0}}
            },
            {NewCrossBar, true};
        true ->
            case Direction of
                1 ->
                    NewCrossBar = #{
                        0 => {Id2, {Middle, Y2}},
                        1 => {Id3, {Last, Y3}},
                        2 => {Id3, {Last + 1, Y3}}
                    };
                -1 ->
                    NewCrossBar = #{
                        0 => {Id1, {First - 1, Y1}},
                        1 => {Id1, {First, Y1}},
                        2 => {Id2, {Middle, Y2}}
                    };
                true ->
                    NewCrossBar = CrossBar
            end,
            {NewCrossBar, true}
    end.

remove_current_crossbar(Map, 9) ->
    Map;
remove_current_crossbar(Map, Number) ->
    Element = maps:get(Number, Map),
    Row = Element band (bnot 128),
    NewMap = Map#{Number := Row},
    remove_current_crossbar(NewMap, Number + 1).

%%% Ball Controller %%%

move_ball({ID, {X, Y}}, {DirX, DirY}, CrossBar, Point, Score) ->
    {Flag, DirectionX, DirectionY, X1, Y1, TempID} = is_game_over({ID, {X, Y}}, {DirX, DirY}, CrossBar),
    {IsCollision, Pos} = is_collision(Point, 0, {ID, {X1, Y1}}),
    if
        IsCollision ->
            % But if reach the Point in middle of Led, it will crash ? Maybe test later
            NewX = (X1 - DirectionX),
            NewY = (Y1 - DirectionY),
            NewDirX = 0 - DirectionX,
            NewDirY = 0 - DirectionY,
            NewPoint = Point#{Pos := {-1, -1}},
            % After collision with the Point, the Ball maybe back to another Ledmatrix
            Cond1 = (NewX == -1),
            Cond2 = (NewX == 8),
            if
                Cond1 ->
                    {{?LED0, {7, NewY}}, {NewDirX, NewDirY}, Flag, NewPoint, Score + 1};
                Cond2 ->
                    {{?LED1, {0, NewY}}, {NewDirX, NewDirY}, Flag, NewPoint, Score + 1};
                true ->
                    {{TempID, {NewX, NewY}}, {NewDirX, NewDirY}, Flag, NewPoint, Score + 1}
            end;
        true ->
            % Update X axis include handle change led matrix of the Ball
            CondX1 = (X1 == 7) and (ID == ?LED1),
            CondX2 = (X1 == 0) and (ID == ?LED0),
            CondX3 = (X1 == 7) and (ID == ?LED0) and (DirectionX == 1),
            CondX4 = (X1 == 0) and (ID == ?LED1) and (DirectionX == -1),
            if
                CondX1 ->
                    NewX = 6,
                    NewDirX = -1,
                    NewID = TempID;
                CondX2 ->
                    NewX = 1,
                    NewDirX = 1,
                    NewID = TempID;
                CondX3 ->
                    NewX = 0,
                    NewDirX = DirectionX,
                    NewID =  ?LED1;
                CondX4 ->
                    NewX = 7,
                    NewDirX = DirectionX,
                    NewID =  ?LED0;
                true ->
                    NewX = X1 + DirectionX,
                    NewDirX = DirectionX,
                    NewID = TempID
            end,

            % Update Y axis
            if
                Y1 == 1 ->
                    NewY = 2,
                    NewDirY = 1;
                Y1 == 7 ->
                    NewY = 6,
                    NewDirY = -1;
                true ->
                    NewY = Y1 + DirectionY,
                    NewDirY = DirectionY
            end,

            {{NewID, {NewX, NewY}}, {NewDirX, NewDirY}, Flag, Point, Score}
        end.

is_game_over({ID, {X, Y}}, {DirX, DirY}, CrossBar) ->
    if
        Y == 1 ->
            compare_crossbar({ID, {X, Y}}, {DirX, DirY}, CrossBar);
        true ->
            {false, DirX, DirY, X, Y, ID}
    end.

% Compare Ball position with Cross Bar then handle
% Format return is {Flag, DirectionX, DirectionY, BallX, BallY}
compare_crossbar(Ball, {DirX, DirY}, CrossBar) ->
    {ID, {BallX, BallY}} = Ball,

    Temp0 = maps:get(0, CrossBar),
    Temp1 = maps:get(1, CrossBar),
    Temp2 = maps:get(2, CrossBar),

    Ball_1 = {ID, {BallX, BallY - 1}},
    Ball_2 = {ID, {BallX + DirX, BallY + DirY}},

    % Reach outside of crossbar but different Led matrix
    Cond = (Ball == {?LED1, {0, 1}}) and (Temp2 == {?LED0, {7, 0}}) and ({DirX, DirY} == {-1, -1}),
    Cond0 = (Ball == {?LED0, {7, 1}}) and (Temp0 == {?LED1, {0, 0}}) and ({DirX, DirY} == {1, -1}),
    Cond1 = Ball_1 == Temp1, % Reach middle of crossbar
    Cond2 = (Ball_1 == Temp0) or (Ball_1 == Temp2), % Reach the righ/left righ of crossbar
    Cond3 = (Ball_2 == Temp0) or (Ball_2 == Temp2), % Reach outside of crossbar
    Cond4 = (((BallY == 1) and (BallX == 0)) and ({0, {BallX + 1, BallY - 1}} == Temp0))
                or (((BallY == 1) and (BallX == 7)) and ({1, {BallX - 1, BallY - 1}} == Temp2)),
    if
        Cond or Cond0 ->
            {false, 0 - DirX, 0 - DirY, BallX - DirX, BallY, ID};
        Cond1 ->
            {false, 0, 1, BallX, BallY, ID};
        Cond2 ->
            {Res1, Res2} = handle_change_direc(DirX, DirY),
            {false, Res1, Res2, BallX, BallY, ID};
        Cond3 ->
            NewBallX = BallX - DirX,
            if
                NewBallX == 8 ->
                    {false, 0 - DirX, 0 - DirY, 0, BallY, ?LED1};
                NewBallX == -1 ->
                    {false, 0 - DirX, 0 - DirY, 7, BallY, ?LED0};
                true ->
                    {false, 0 - DirX, 0 - DirY, NewBallX, BallY, ID}
            end;
        Cond4 ->
            {false, 0 - DirX, 0 - DirY, BallX, BallY, ID};
        true ->
            {true, DirX, DirY, BallX, BallY, ID}
    end.

% If previous ball position is {0, Y}, random which way to go next
handle_change_direc(DirX, DirY) ->
    if
        DirX == 0 ->
            case atomvm:random() > 0 of
                false ->
                    {1, DirY};
                true ->
                    {-1, DirY}
            end;
        true ->
            {DirX, DirY}
    end.

is_collision(_Point, ?MAX_POINT, _Ball) ->
    {false, -1};
is_collision(Point, Current, Ball) ->
    Var = maps:get(Current, Point),
    if
        Ball == Var ->
            {true, Current};
        true ->
            is_collision(Point, Current + 1, Ball)
    end.

update_ball({ID, {X, Y}}, {PreID, {PreX, PreY}}, Data1, Data2) ->
    PreDev = get_device(PreID),
    PreData = get_data(PreDev, {Data1, Data2}),

    % Delete current ball
    DelX = (bnot (128 bsr PreY)) band maps:get(PreX + 1, PreData),
    NewData = PreData#{PreX + 1 := DelX},

    if
        ID == PreID ->
            % PreBall and NewBall is on the same ledmatrix
            NewX = 128 bsr Y,
            CurrentRow = maps:get(X + 1, NewData),
            NewRow = NewX bor CurrentRow,
            Result = NewData#{X + 1 := NewRow},
            get_return_data({Data1, Data2}, Result, PreDev);
        true ->
            % PreBall and NewBal is on the different led matrix
            Device = get_device(ID),
            Data = get_data(Device, {Data1, Data2}),

            NewX = 128 bsr Y,
            CurrentRow = maps:get(X + 1, Data),
            NewRow = NewX bor CurrentRow,
            Result = Data#{X + 1 := NewRow},
            if
                Device == device_1 ->
                    {Result, NewData};
                true ->
                    {NewData, Result}
            end
    end.



%%%% JOY Stick part  %%%%%

% Start interrupt from switch in Joystick
init_sw_interrupt() ->
    gpio:set_pin_mode(?GPIO_SW, input),
    gpio:set_pin_pull(?GPIO_SW, up),
    GPIO = gpio:start(),
    gpio:set_int(GPIO, ?GPIO_SW, rising).

setup_adc() ->
    {ok, ADCX} = adc:start(?GPIO_VRx, [{attenuation, db_11}, {bit_width, bit_12}]),
    {ok, ADCY} = adc:start(?GPIO_VRy, [{attenuation, db_11}, {bit_width, bit_12}]),
    {ADCX, ADCY}.

read_adc(ADC) ->
    case adc:read(ADC) of
        {ok, {Raw, _MilliVolts}} ->
            {ok, Raw};
        Error ->
            io:format("Error taking reading: ~p~n", [Error])
    end.

% Currently we dont use ADCY, but if new idea need it, we will use it
joystick(Pid, ADCX, ADCY) ->
    {ok, X} = read_adc(ADCX),
    {ok, _Y} = read_adc(ADCY),
    if
        X < ?LOW_RANGE ->
            gen_server:cast(Pid, {move_cross_bar, -1});
        X > ?HIGH_RANGE ->
            gen_server:cast(Pid, {move_cross_bar, 1});
        true ->
            nothing_change
    end,
    timer:sleep(?DELAY_READ_ADC),
    joystick(Pid, ADCX, ADCY).

%%% Display score and GAME WIN or GAME OVER text %%%

% % Handle game over function
handle_game_over(Score) ->
    FirstNum = get_num_macro(Score div 10),
    SecondNum = get_num_macro(Score rem 10),
    {FirstNum, SecondNum}.

% Get number from macro to Display score
get_num_macro(Number) ->
    case Number of
        0 ->
            ?NUMBER_0;
        1 ->
            ?NUMBER_1;
        2 ->
            ?NUMBER_2;
        3 ->
            ?NUMBER_3;
        4 ->
            ?NUMBER_4;
        5 ->
            ?NUMBER_5;
        6 ->
            ?NUMBER_6;
        7 ->
            ?NUMBER_7;
        8 ->
            ?NUMBER_8;
        9 ->
            ?NUMBER_9
    end.

% Display Game win or Game over
display_game_text(SPI, Times, Command) ->
    Data1 = get_data(?EMPTY_MATRIX, 1, Times, Command),
    Data2 = get_data(?EMPTY_MATRIX, 1, Times + 8, Command),
    write_digit(SPI, ?DIGIT_0, Data1, device_1),
    write_digit(SPI, ?DIGIT_0, Data2, device_2).

% Helper function to Get Data which use to print to Led matrix
get_data(Result, 9, _Times, _) ->
    Result;

get_data(Result, Number, Times, lose) ->
    Row = maps:get(Number + Times, ?GAME_OVER),
    NewResult = Result#{Number := Row},
    get_data(NewResult, Number + 1, Times, lose);

get_data(Result, Number, Times, win) ->
    Row = maps:get(Number + Times, ?GAME_WIN),
    NewResult = Result#{Number := Row},
    get_data(NewResult, Number + 1, Times, win).

%%% Some process function call back %%%%

game_over_process(P, Times) ->
    receive
        stop ->
            ok
    after 300 ->
        gen_server:cast(P, {display_game_over, Times}),
        % Handle to display GAME OVER text again
        case (Times + 1) == 29 of
            true ->
                NewTimes = 0;
            false ->
                NewTimes = Times + 1
        end,
        game_over_process(P, NewTimes)
    end.

game_win_process(P, Times) ->
    receive
        stop ->
            ok
    after 300 ->
        gen_server:cast(P, {display_game_win, Times}),
        % Handle to display GAME OVER text again
        case (Times + 1) == 27 of
            true ->
                NewTimes = 0;
            false ->
                NewTimes = Times + 1
        end,
        game_win_process(P, NewTimes)
    end.

% Read variable resistor callback
variable_resistor(Parrent, ADC, PreviousSpeed) ->
    {ok, Speed} = read_adc(ADC),
    MapSpeed = map(Speed, 0, ?BIT_RESOLUTION, ?MAX_SPEED, ?MIN_SPEED),
    Ischange = is_not_in_range(PreviousSpeed, MapSpeed),
    if
        Ischange ->
            NewSpeed = MapSpeed,
            Parrent ! {newspeed, MapSpeed};
        true ->
            NewSpeed = PreviousSpeed
    end,
    timer:sleep(NewSpeed),
    variable_resistor(Parrent, ADC, NewSpeed).

% Becasue with one Value of resistor, when read ADC there is a slight error of about 1 to 10
% So this function help us check the value change or not
is_not_in_range(PreVal, NewVal) ->
    Low = PreVal - 10,
    High = PreVal + 10,
    case (NewVal >= Low )and (NewVal =< High) of
        true ->
            false;
        false ->
            true
    end.

map(Value, InLow, InHigh, OutLow, OutHigh) ->
    Res = (Value - InLow) * (OutHigh - OutLow) / (InHigh - InLow) + OutLow,
    round(Res).

% Move ball callback
ball(Pid, PreSpeed) ->
    receive
        {newspeed, Speed} ->
            NewSpeed = Speed
    after PreSpeed ->
        NewSpeed = PreSpeed
    end,
    gen_server:cast(Pid, move_ball),
    ball(Pid, NewSpeed).
