%
% This file is part of AtomVM.
%
% Copyright 2022 Bien Nguyen <nguyennhubientdh94@gmail.com>
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
%    http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%

-module(snake_game).
-export([start/0]).
-export([init/1, handle_call/3, handle_info/2, terminate/2]).

-record(state, {spi="",
    row,
    adc,
    gpio
    }).

-record(row, {
    row1=16#00,
    row2=16#00,
    row3=16#00,
    row4=16#00,
    row5=16#00,
    row6=16#00,
    row7=16#00,
    row8=16#00
    }).

-record(main, {spi,
    gpio,
    adc,
    game_board,
    previous_direction = 0,
    snake_position,
    food_position = {-1,-1},
    snake_length  = 3
    }).

-define(InitialSnakeLength, 3).
-define(Initial_Snake_Row, 3).
-define(Initial_Snake_Col, 3).
-define (SPISettings, [
    {bus_config, [
            {miso_io_num, 19},
            {mosi_io_num, 27},
            {sclk_io_num, 5}
        ]},
        {device_config, [
            {spi_clock_hz, 1000000},
            {spi_mode, 0},
            {spi_cs_io_num, 18},
            {address_len_bits, 8}
        ]}
    ]).

start() ->
    {ok, P} = gen_server:start(?MODULE, [], []),
    [{ADC_X, ADC_Y}, GameBoard, SPI, {SnakeRow, SnakeCol}]  = gen_server:call(P, init),
    loop(P, #main{adc={ADC_X, ADC_Y}, game_board=GameBoard, spi=SPI, snake_position = {SnakeRow, SnakeCol}}).

loop(P, S=#main{adc={_ADC_X, _ADC_Y}, game_board=GameBoard, spi=SPI, previous_direction = PrevSnakeDirection,
		food_position ={FoodRow1, FoodCol1}, snake_length = SnakeLength, snake_position = {SnakeRow, SnakeCol}}) ->
    io:format("Loop start~n"),

    Row  = gen_server:call(P, get_raw_status),
    io:format("Raw test : ~p~n", [Row]),

    {FoodRow, FoodCol} = generate_food(GameBoard, {FoodRow1, FoodCol1}),
    io:format("FoodRow, FoodCol : ~p, ~p~n", [FoodRow, FoodCol]),

    SnakeDirection1 = gen_server:call(P, {scan_joystick, [FoodRow, FoodCol]}),
    SnakeDirection = choose(SnakeDirection1 /=0, SnakeDirection1, PrevSnakeDirection),
    io:format("PrevSnakeDirection, SnakeDirection1, SnakeDirection: ~p, ~p, ~p~n",[PrevSnakeDirection, SnakeDirection1, SnakeDirection]),

    [{NewFoodRow, NewFoodCol}, SnakeLengthNew, GameBoard2, {NewSnakeRow, NewSnakeCol}] =
        calculate_snake(SnakeDirection, {SnakeRow, SnakeCol}, GameBoard, P, {FoodRow, FoodCol}, SnakeLength),
    io:format("SnakeLengthNew test : ~p~n", [SnakeLengthNew]),

    %TODO: add handleGameStates function (win/gameOver), and restart all variables

    io:format("Loop end~n"),

    loop(P, S#main{previous_direction = SnakeDirection, game_board=GameBoard2, food_position = {NewFoodRow, NewFoodCol},
		   snake_length = SnakeLengthNew, snake_position = {NewSnakeRow, NewSnakeCol}}).

init(_) ->
    {ok, []}.

handle_call(init, _From, _S) ->

    io:format("Init start~n"),
    % setup ADC (joystick)
    {ADC_X, ADC_Y} = setup_adc(),

    % setup SPI (matrix led)
    GPIO = gpio:open(),
    {ok, SPI} = init_matrix_led(GPIO, ?SPISettings),

    % init gameboard
    GameBoard = [{{R, C}, 0} || R <- lists:seq(1, 8),  C <- lists:seq(1, 8)],

    % init random snake row & col
    SnakeRow = random(8),
    SnakeCol = random(8),

    io:format("Init end~n"),
    {reply, [{ADC_X, ADC_Y}, GameBoard, SPI, {SnakeRow, SnakeCol}], #state{spi=SPI, adc={ADC_X, ADC_Y},
									   row = #row{}, gpio=GPIO}};

handle_call({send, _Msg}, _From, S=#state{spi=_SPI, row=#row{row1=_Row1}, gpio=_GPIO}) ->
    {reply, ok, S};

handle_call(get_raw_status, _From, S=#state{row=Row}) ->
    {reply, Row, S};

handle_call({scan_joystick, [FoodRow, FoodCol]}, _From, State=#state{adc={ADC_X, ADC_Y},
								     spi=SPI, row = Row}) ->
    timer:sleep(100),
    NewRow = set_led(SPI, Row, FoodRow, FoodCol, 1),
    SnakeDirection = do_scan_joystick(ADC_X, ADC_Y, {FoodRow, FoodCol}, SPI, anything),
    {reply, SnakeDirection, State#state{row=NewRow}};

handle_call({set_led, {Row, Col}, Value}, _From, State = #state{row=RowRec, spi=SPI}) ->
    NewRowRec = set_led(SPI, RowRec, Row, Col, Value),
    {reply, ok, State#state{row=NewRowRec}};

handle_call(Call, _From, State) ->
    erlang:display(Call),
    {reply, ok, State}.

handle_info({gpio_interrupt, 26}, SPI) ->
    {noreply, SPI}.

terminate(_Reason, _State) ->
    ok.


calculate_snake(SnakeDirection, {SnakeRow, SnakeCol}, GameBoard, P, {FoodRow, FoodCol}, SnakeLength) ->
    io:format("fix_edge start~n"),
    {SnakeRowRes, SnakeColRes} = case SnakeDirection of
        1 ->
            %DONE: the snake to appear on the other side of the screen if it gets out of the edge
    io:format("fix_edge start 1, SnakeRow, SnakeCol:  ~p, ~p~n", [SnakeRow, SnakeCol]),
            [SnakeRow1, SnakeCol1] = fix_edge(SnakeRow-1, SnakeCol),
    io:format("fix_edge stop 2~n"),
            gen_server:call(P, {set_led, {SnakeRow1, SnakeCol1}, 1}),
            {SnakeRow1, SnakeCol1};
        2 ->
            %DONE: the snake to appear on the other side of the screen if it gets out of the edge
            [SnakeRow1, SnakeCol1] = fix_edge(SnakeRow, SnakeCol+1),
            gen_server:call(P, {set_led, {SnakeRow1, SnakeCol1}, 1}),
            {SnakeRow1, SnakeCol1};
        3 ->
            %DONE: the snake to appear on the other side of the screen if it gets out of the edge
            [SnakeRow1, SnakeCol1] = fix_edge(SnakeRow+1, SnakeCol),
            gen_server:call(P, {set_led, {SnakeRow1, SnakeCol1}, 1}),
            {SnakeRow1, SnakeCol1};
        4 ->
            %DONE: the snake to appear on the other side of the screen if it gets out of the edge
            [SnakeRow1, SnakeCol1] = fix_edge(SnakeRow, SnakeCol-1),
            gen_server:call(P, {set_led, {SnakeRow1, SnakeCol1}, 1}),
            {SnakeRow1, SnakeCol1};
        _ ->
            {SnakeRow, SnakeCol}
    end,
    io:format("fix_edge stop~n"),
    % TODO: if there is a snake body segment, this will cause the end of the game (snake must be moving)
    % GameBoardRes = game_board(SnakeRowRes, SnakeColRes, GameBoard),
    % case GameBoardRes>1 of
    %     true -> return;
    %     _ -> ok
    % end,

    % DONE: check if the food was eaten
    [{NewFoodRow, NewFoodCol}, NewSnakeLength, GameBoard12]=
    case FoodRow == SnakeRowRes andalso FoodCol == SnakeColRes of
        true ->
            GameBoard11 = lists:map(fun({{RowMap, ColMap}, Value})->
                case Value > 0 of
                    true ->
                        {{RowMap, ColMap}, Value + 1};
                    _ ->
                        {{RowMap, ColMap}, Value}
                end
            end, GameBoard),
            [{-1,-1}, SnakeLength + 1, GameBoard11];
        false ->
            [{FoodRow, FoodCol}, SnakeLength, GameBoard]
    end,

    GameBoard1 = update_game_board(GameBoard12, SnakeRowRes, SnakeColRes, NewSnakeLength + 1),

    GameBoard2 = lists:map(fun({{RowMap, ColMap}, Value})->
        case Value > 0 of
            true ->
                case (Value - 1) > 0 of
                    true ->
                        gen_server:call(P, {set_led, {RowMap, ColMap}, 1});
                    false ->
                        gen_server:call(P, {set_led, {RowMap, ColMap}, 0})
                end,
                {{RowMap, ColMap}, Value - 1};
            _ ->
                gen_server:call(P, {set_led, {RowMap, ColMap}, 0}),
                {{RowMap, ColMap}, Value}
        end
    end, GameBoard1),
    [{NewFoodRow, NewFoodCol}, NewSnakeLength, GameBoard2, {SnakeRowRes, SnakeColRes}].

fix_edge(SnakeRow, SnakeCol) when SnakeRow < 1 orelse SnakeRow > 8 ->
    case SnakeRow < 1 of
        true -> fix_edge2(SnakeRow+8, SnakeCol);
        _ -> fix_edge2(SnakeRow-8, SnakeCol)
    end;
fix_edge(SnakeRow, SnakeCol) ->
    fix_edge2(SnakeRow, SnakeCol).


fix_edge2(SnakeRow, SnakeCol) when SnakeCol < 1 orelse SnakeCol > 8 ->
    case SnakeCol < 1 of
        true -> [SnakeRow, SnakeCol+8];
        _ -> [SnakeRow, SnakeCol-8]
    end;
fix_edge2(SnakeRow, SnakeCol) -> [SnakeRow, SnakeCol].

update_game_board(GameBoard, Row, Col, Value) ->
    % Index = array_mapping(Row, Col),
    % lists:sublist(GameBoard, Index-1) ++ [{{Row, Col}, Value}] ++ lists:nthtail(Index,GameBoard).
    lists:keyreplace({Row, Col}, 1, GameBoard, {{Row, Col}, Value}).

%% TODO: check for victory (win)
generate_food(GameBoard, {-1, -1}) ->
    FoodRow = random(8),
    FoodCol = random(8),
    io:format("genarate_food~n"),
    GameBoardRes = game_board(FoodRow, FoodCol, GameBoard),
    io:format("genarate_food, GameBoardRes:~p~n", [GameBoardRes]),
    generate_food(GameBoard, GameBoardRes, {FoodRow, FoodCol});
generate_food(_GameBoard, {FoodRow, FoodCol}) -> {FoodRow, FoodCol}.

generate_food(GameBoard, {_, GameBoardRes}, {_FoodRow, _FoodCol}) when GameBoardRes > 0 ->
    generate_food(GameBoard, {-1, -1});
generate_food(_GameBoard, _GameBoardRes, {FoodRow, FoodCol}) ->
    {FoodRow, FoodCol}.

set_led(SPI, RowRec, Row, Col, 1) ->
    Status = get_row_status(RowRec, Row),
    NewStatus = Status bor (16#80 bsr (Col-1)),
    write_register(SPI, Row, NewStatus, any_gpio),
    update_and_return_row_status(Row, RowRec, NewStatus);

set_led(SPI, RowRec, Row, Col, 0) ->
    Status = get_row_status(RowRec, Row),
    NewStatus = Status band bnot (16#80 bsr (Col-1)),
    write_register(SPI, Row, NewStatus, any_gpio),
    update_and_return_row_status(Row, RowRec, NewStatus).

update_and_return_row_status(Row, RowRec, NewStatus) ->
    case Row of
        1 -> RowRec#row{row1 = NewStatus};
        2 -> RowRec#row{row2 = NewStatus};
        3 -> RowRec#row{row3 = NewStatus};
        4 -> RowRec#row{row4 = NewStatus};
        5 -> RowRec#row{row5 = NewStatus};
        6 -> RowRec#row{row6 = NewStatus};
        7 -> RowRec#row{row7 = NewStatus};
        8 -> RowRec#row{row8 = NewStatus}
    end.

get_row_status(#row{row1 = Row1}, 1) -> Row1;
get_row_status(#row{row2 = Row2}, 2) -> Row2;
get_row_status(#row{row3 = Row3}, 3) -> Row3;
get_row_status(#row{row4 = Row4}, 4) -> Row4;
get_row_status(#row{row5 = Row5}, 5) -> Row5;
get_row_status(#row{row6 = Row6}, 6) -> Row6;
get_row_status(#row{row7 = Row7}, 7) -> Row7;
get_row_status(#row{row8 = Row8}, 8) -> Row8.


%blink_food(SPI, Row, FoodRow, FoodCol, SetLedRes, 0) -> SetLedRes;
%blink_food(SPI, Row, FoodRow, FoodCol, _SetLedRes, Counter) ->
%    SetLedRes = case choose(atomvm:random() rem 100 < 50, 1, 0) of
%        1 ->
%            set_led(SPI, Row, FoodRow, FoodCol, 1);
%        0 ->
%            set_led(SPI, Row, FoodRow, FoodCol, 0)
%    end,
%    timer:sleep(500),
%    blink_food(SPI, Row, FoodRow, FoodCol, SetLedRes, Counter-1).

random(N) ->
    {MegaSecs, Secs, MicroSecs} = erlang:timestamp(),
    ((MegaSecs bxor Secs bxor MicroSecs) rem N) + 1.

game_board(SnakeRow, SnakeCol, GameBoard) ->
    Index = array_mapping(SnakeRow, SnakeCol),
    lists:nth(Index, GameBoard).

do_scan_joystick(ADC_X, ADC_Y, {_FoodRow, _FoodCol}, _SPI, _PrevSnakeDirection) ->
    SnakeDirection = case adc:read(ADC_X) of
        {ok, {Raw2, _MilliVolts2}} when Raw2 < 1500 ->
            io:format("ADC_X 1: ~p~n", [Raw2]),
            1;
        {ok, {Raw2, _MilliVolts2}} when Raw2 > 3500 ->
            io:format("ADC_X 3: ~p~n", [Raw2]),
            3;
        {ok, {_Raw2, _MilliVolts2}} ->
            timer:sleep(100),
            case adc:read(ADC_Y) of
                {ok, {Raw, _MilliVolts}} when Raw < 1500 ->
                    io:format("ADC_Y 4: ~p~n", [Raw]),
                    4;
                {ok, {Raw, _MilliVolts}} when Raw > 3500 ->
                    io:format("ADC_Y 2: ~p~n", [Raw]),
                    2;
                Error ->
                    io:format("Nothing to do 1: ~p~n", [Error]),
                    0
            end;
        Error ->
            io:format("Nothing to do 2: ~p~n", [Error]),
            0
    end,
    %test
    % PreviousDirection = PrevSnakeDirection,
    %test
    SnakeDirection.
    % SnakeDirection1 = choose(((SnakeDirection + 2) == PreviousDirection) and (PreviousDirection /= 0), PreviousDirection, 0),
    % SnakeDirection2 =
    %     case SnakeDirection1 of
    %         0 -> choose(((SnakeDirection - 2) == PreviousDirection) and (PreviousDirection /= 0), PreviousDirection, 0);
    %         _ -> SnakeDirection1
    %     end.


choose(true,  True, _)  -> True;
choose(false, _, False) -> False.

setup_adc() ->
    JoystickX = 34,
    JoystickY = 35,
    {ok, ADC_X} = adc:start(JoystickX, [{attenuation, db_11}, {bit_width, bit_12}]),
    {ok, ADC_Y} = adc:start(JoystickY, [{attenuation, db_11}, {bit_width, bit_12}]),
    {ADC_X, ADC_Y}.


init_matrix_led(GPIO, SPISettings) ->
    SPI = spi:open(SPISettings),
    write_register(SPI, 16#0C, 16#01, GPIO),
    write_register(SPI, 16#0B, 16#07, GPIO),
    write_register(SPI, 16#0A, 16#00, GPIO),
    write_register(SPI, 16#09, 16#00, GPIO),
    write_register(SPI, 16#0F, 16#00, GPIO),
    {ok, SPI}.

init_matrix_led_test(GPIO, SPISettings) ->
    SPI = spi:open(SPISettings),
    write_register(SPI, 16#0C, 16#01, GPIO),
    write_register(SPI, 16#0B, 16#07, GPIO),
    write_register(SPI, 16#0A, 16#00, GPIO),
    write_register(SPI, 16#09, 16#00, GPIO),
    write_register(SPI, 16#0F, 16#00, GPIO),

    write_register(SPI, 16#01, 16#70, GPIO),
    write_register(SPI, 16#02, 16#88, GPIO),
    write_register(SPI, 16#03, 16#88, GPIO),
    write_register(SPI, 16#04, 16#88, GPIO),
    write_register(SPI, 16#05, 16#F8, GPIO),
    write_register(SPI, 16#06, 16#88, GPIO),
    write_register(SPI, 16#07, 16#88, GPIO),
    write_register(SPI, 16#08, 16#88, GPIO),

    timer:sleep(2000),
    N = 1,
    spawn(fun() -> show_message(N, SPI, GPIO, 0) end),
    {ok, SPI}.

show_message(N, SPI, GPIO, 8) ->
    show_message1(N, SPI, GPIO, 0);
show_message(N, SPI, GPIO, M) ->
    timer:sleep(500),
    write_register(SPI, 16#01, 16#18 bsr M, GPIO),
    write_register(SPI, 16#02, 16#24 bsr M, GPIO),
    write_register(SPI, 16#03, 16#42 bsr M, GPIO),
    write_register(SPI, 16#04, 16#42 bsr M, GPIO),
    write_register(SPI, 16#05, 16#7E bsr M, GPIO),
    write_register(SPI, 16#06, 16#42 bsr M, GPIO),
    write_register(SPI, 16#07, 16#42 bsr M, GPIO),
    write_register(SPI, 16#08, 16#42 bsr M, GPIO),
    show_message(N, SPI, GPIO, M+1).

show_message1(_N, _SPI, _GPIO, 9) ->
    % show_message1(N, SPI, GPIO, 0);
    ok;
show_message1(N, SPI, GPIO, M) ->
    timer:sleep(500),
    write_register(SPI, 16#01, 16#70 bsr M, GPIO),
    write_register(SPI, 16#02, 16#88 bsr M, GPIO),
    write_register(SPI, 16#03, 16#88 bsr M, GPIO),
    write_register(SPI, 16#04, 16#88 bsr M, GPIO),
    write_register(SPI, 16#05, 16#F8 bsr M, GPIO),
    write_register(SPI, 16#06, 16#88 bsr M, GPIO),
    write_register(SPI, 16#07, 16#88 bsr M, GPIO),
    write_register(SPI, 16#08, 16#88 bsr M, GPIO),
    show_message1(N, SPI, GPIO, M+1).


%read_register(SPI, Address) ->
%    spi:read_at(SPI, Address, 8).

write_register(SPI, Address, Data, _GPIO) ->
    % gpio:set_level(GPIO, 18, 0),
    spi:write_at(SPI, Address, 8, Data).
    % gpio:set_level(GPIO, 18, 1).


array_mapping(1,1) ->
    1;
array_mapping(1,2) ->
    2;
array_mapping(1,3) ->
    3;
array_mapping(1,4) ->
    4;
array_mapping(1,5) ->
    5;
array_mapping(1,6) ->
    6;
array_mapping(1,7) ->
    7;
array_mapping(1,8) ->
    8;

array_mapping(2,1) ->
    9;
array_mapping(2,2) ->
    10;
array_mapping(2,3) ->
    11;
array_mapping(2,4) ->
    12;
array_mapping(2,5) ->
    13;
array_mapping(2,6) ->
    14;
array_mapping(2,7) ->
    15;
array_mapping(2,8) ->
    16;

array_mapping(3,1) ->
    17;
array_mapping(3,2) ->
    18;
array_mapping(3,3) ->
    19;
array_mapping(3,4) ->
    20;
array_mapping(3,5) ->
    21;
array_mapping(3,6) ->
    22;
array_mapping(3,7) ->
    23;
array_mapping(3,8) ->
    24;

array_mapping(4,1) ->
    25;
array_mapping(4,2) ->
    26;
array_mapping(4,3) ->
    27;
array_mapping(4,4) ->
    28;
array_mapping(4,5) ->
    29;
array_mapping(4,6) ->
    30;
array_mapping(4,7) ->
    31;
array_mapping(4,8) ->
    32;

array_mapping(5,1) ->
    33;
array_mapping(5,2) ->
    34;
array_mapping(5,3) ->
    35;
array_mapping(5,4) ->
    36;
array_mapping(5,5) ->
    37;
array_mapping(5,6) ->
    38;
array_mapping(5,7) ->
    39;
array_mapping(5,8) ->
    40;

array_mapping(6,1) ->
    41;
array_mapping(6,2) ->
    42;
array_mapping(6,3) ->
    43;
array_mapping(6,4) ->
    44;
array_mapping(6,5) ->
    45;
array_mapping(6,6) ->
    46;
array_mapping(6,7) ->
    47;
array_mapping(6,8) ->
    48;

array_mapping(7,1) ->
    49;
array_mapping(7,2) ->
    50;
array_mapping(7,3) ->
    51;
array_mapping(7,4) ->
    52;
array_mapping(7,5) ->
    53;
array_mapping(7,6) ->
    54;
array_mapping(7,7) ->
    55;
array_mapping(7,8) ->
    56;

array_mapping(8,1) ->
    57;
array_mapping(8,2) ->
    58;
array_mapping(8,3) ->
    59;
array_mapping(8,4) ->
    60;
array_mapping(8,5) ->
    61;
array_mapping(8,6) ->
    62;
array_mapping(8,7) ->
    63;
array_mapping(8,8) ->
    64.
