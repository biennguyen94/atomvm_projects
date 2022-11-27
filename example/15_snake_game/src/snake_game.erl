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
    gpio
    }).

-record(row1, {
    row1=16#00,
    row2=16#00,
    row3=16#00,
    row4=16#00,
    row5=16#00,
    row6=16#00,
    row7=16#00,
    row8=16#00
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
    row,
    gpio,
    adc,
    game_board,
    previous_direction = 0,
    snake_position
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
    loop(P, #main{adc={ADC_X, ADC_Y}, game_board=GameBoard, spi=SPI, row=#row1{row2=16#00}, snake_position = {SnakeRow, SnakeCol}}).

loop(P, S=#main{adc={ADC_X, ADC_Y}, game_board=GameBoard, spi=SPI, previous_direction = PrevSnakeDirection, row=#row1{row2=Row2} = Row, snake_position ={SnakeRow, SnakeCol}}) ->
    timer:sleep(1000),
    TheList = "AVM",
    gen_server:call(P, {send, TheList}),
    io:format("Sending: ~s~n", [TheList]),

    %%main
    {FoodRow, FoodCol} = generate_food(GameBoard),
    io:format("FoodRow, FoodCol : ~p, ~p~n", [FoodRow, FoodCol]),

    %begin test
    io:format("NewRow1 : ~p~n", [Row2]),
    % NewRow2 = set_led(SPI, get_row(Row, FoodRow), FoodRow, FoodCol, 1),
    % io:format("NewRow2 : ~p~n", [NewRow2]),

    NewRow2 = blink_food(SPI, Row, FoodRow, FoodCol, 0, 10),

    Random = atomvm:random() rem 100,
    io:format("Random : ~p~n", [Random]),
    %end test

    SnakeDirection = scan_joystick(ADC_X, ADC_Y, {FoodRow, FoodCol}, SPI, PrevSnakeDirection),
    io:format("SnakeDirection : ~p~n", [SnakeDirection]),

    % calculate_snake(SnakeDirection, {SnakeRow, SnakeCol}),

    read_adc({ADC_X, ADC_Y}),
    loop(P, S#main{previous_direction = SnakeDirection,
        row=#row1{row2=NewRow2}}).

init(_) ->
    {ok, []}.

handle_call(init, _From, _S) ->

    % setup ADC (joystick)
    {ADC_X, ADC_Y} = setup_adc(),

    % setup SPI (matrix led)
    GPIO = gpio:open(),
    {ok, SPI} = init_matrix_led(GPIO, ?SPISettings),

    % init gameboard
    GameBoard = [0 || C <- lists:seq(1, 64)],

    % init random snake row & col
    SnakeRow = random(8),
    SnakeCol = random(8),

    {reply, [{ADC_X, ADC_Y}, GameBoard, SPI, {SnakeRow, SnakeCol}], #state{spi=SPI, row = #row{row1 = 16#70}, gpio=GPIO}};

handle_call({send, _Msg}, _From, S=#state{spi=SPI, row=#row{row1=Row1}, gpio=GPIO}) ->
    {reply, ok, S};

handle_call(Call, _From, State) ->
    erlang:display(Call),
    {reply, ok, State}.

handle_info({gpio_interrupt, 26}, SPI) ->
    {noreply, SPI}.

terminate(_Reason, _State) ->
    ok.


% calculate_snake(SnakeDirection, {SnakeRow, SnakeCol}, Row, SPI) ->
%     {SnakeRow1, SnakeCol1} = case SnakeDirection of
%         1 ->
%             NewSnakeRow = SnakeRow-1,
%             set_led(SPI, get_row(Row, NewSnakeRow), NewSnakeRow, SnakeCol, 1),
%             {NewSnakeRow, SnakeCol};
%         2 ->
%             NewSnakeCol = SnakeCol+1,
%             set_led(SPI, get_row(Row, SnakeRow), SnakeRow, NewSnakeCol, 1),
%             {SnakeRow, NewSnakeCol};
%         3 ->
%             NewSnakeRow = SnakeRow+1,
%             set_led(SPI, get_row(Row, NewSnakeRow), NewSnakeRow, SnakeCol, 1),
%             {NewSnakeRow, SnakeCol};
%         4 ->
%             NewSnakeCol = SnakeCol-1,
%             set_led(SPI, get_row(Row, SnakeRow), SnakeRow, NewSnakeCol, 1),
%             {SnakeRow, NewSnakeCol};
%         _ ->
%             {-1, -1}
%     end,


generate_food(GameBoard) ->
    FoodRow = random(8),
    FoodCol = random(8),
    GameBoardRes = game_board(FoodRow, FoodCol, GameBoard),
    io:format("GameBoardRes: ~p~n", [GameBoardRes]),
    generate_food(GameBoard, GameBoardRes, {FoodRow, FoodCol}).

generate_food(GameBoard, GameBoardRes, _) when GameBoardRes > 0 ->
    generate_food(GameBoard);
generate_food(_GameBoard, _GameBoardRes, {FoodRow, FoodCol}) ->
    {FoodRow, FoodCol}.

set_led(SPI, Status, Row, Col, Value) when Value == 1 ->
    X = Status bor (16#80 bsr (Col-1)),
    io:format("XXXXXXXX : ~p~n", [X]),
    write_register(SPI, Row, X, any_gpio),
    X;

set_led(SPI, Status, Row, Col, Value) when Value == 0 ->
    Y = Status band bnot (16#80 bsr (Col-1)),
    io:format("YYYYYYYY : ~p~n", [Y]),
    write_register(SPI, Row, Y, any_gpio),
    Y.

get_row(#row1{row1 = Row1}, 1) -> Row1;
get_row(#row1{row2 = Row2}, 2) -> Row2;
get_row(#row1{row3 = Row3}, 3) -> Row3;
get_row(#row1{row4 = Row4}, 4) -> Row4;
get_row(#row1{row5 = Row5}, 5) -> Row5;
get_row(#row1{row6 = Row6}, 6) -> Row6;
get_row(#row1{row7 = Row7}, 7) -> Row7;
get_row(#row1{row8 = Row8}, 8) -> Row8.

blink_food(SPI, Row, FoodRow, FoodCol, SetLedRes, 0) -> SetLedRes;
blink_food(SPI, Row, FoodRow, FoodCol, _SetLedRes, Counter) ->
    SetLedRes = case choose(atomvm:random() rem 100 < 50, 1, 0) of
        1 ->
            set_led(SPI, get_row(Row, FoodRow), FoodRow, FoodCol, 1);
        0 ->
            set_led(SPI, get_row(Row, FoodRow), FoodRow, FoodCol, 0)
    end,
    timer:sleep(500),
    blink_food(SPI, Row, FoodRow, FoodCol, SetLedRes, Counter-1).

random(N) ->
    {MegaSecs, Secs, MicroSecs} = erlang:timestamp(),
    ((MegaSecs bxor Secs bxor MicroSecs) rem N) + 1.

game_board(SnakeRow, SnakeCol, GameBoard) ->
    Index = array_mapping(SnakeRow, SnakeCol),
    lists:nth(Index, GameBoard).

scan_joystick(ADC_X, ADC_Y, {FoodRow, FoodCol}, SPI, PrevSnakeDirection) ->
    SnakeDirection = case adc:read(ADC_X) of
        {ok, {Raw2, _MilliVolts2}} when Raw2 < 1500 ->
            io:format("ADC_X 1: ~p~n", [Raw2]),
            1;
        {ok, {Raw2, _MilliVolts2}} when Raw2 > 3500 ->
            io:format("ADC_X 3: ~p~n", [Raw2]),
            3;
        {ok, {Raw2, _MilliVolts2}} ->
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
    PreviousDirection = PrevSnakeDirection,
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

read_adc({ADC_X, ADC_Y}) ->
    case adc:read(ADC_X) of
        {ok, {Raw, MilliVolts}} ->
            io:format("Raw: ~p Voltage: ~pmV~n", [Raw, MilliVolts]);
        Error ->
            io:format("Error taking reading: ~p~n", [Error])
    end,
    timer:sleep(1000),
    case adc:read(ADC_Y) of
        {ok, {Raw2, MilliVolts2}} ->
            io:format("Raw2: ~p Voltage2: ~pmV~n", [Raw2, MilliVolts2]);
        Error2 ->
            io:format("Error taking reading: ~p~n", [Error2])
    end,
    timer:sleep(1000),
    ok.


init_matrix_led(GPIO, SPISettings) ->
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

show_message1(N, SPI, GPIO, 9) ->
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


read_register(SPI, Address) ->
    spi:read_at(SPI, Address, 8).

write_register(SPI, Address, Data, GPIO) ->
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