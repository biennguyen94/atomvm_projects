-module(block_breaker).

-include("global.hrl").

-export([start/0, joystick/3, variable_resistor/3, game_over_process/2, game_win_process/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
        terminate/2, code_change/3]).

-define(DELAY_READ_ADC, 100).
-define(MAX_SPEED, 100).
-define(MIN_SPEED, 1000).
-define(BIT_RESOLUTION, 4095).

-record(state, {spi, crossbar, ball, direction, point, data, isgameover, goverproc, score}).

-define(NUM_OF_BITS, 8).

-define(DEVICE_NAME, device_1).

-define(SPISettings, [
    {bus_config, [
        {miso_io_num, 19},
        {mosi_io_num, 27},
        {sclk_io_num, 5}
    ]},
    {device_config, [
        {?DEVICE_NAME, [
            {spi_clock_hz, 1000000},
            {mode, 0},
            {spi_cs_io_num, 18},
            {address_len_bits, 8}
        ]}
    ]}
]).

start() ->
    % Start gen server and spi peripheral
    {ok, P} = gen_server:start(?MODULE, [], []),
    gen_server:cast(P, update_game),

    % Setup ADC to read Joystick
    {ADCX, ADCY} = setup_adc(),
    spawn(?MODULE, joystick, [P, ADCX, ADCY]),

    % Setup ADC to read polimeter
    ok = esp_adc:start(?GPIO_RESISTOR),
    spawn(?MODULE, variable_resistor, [self(), ?GPIO_RESISTOR, ?MAX_SPEED]),

    io:format("INIT OK ~n"),
    % move ball
    ball(P, 300).

init(_) ->
    {ok, SPI} = init_max7219(?SPISettings),
    init_sw_interrupt(),
    % Default setup when start the game
    State = #state{spi = SPI, crossbar = ?CROSS_BAR, data = ?EMPTY_MATRIX, score = 0, goverproc = undefined,
                point = ?DEFAULT_POINT, ball = #{0 => {4, 1}}, direction = {-1, 1}, isgameover = false},
    io:format("Init SPI and MAX7219 OK ~p ~n", [?CROSS_BAR]),
    {ok, State}.

handle_call(_Msg, _From, State) ->
    {reply, ok, State}.

% Update game with current State of Gen server
handle_cast(update_game, State) ->
    % Add cross bar to Data
    AddCrossBar = update_data(State#state.crossbar, State#state.data , 0, 3),

    % Add ball to data
    AddBall = update_data(State#state.ball, AddCrossBar, 0, 1),

    % Add Point to data
    NewData = update_data(State#state.point, AddBall, 0, 24),

    % Print data to led matrix
    write_digit(State#state.spi, ?DIGIT_0, NewData),

    NewState = State#state{data = NewData},
    {noreply, NewState};

% Handle reset game
handle_cast(reset_game, State) ->
    NewState = State#state{crossbar = ?CROSS_BAR, data = ?EMPTY_MATRIX, score = 0, goverproc = undefined,
            point = ?DEFAULT_POINT, ball = #{0 => {4, 1}}, direction = {-1, 1}, isgameover = false},
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
                    TempData = remove_current_crossbar(State#state.data, 1),
                    NewData = update_data(NewCrossBar, TempData , 0, 3),
                    write_digit(State#state.spi, ?DIGIT_0, NewData),
                    NewState = State#state{data = NewData, crossbar = NewCrossBar};
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
                    NewData = handle_game_over(State#state.score),
                    write_digit(State#state.spi, ?DIGIT_0, NewData),
                    timer:sleep(2000),
                    % Spawn new process to send display_game_over request
                    NewProc = spawn(?MODULE, game_over_process, [self(), 0]),
                    NewState = State#state{isgameover = true, goverproc = NewProc};
                NewScore == ?MAX_POINT ->
                    io:format("GAME WIN ~n"),
                    timer:sleep(500),
                    % Display Score
                    NewData = handle_game_over(NewScore),
                    write_digit(State#state.spi, ?DIGIT_0, NewData),
                    timer:sleep(2000),
                    % Spawn new process to send display_game_win request
                    NewProc = spawn(?MODULE, game_win_process, [self(), 0]),
                    NewState = State#state{isgameover = true, goverproc = NewProc};
                true ->
                    % Normal case, move ball to the next position
                    NewData = update_ball(NewBall, Ball ,State#state.data),
                    write_digit(State#state.spi, ?DIGIT_0, NewData),
                    NewState = State#state{ball = #{0 => NewBall}, data = NewData, direction = NewDirec, point = NewPoint, score = NewScore}
            end
        end,
    {noreply, NewState};

handle_cast({display_game_win, Times}, State) ->
    display_game_win(State#state.spi, Times),
    {noreply, State};

handle_cast({display_game_over, Times}, State) ->
    display_game_over(State#state.spi, Times),
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
    write_register(SPI, ?DECODE_MODE, 16#0),    % No decoding
    write_register(SPI, ?INTENSITY, 16#3),      % Brightness intensity
    write_register(SPI, ?SCAN_LIMIT, 16#7),     % Scan limit = 8 LEDs
    write_register(SPI, ?SHUTDOWN, 16#1),       % Power down = 0, Normal mode = 1
    write_register(SPI, ?DISPLAY_TEST, 16#0),   % No display Test
    {ok, SPI}.

% Update the Data store in MAX7219 with the new Data
update_data(_Map, Data, Len, Len) ->
    Data;
update_data(Map, PreviousData, Number, Len) ->
    Element = maps:get(Number, Map),
    if
        Element =/= {-1, -1} ->
            NewData = write_element(Element, PreviousData);
        true ->
            NewData = PreviousData
    end,
    update_data(Map, NewData, Number + 1, Len).

% Helper function to write single element to the Data Maps
write_element({X, Y}, Data) ->
    NewX = 128 bsr Y,
    CurrentRow = maps:get(X + 1, Data),
    NewRow = NewX bor CurrentRow,
    Data#{X + 1 := NewRow}.

% Recursive to write Data from Digit 1 to 8
write_digit(SPI, 8, Data) ->
    RegData = maps:get(8, Data),
    write_register(SPI, 8, RegData),
    ok;
write_digit(SPI, Number, Data) ->
    RegData = maps:get(Number, Data),
    write_register(SPI, Number, RegData),
    write_digit(SPI, Number + 1, Data).

write_register(SPI, Address, Data) ->
    spi:write_at(SPI, ?DEVICE_NAME, Address, ?NUM_OF_BITS, Data).

%%% CrossBar Controll %%%
update_cross_bar(CrossBar, Direction) ->
    {First, _} = maps:get(0, CrossBar),
    {Middle, _} = maps:get(1, CrossBar),
    {Last, _} = maps:get(2, CrossBar),
    case ((First == 0) and (Direction == -1)) or ((Last == 7) and (Direction == 1)) of
        true ->
            {CrossBar, false};
        false ->
            {NewFirst, NewMiddle, NewLast} = move_cross_bar({First, Middle, Last}, Direction),
            NewCrossBar = #{
                        0 => {NewFirst, 0},
                        1 => {NewMiddle, 0},
                        2 => {NewLast, 0}
                },
            {NewCrossBar, true}
    end.

move_cross_bar({First, Middle, Last}, Direction) ->
    case Direction of
        1 ->
            {First + 1, Middle + 1, Last + 1};
        -1 ->
            {First - 1, Middle - 1, Last - 1};
        true ->
            {First, Middle, Last}
    end.

remove_current_crossbar(Map, 9) ->
    Map;
remove_current_crossbar(Map, Number) ->
    Element = maps:get(Number, Map),
    Row = Element band (bnot 128),
    NewMap = Map#{Number := Row},
    remove_current_crossbar(NewMap, Number + 1).

%%% Ball Controller %%%

move_ball({X, Y}, {DirX, DirY}, CrossBar, Point, Score) ->
    {Flag, DirectionX, DirectionY, X1, Y1} = is_game_over({X, Y}, {DirX, DirY}, CrossBar),
    {IsCollision, Pos} = is_collision(Point, 0, {X1, Y1}),
    if
        IsCollision ->
            NewX = (X1 - DirectionX),
            NewY = (Y1 - DirectionY),
            NewDirX = 0 - DirectionX,
            NewDirY = 0 - DirectionY,
            NewPoint = Point#{Pos := {-1, -1}},
            {{NewX, NewY}, {NewDirX, NewDirY}, Flag, NewPoint, Score + 1};
        true ->
            % Update X axis
            if
                X1 == 7 ->
                    NewX = 6,
                    NewDirX = -1;
                X1 == 0 ->
                    NewX = 1,
                    NewDirX = 1;
                true ->
                    NewX = X1 + DirectionX,
                    NewDirX = DirectionX
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
            {{NewX, NewY}, {NewDirX, NewDirY}, Flag, Point, Score}
        end.

is_game_over({X, Y}, {DirX, DirY}, CrossBar) ->
    if
        Y == 1 ->
            compare_crossbar({X, Y}, {DirX, DirY}, CrossBar);
        true ->
            {false, DirX, DirY, X, Y}
    end.

% Compare Ball position with Cross Bar then handle
compare_crossbar({BallX, BallY}, {DirX, DirY}, CrossBar) ->
    Temp0 = maps:get(0, CrossBar),
    Temp1 = maps:get(1, CrossBar),
    Temp2 = maps:get(2, CrossBar),
    Ball = {BallX, BallY - 1},
    Ball1 = {BallX + DirX, BallY + DirY},
    Cond1 = (Ball == Temp1), % Reach middle of crossbar
    Cond2 = (Ball == Temp0) or (Ball == Temp2), % Reach the righ/left righ of crossbar
    Cond3 = (Ball1 == Temp0) or (Ball1 == Temp2), % Reach outside of crossbar
    Cond4 = (((BallY == 1) and (BallX == 0)) and ({BallX + 1, BallY - 1} == Temp0)) or (((BallY == 1) and (BallX == 7)) and ({BallX - 1, BallY - 1} == Temp2)),
    if
        Cond1 ->
            {false, 0, 1, BallX, BallY};
        Cond2 ->
            {Res1, Res2} = handle_change_direc(DirX, DirY),
            {false, Res1, Res2, BallX, BallY};
        Cond3 ->
            {false, 0 - DirX, 0 - DirY, BallX - DirX, BallY};
        Cond4 ->
            {false, 0 - DirX, 0 - DirY, BallX, BallY};
        true ->
            {true, DirX, DirY, BallX, BallY}
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

is_collision(_Point, 24, _Ball) ->
    {false, -1};
is_collision(Point, Current, Ball) ->
    Var = maps:get(Current, Point),
    if
        Ball == Var ->
            {true, Current};
        true ->
            is_collision(Point, Current + 1, Ball)
    end.

update_ball({X, Y}, {PreX, PreY}, Data) ->
    % Delete current ball
    DelX = (bnot (128 bsr PreY)) band maps:get(PreX + 1, Data),
    NewData = Data#{PreX + 1 := DelX},

    % Update with new Ball position
    NewX = 128 bsr Y,
    CurrentRow = maps:get(X + 1, NewData),
    NewRow = NewX bor CurrentRow,
    NewData#{X + 1 := NewRow}.

%%%% JOY Stick part  %%%%%

% Start interrupt from switch in Joystick
init_sw_interrupt() ->
    gpio:set_pin_mode(?GPIO_SW, input),
    gpio:set_pin_pull(?GPIO_SW, up),
    GPIO = gpio:start(),
    gpio:set_int(GPIO, ?GPIO_SW, rising).

setup_adc() ->
    ok = esp_adc:start(?GPIO_VRx),
    ok = esp_adc:start(?GPIO_VRy),
    {?GPIO_VRx, ?GPIO_VRy}.

read_adc(ADC) ->
    case esp_adc:read(ADC) of
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

% Handle game over function
handle_game_over(Score) ->
    FirstNum = get_num_macro(Score div 10, left),
    SecondNum = get_num_macro(Score rem 10, right),
    EmptyMap = ?EMPTY_MATRIX,
    merge_two_maps(EmptyMap, FirstNum, SecondNum, 1).

% Get number from macro to Display score
get_num_macro(Number, left) ->
    case Number of
        0 ->
            ?NUMBER_0_LEFT;
        1 ->
            ?NUMBER_1_LEFT;
        2 ->
            ?NUMBER_2_LEFT;
        3 ->
            ?NUMBER_3_LEFT;
        4 ->
            ?NUMBER_4_LEFT;
        5 ->
            ?NUMBER_5_LEFT;
        6 ->
            ?NUMBER_6_LEFT;
        7 ->
            ?NUMBER_7_LEFT;
        8 ->
            ?NUMBER_8_LEFT;
        9 ->
            ?NUMBER_9_LEFT
    end;

get_num_macro(Number, right) ->
    case Number of
        0 ->
            ?NUMBER_0_RIGHT;
        1 ->
            ?NUMBER_1_RIGHT;
        2 ->
            ?NUMBER_2_RIGHT;
        3 ->
            ?NUMBER_3_RIGHT;
        4 ->
            ?NUMBER_4_RIGHT;
        5 ->
            ?NUMBER_5_RIGHT;
        6 ->
            ?NUMBER_6_RIGHT;
        7 ->
            ?NUMBER_7_RIGHT;
        8 ->
            ?NUMBER_8_RIGHT;
        9 ->
            ?NUMBER_9_RIGHT
    end.

% Merge two map contain two Score character to one Map then display on Led maxtrix
merge_two_maps(Result, _Map1, _Map2, 9) ->
    Result;
merge_two_maps(Result, Map1, Map2, Number) ->
    Temp1 = maps:get(Number, Map1),
    Temp2 = maps:get(Number, Map2),
    NewRow = Temp1 bor Temp2,
    NewResult = Result#{Number := NewRow},
    merge_two_maps(NewResult, Map1, Map2, Number + 1).

% Display Game win or Game over
display_game_over(SPI, Times) ->
    EmtyData = ?EMPTY_MATRIX,
    Data = get_data(EmtyData, 1, Times, lose),
    write_digit(SPI, 1, Data).

display_game_win(SPI, Times) ->
    EmtyData = ?EMPTY_MATRIX,
    Data = get_data(EmtyData, 1, Times, win),
    write_digit(SPI, 1, Data).

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
        case (Times + 1) == 37 of
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
        case (Times + 1) == 35 of
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
% So this function help us compare Old value and New value if change or not
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
