-module(snake_game).

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

-define(LOW_RANGE, 700).
-define(HIGH_RANGE, 3000).

-define(DELAY_READ_ADC, 20).
-define(MAX_SPEED, 200).
-define(MIN_SPEED, 1000).
-define(BLINK_RATE, 200).
-define(BIT_RESOLUTION, 4095).

-define(NUM_OF_BITS, 8).

-define(DEVICE_NAME, device_1).

-define(SPISettings, [
    {bus_config, [
        {miso_io_num, ?GPIO_MISO},
        {mosi_io_num, ?GPIO_MOSI},
        {sclk_io_num, ?GPIO_SLCK}
    ]},
    {device_config, [
        {?DEVICE_NAME, [
            {spi_clock_hz, 1000000},
            {mode, 0},
            {spi_cs_io_num, ?GPIO_CS},
            {address_len_bits, 8}
        ]}
    ]}
]).

% Default Snake Status
-define(HEAD, {2, 4}).
-define(BODY, #{0 => {1, 4}, 1 => {2,4}}).
-define(DIRECTION, {0, 1}).

-record(snake, {spi, snakehead, snakebody, snakelen, food, data, direction, gameover, goverproc}).

start() ->
    % Start Gen server and setup some peripherals
    {ok, Pid} = gen_server:start(?MODULE, [], []),

    % Init Joystick and Spawn new process to handle read Joystick
    {ADCX, ADCY} = setup_adc(),
    spawn(?MODULE, joystick, [Pid, ADCX, ADCY]),

    % Init Variable resitor and Spawn new process to handle read variable resistor
    % This process help us read variable resistor to change the speed of Snake
    ok = esp_adc:start(?GPIO_RESISTOR),
    spawn(?MODULE, variable_resistor, [self(), GPIO_RESISTOR, ?MAX_SPEED]),

    % Spawn new process to handle blink the food
    spawn(?MODULE, blink_food, [Pid]),

    loop(Pid, ?MAX_SPEED).

% Gen Server side:
% Setup some peripherals and init default Snake, Food and direction
init(_) ->
    {ok, SPI} = init_max7219(?SPISettings),
    init_sw_interrupt(),
    {SnakeHead, SnakeBody, Food, Data} = init_snake(SPI, ?BODY),
    io:format("Init SPI and MAX7219 OK~n ~p ~n", [Data]),
    NewState = #snake{spi = SPI, snakehead = SnakeHead, snakebody = SnakeBody, snakelen = 2,
                        food = Food, direction = ?DIRECTION, data = Data, gameover = false},
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
    display_gameover(State#snake.spi, Times),
    {noreply, State};

% Handle blink the food (need check current game over status)
handle_cast(turn_off_food, State) ->
    if
        State#snake.gameover == true ->
            {noreply, State};
        true ->
            turn_off_food(State#snake.spi, State#snake.food, State#snake.data),
            {noreply, State}
    end;

handle_cast(turn_on_food, State) ->
    if
        State#snake.gameover == true ->
            {noreply, State};
        true ->
            turn_on_food(State#snake.spi, State#snake.food, State#snake.data),
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
    {SnakeHead, SnakeBody, Food, Data} = init_snake(State#snake.spi, ?BODY),
    NewState = State#snake{snakehead = SnakeHead, snakebody = SnakeBody, snakelen = 2,
                        food = Food, direction = ?DIRECTION, data = Data, gameover = false, goverproc = undefined},
    {noreply, NewState}.

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

% Start interrupt from switch in Joystick
init_sw_interrupt() ->
    gpio:set_pin_mode(?GPIO_SW, input),
    gpio:set_pin_pull(?GPIO_SW, up),
    GPIO = gpio:start(),
    gpio:set_int(GPIO, ?GPIO_SW, rising).

% Recursive to write Data from Digit 0 to 7
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

%%% ADC part to control Joystick %%%

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

% joystick process callback
joystick(Pid, ADCX, ADCY) ->
    {ok, X} = read_adc(ADCX),
    {ok, Y} = read_adc(ADCY),
    if
        X < ?LOW_RANGE ->
            gen_server:cast(Pid, {change_direction, 1, 0});
        Y < ?LOW_RANGE ->
            gen_server:cast(Pid, {change_direction, 0, -1});
        X > ?HIGH_RANGE ->
            gen_server:cast(Pid, {change_direction, -1, 0});
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
    {HeadX, HeadY} = ?HEAD,
    Data = DigitList#{HeadY + 1 := (128 bsr HeadX), HeadY := (128 bsr HeadX)},
    % Radom first food and add to Data
    {FoodX, FoodY} = spawn_new_food(Body, 2),
    Row = maps:get(FoodY + 1, Data) bor (128 bsr FoodX),
    NewData = Data#{FoodY + 1 := Row},

    write_digit(SPI, ?DIGIT_0, NewData),
    {{HeadX, HeadY}, ?BODY, {FoodX, FoodY}, NewData}.

move_snake(State) ->
    % Update new Snake Head
    {X, Y} = State#snake.snakehead,
    {DirX, DirY} = State#snake.direction,
    SnakeHead = {X + DirX, Y + DirY},

    % Handle border
    NewSnakeHead = handle_border(SnakeHead),

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
            NewData = handle_game_over(State#snake.snakelen),
            write_digit(State#snake.spi, ?DIGIT_0, NewData),
            timer:sleep(2000),
            % Spawn new process to send display_game_over request
            NewProc = spawn(?MODULE, game_over_process, [self(), 0]),
            State#snake{gameover = true, goverproc = NewProc};
        true ->
            % Game not over yet, update new Snake and display in Ledmatrix
            NewData = update_data(NewSnakeBody, NewFood, NewSnakeLen, 0, ?EMPTY_MATRIX),
            write_digit(State#snake.spi, ?DIGIT_0, NewData),
            State#snake{snakehead = NewSnakeHead, snakebody = NewSnakeBody,
                        snakelen = NewSnakeLen, food = NewFood, data = NewData}
    end.

% Handler if snake reach to the border
handle_border({X, Y}) ->
    if
        X > 7 ->
            {0, Y};
        X < 0 ->
            {7, Y};
        Y > 7 ->
            {X, 0};
        Y < 0 ->
            {X, 7};
        true ->
            {X, Y}
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
update_data(_SnakeBody, NewFood, SnakeLen, SnakeLen, PreviousData) ->
    write_element(NewFood, PreviousData);
update_data(SnakeBody, NewFood, SnakeLen, Number, PreviousData) ->
    Element = maps:get(Number, SnakeBody),
    NewData = write_element(Element, PreviousData),
    update_data(SnakeBody, NewFood, SnakeLen, Number + 1, NewData).

% Helper function to write single element to the MAX7219
write_element({X, Y}, Data) ->
    NewX = 128 bsr X,
    CurrentRow = maps:get(Y + 1, Data),
    NewRow = NewX bor CurrentRow,
    Data#{Y + 1 := NewRow}.

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
handle_game_over(SnakeLen) ->
    FirstNum = get_num_macro(SnakeLen div 10, left),
    SecondNum = get_num_macro(SnakeLen rem 10, right),
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

% Merge two map contain two Score character to one Map to display on Led maxtrix
merge_two_maps(Result, _Map1, _Map2, 9) ->
    Result;
merge_two_maps(Result, Map1, Map2, Number) ->
    Temp1 = maps:get(Number, Map1),
    Temp2 = maps:get(Number, Map2),
    NewRow = Temp1 bor Temp2,
    NewResult = Result#{Number := NewRow},
    merge_two_maps(NewResult, Map1, Map2, Number + 1).

% Display 8 bits * 8 rows of curent GAME OVER text
display_gameover(SPI, Times) ->
    EmtyData = ?EMPTY_MATRIX,
    Data = get_data(EmtyData, 1, Times),
    write_digit(SPI, 1, Data).

% Get 8bits of each Row then combine to one Map
get_data(Result, 9, _Times) ->
    Result;
get_data(Result, Number, Times) ->
    Num = maps:get(Number, ?GAME_OVER),
    % Num of bits in one Row in GAME OVER map is 40bits and we want to get 8bit
    % So we use 32 - Times which equal to 40 - 8 - Times
    Row = (Num bsr (32 - Times)) band 16#ff,
    NewResult = Result#{Number := Row},
    get_data(NewResult, Number + 1, Times).

% If user control the snake moving backward, ignore that signal
is_backward(State, Direction) ->
    {PreX, PreY} = maps:get(State#snake.snakelen - 2, State#snake.snakebody),
    {HeadX, HeadY} = State#snake.snakehead,
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


% Food handler
spawn_new_food(Body, Size) ->
    FoodX = rand(),
    FoodY = rand(),
    % Food position dupplicate with snake, Spawn new food
    % Otherwise return the food
    Flag = is_exits(Body, {FoodX, FoodY}, Size, 0),
    if
        Flag ->
            spawn_new_food(Body, Size);
        true ->
            {FoodX, FoodY}
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
turn_off_food(SPI, {FoodX, FoodY}, Data) ->
    Row = maps:get(FoodY + 1, Data),
    Temp = Row band (bnot (128 bsr FoodX)),
    write_register(SPI, FoodY + 1, Temp).

turn_on_food(SPI, {FoodX, FoodY}, Data) ->
    Row = maps:get(FoodY + 1, Data),
    Temp = Row bor (128 bsr FoodX),
    write_register(SPI, FoodY + 1, Temp).


% Game over process callback
game_over_process(P, Times) ->
    receive
        stop ->
            ok
    after 300 ->
        gen_server:cast(P, {display_game_over, Times}),
        % Handle to display GAME OVER text again
        case (Times + 1) == 33 of
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