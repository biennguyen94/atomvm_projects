-module(snake_game_2led).

-include("led_matrix.hrl").

-export([start/0, joystick/3, blink_food/1, game_over_process/2, variable_resistor/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
        terminate/2, code_change/3]).

-define(GPIO_VRx, 34).
-define(GPIO_VRy, 35).
-define(GPIO_SW, 32).
-define(GPIO_RESISTOR, 33).

-define(GPIO_MISO, 19).
-define(GPIO_MOSI, 27).
-define(GPIO_SLCK, 5).
-define(GPIO_CS, 18).

-define(LOW_RANGE, 100).
-define(HIGH_RANGE, 4000).

-define(DELAY_READ_ADC, 20).
-define(MAX_SPEED, 200).
-define(MIN_SPEED, 1000).
-define(BLINK_RATE, 200).
-define(BIT_RESOLUTION, 4095).

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
% Default Snake Status
-define(LED0, 0).
-define(LED1, 1).

-define(HEAD, {?LED0, {2, 4}}).
-define(BODY, #{0 => {?LED0, {1, 4}}, 1 => {?LED0, {2,4}}}).
-define(DIRECTION, {1, 0}).

-record(snake, {spi, snakehead, snakebody, snakelen, food, data1, data2, direction, gameover, goverproc}).

start() ->
    % Start Gen server and setup some peripherals
    {ok, Pid} = gen_server:start(?MODULE, [], []),

    % Init Joystick and Spawn new process to handle read Joystick
    {ADCX, ADCY} = setup_adc(),
    spawn(?MODULE, joystick, [Pid, ADCX, ADCY]),

    % Init Variable resitor and Spawn new process to handle read variable resistor
    % This process help us read variable resistor to change the speed of Snake
    {ok, VRes} = adc:start(?GPIO_RESISTOR, [{attenuation, db_11}, {bit_width, bit_12}]),
    spawn(?MODULE, variable_resistor, [self(), VRes, ?MAX_SPEED]),

    % Spawn new process to handle blink the food
    spawn(?MODULE, blink_food, [Pid]),

    loop(Pid, ?MAX_SPEED).

% Gen Server side:
% Setup some peripherals and init default Snake, Food and direction
init(_) ->
    {ok, SPI} = init_max7219(?SPISettings),
    init_sw_interrupt(),
    {SnakeHead, SnakeBody, Food, {Data1, Data2}} = init_snake(SPI, ?BODY),
    io:format("Init SPI and MAX7219 OK~n ~n"),
    NewState = #snake{spi = SPI, snakehead = SnakeHead, snakebody = SnakeBody, snakelen = 2,
                        food = Food, direction = ?DIRECTION, data1 = Data1, data2 = Data2, gameover = false},
    {ok, NewState}.

handle_call(_Msg, _From, State) ->
    {reply, ok, State}.

% Handle change direction request
handle_cast({change_direction, X, Y}, State) ->
    Flag = is_backward(State, {X, Y}),
    % If Game over or New direction make Snake moving backward, ingore that request
    case (State#snake.gameover == true) or (Flag == true) of
        true ->
            NewState = State;
        false ->
            NewState = State#snake{direction = {X, Y}}
    end,
    {noreply, NewState};

% Handle move Snake request
handle_cast(move, State) ->
    % Game over -> Stop moving the Snake
    if
        State#snake.gameover ->
            NewState = State;
        true ->
            NewState = move_snake(State)
    end,
    {noreply, NewState};

% Handle display Moving "GAME OVER" text
handle_cast({display_game_over, Times}, State) ->
    display_game_text(State#snake.spi, Times, lose),
    {noreply, State};

% Handle blink the food (need check current game over status)
handle_cast(turn_off_food, State) ->
    if
        State#snake.gameover == true ->
            {noreply, State};
        true ->
            turn_off_food(State#snake.spi, State#snake.food, {State#snake.data1, State#snake.data2}),
            {noreply, State}
    end;

handle_cast(turn_on_food, State) ->
    if
        State#snake.gameover == true ->
            {noreply, State};
        true ->
            turn_on_food(State#snake.spi, State#snake.food, {State#snake.data1, State#snake.data2}),
            {noreply, State}
    end.

% Receive Reset request from User and handle it
handle_info({gpio_interrupt, ?GPIO_SW}, State) ->
    io:format("receive interrupt~n"),
    case is_pid(State#snake.goverproc) of
        true ->
            State#snake.goverproc ! stop;
        false ->
            ok
    end,
    {SnakeHead, SnakeBody, Food, {Data1, Data2}} = init_snake(State#snake.spi, ?BODY),
    NewState = State#snake{snakehead = SnakeHead, snakebody = SnakeBody, snakelen = 2,
                        food = Food, direction = ?DIRECTION, data1 = Data1, data2 = Data2, gameover = false, goverproc = undefined},
    {noreply, NewState}.

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

% Start interrupt from switch in Joystick
init_sw_interrupt() ->
    gpio:set_pin_mode(?GPIO_SW, input),
    gpio:set_pin_pull(?GPIO_SW, up),
    GPIO = gpio:start(),
    gpio:set_int(GPIO, ?GPIO_SW, rising).
%%% ADC part to control Joystick %%%

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

% joystick process callback
joystick(Pid, ADCX, ADCY) ->
    {ok, X} = read_adc(ADCX),
    {ok, Y} = read_adc(ADCY),
    if
        X < ?LOW_RANGE ->
            gen_server:cast(Pid, {change_direction, -1, 0});
        Y < ?LOW_RANGE ->
            gen_server:cast(Pid, {change_direction, 0, -1});
        X > ?HIGH_RANGE ->
            gen_server:cast(Pid, {change_direction, 1, 0});
        Y > ?HIGH_RANGE ->
            gen_server:cast(Pid, {change_direction, 0, 1});
        true ->
            nothing_change
    end,
    timer:sleep(?DELAY_READ_ADC),
    joystick(Pid, ADCX, ADCY).

%%% Snake and food Part %%%

init_snake(SPI, Body) ->
    DigitList = ?EMPTY_MATRIX,
    % Create default Snake and add to Data
    {_Id, {HeadX, HeadY}} = ?HEAD,
    Data1 = DigitList#{HeadX + 1 := (128 bsr HeadY), HeadX := (128 bsr HeadY)},
    Data2 = ?EMPTY_MATRIX,

    % Radom first food and add to Data
    {FoodID, {FoodX, FoodY}} = spawn_new_food(Body, 2),
    TempData = get_data(get_device(FoodID), {Data1, Data2}),
    Row = maps:get(FoodX + 1, TempData) bor (128 bsr FoodY),
    NewData = TempData#{FoodX + 1 := Row},

    {Res1, Res2} = get_return_data({Data1, Data2}, NewData, get_device(FoodID)),
    write_digit(SPI, ?DIGIT_0, Res1, device_1),
    write_digit(SPI, ?DIGIT_0, Res2, device_2),
    io:format("First Food is ~p ~n", [{FoodID, {FoodX, FoodY}}]),
    {?HEAD, ?BODY, {FoodID, {FoodX, FoodY}}, {Res1, Res2}}.

move_snake(State) ->
    % Update new Snake Head
    {Id, {X, Y}} = State#snake.snakehead,
    {DirX, DirY} = State#snake.direction,
    SnakeHead = {X + DirX, Y + DirY},

    % Handle border
    NewSnakeHead = handle_border(Id, SnakeHead),

    % Handle eat Food or not
    case NewSnakeHead == State#snake.food of
        true ->
            NewSnakeLen = State#snake.snakelen + 1,
            % Add Food to SnakeBody
            NewSnakeBody = update_snake_body(State#snake.snakebody, NewSnakeLen, State#snake.food),
            NewFood = spawn_new_food(NewSnakeBody, NewSnakeLen);
        false ->
            % Shift left the Snake
            NewSnakeLen = State#snake.snakelen,
            PreviousBody = maps:new(),
            NewSnakeBody = shift_snake(State#snake.snakebody, NewSnakeHead, NewSnakeLen - 1, PreviousBody, 0),
            NewFood = State#snake.food
    end,

    % Handle snake eat itself or not
    Status = is_game_over(NewSnakeHead, NewSnakeBody, NewSnakeLen - 1, 0),
    if
        Status ->
            timer:sleep(500),
            % Display Score
            {Data1, Data2} = handle_game_over(State#snake.snakelen),
            write_digit(State#snake.spi, ?DIGIT_0, Data1, device_1),
            write_digit(State#snake.spi, ?DIGIT_0, Data2, device_2),
            timer:sleep(2000),
            % Spawn new process to send display_game_over request
            NewProc = spawn(?MODULE, game_over_process, [self(), 0]),
            State#snake{gameover = true, goverproc = NewProc};
        true ->
            % Game not over yet, update new Snake and display in Ledmatrix
            {Data1, Data2} = update_data(NewSnakeBody, {?EMPTY_MATRIX, ?EMPTY_MATRIX}, NewFood, 0, NewSnakeLen),
            write_digit(State#snake.spi, ?DIGIT_0, Data1, device_1),
            write_digit(State#snake.spi, ?DIGIT_0, Data2, device_2),
            State#snake{snakehead = NewSnakeHead, snakebody = NewSnakeBody,
                        snakelen = NewSnakeLen, food = NewFood, data1 = Data1, data2 = Data2}
    end.

% Handler if snake reach to the border
handle_border(Id, {X, Y}) ->
    Cond0 = (X > 7) and (Id == ?LED0),
    Cond1 = (X > 7) and (Id == ?LED1),
    Cond2 = (X < 0) and (Id == ?LED0),
    Cond3 = (X < 0) and (Id == ?LED1),
    Cond4 = (Y > 7),
    Cond5 = (Y < 0),
    if
        Cond0 ->
            {?LED1, {0, Y}};
        Cond1 ->
            {?LED0, {0, Y}};
        Cond2 ->
            {?LED1, {7, Y}};
        Cond3 ->
            {?LED0, {7, Y}};
        Cond4 ->
            {Id, {X, 0}};
        Cond5 ->
            {Id, {X, 7}};
        true ->
            {Id, {X, Y}}
    end.


% Eat new Food, so add to Head of Snake
update_snake_body(SnakeBody, SnakeLen, Food) ->
    SnakeBody#{SnakeLen - 1 => Food}.

% Recursive Number times to shift SnakeBody
% (current key will be equal to the next key, last key equal to Newhead)
shift_snake(_SnakeBody, SnakeHead, SnakeLen, PreviousBody, SnakeLen) ->
    PreviousBody#{SnakeLen => SnakeHead};
shift_snake(SnakeBody, SnakeHead, SnakeLen, PreviousBody, Number) ->
    NextEle = maps:get(Number + 1, SnakeBody),
    NewSnakeBody = PreviousBody#{Number => NextEle},
    shift_snake(SnakeBody, SnakeHead, SnakeLen, NewSnakeBody, Number + 1).

% Update the Data store in MAX7219 with the new SnakeBody and new food (if have)
update_data(_Map, Data, {Id, {X, Y}}, Len, Len) ->
    Temp = get_data(get_device(Id), Data),
    NewData = write_element({X, Y}, Temp),
    get_return_data(Data, NewData, get_device(Id));

update_data(Map, Data, Food, Number, Len) ->
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
    update_data(Map, ReturnData, Food, Number + 1, Len).

% Helper function to write single element to the MAX7219
write_element({X, Y}, Data) ->
    NewX = 128 bsr Y,
    CurrentRow = maps:get(X + 1, Data),
    NewRow = NewX bor CurrentRow,
    Data#{X + 1 := NewRow}.

% Check if game over or not by compare each element in SnakeBody and SnakeHead
% (except the last element in Snakebody)
is_game_over(_SnakeHead, _SnakeBody, SnakeLen, SnakeLen) ->
    false;
is_game_over(SnakeHead, SnakeBody, SnakeLen, Number) ->
    Element = maps:get(Number, SnakeBody),
    case Element == SnakeHead of
        true ->
            true;
        false ->
            is_game_over(SnakeHead, SnakeBody, SnakeLen, Number + 1)
    end.

% Handle game over function
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
    get_data(NewResult, Number + 1, Times, lose).

% If user control the snake moving backward, ignore that signal
is_backward(State, Direction) ->
    {_Idbody, {PreX, PreY}} = maps:get(State#snake.snakelen - 2, State#snake.snakebody),
    {_Idhead, {HeadX, HeadY}} = State#snake.snakehead,
    {X, Y} = {(HeadX - PreX), (HeadY - PreY)},
    case (abs(X) + abs(Y)) =/= 1 of
        true ->
            % Handle case Two head of snake reach border
            Sub = {(X rem 6), (Y rem 6)};
        false ->
            Sub = {-X, -Y}
    end,
    if
        Sub == Direction ->
            true;
        true ->
            false
    end.

% Random integer number where: 0 <= result <= 7
rand() ->
    Value = atomvm:random() rem 8,
    if
        Value >= 0 ->
            Value;
        true ->
            rand()
    end.

% Random which led use to display
rand_led() ->
    Value = atomvm:random(),
    if
        Value >= 0 ->
            1;
        true ->
            0
    end.

% Food handler
spawn_new_food(Body, Size) ->
    FoodX = rand(),
    FoodY = rand(),
    FoodID = rand_led(),
    % Food position dupplicate with snake, Spawn new food
    % Otherwise return the food
    Flag = is_exits(Body, {FoodID, {FoodX, FoodY}}, Size, 0),
    if
        Flag ->
            spawn_new_food(Body, Size);
        true ->
            {FoodID, {FoodX, FoodY}}
    end.

is_exits(_Body, _Food, Size, Size) ->
    false;
is_exits(Body, Food, Size, Number) ->
    Temp = maps:get(Number, Body),
    if
        Temp == Food ->
            true;
        true ->
            is_exits(Body, Food, Size, Number + 1)
    end.

% The next two function use to blink the food
turn_off_food(SPI, {FoodID, {FoodX, FoodY}}, Data) ->
    Dev = get_device(FoodID),
    Temp = get_data(Dev, Data),
    Row = maps:get(FoodX + 1, Temp),
    Temp1 = Row band (bnot (128 bsr FoodY)),
    write_register(SPI, FoodX + 1, Temp1, Dev).

turn_on_food(SPI, {FoodID, {FoodX, FoodY}}, Data) ->
    Dev = get_device(FoodID),
    Temp = get_data(Dev, Data),
    Row = maps:get(FoodX + 1, Temp),
    Temp1 = Row bor (128 bsr FoodY),
    write_register(SPI, FoodX + 1, Temp1, Dev).


% Game over process callback
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

% Bink food callback
blink_food(Pid) ->
    gen_server:cast(Pid, turn_off_food),
    timer:sleep(?BLINK_RATE),
    gen_server:cast(Pid, turn_on_food),
    timer:sleep(?BLINK_RATE),
    blink_food(Pid).

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

% Move snake callback
loop(Pid, PreSpeed) ->
    receive
        {newspeed, Speed} ->
            NewSpeed = Speed
    after PreSpeed ->
        NewSpeed = PreSpeed
    end,
    gen_server:cast(Pid, move),
    loop(Pid, NewSpeed).