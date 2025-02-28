%%
%% Copyright (c) 2024 <nguyennhubientdh94@gmail.com>
%% All rights reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
-module(snake_blockbreaker).

-include("snake_game_2led.hrl").

-export([start/0]).

-export([display_select_game/2, select_game1/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
        terminate/2, code_change/3]).

start() ->
    erlang:system_flag(schedulers_online, 2),
    {ok, Pid} = gen_server:start({local, snake_blockbreaker}, ?MODULE, [], []),
    {ADCX, _ADCY} = setup_adc(),
    select_game(Pid, ADCX).

init(_) ->
    {ok, SPI} = init_max7219(?SPISettings),
    io:format("Init SPI and MAX7219 OK~n ~n"),
    NewProc = spawn(?MODULE, display_select_game, [self(), 0]),
    NewState = #state{spi = SPI, goverproc = NewProc},
    {ok, NewState}.

handle_call(_Msg, _From, State) ->
    {reply, ok, State}.

handle_cast(game_over, State) ->
    io:format("parent game_over~n ~n"),
    NewProc = spawn(?MODULE, display_select_game, [self(), 0]),
    spawn(?MODULE, select_game1, [self(), ?GPIO_VRx]),
    NewState = State#state{goverproc = NewProc},
    {noreply, NewState};

handle_cast({display_select_game_flag, Times}, State) ->
    display_game_text(State#state.spi, Times),
    {noreply, State}.

handle_info({From, do_select_game}, State) ->
    io:format("receive do_select_game~n"),
    case is_pid(State#state.goverproc) of
        true ->
            State#state.goverproc ! stop;
        false ->
            ok
    end,
    NewState = State#state{goverproc = undefined},
    From ! {spi, State#state.spi},
    {noreply, NewState}.

code_change(_OldVsn, State, _Extra) -> {ok, State}.

terminate(_Reason, _State) ->
    ok.

select_game(Pid, ADCX) ->
    {ok, X} = read_adc(ADCX),
    if
        X < ?LOW_RANGE ->
            Pid ! {self(), do_select_game},
            receive
                {spi, SPI} -> snake_game_2led:start(SPI)
            end;
        X > ?HIGH_RANGE ->
            Pid ! {self(), do_select_game},
            receive
                {spi, SPI} -> block_breaker_2led:start(SPI)
            end;
        true ->
            timer:sleep(?DELAY_READ_ADC),
            select_game(Pid, ADCX)
    end.

select_game1(Pid, ADCX) ->
    {ok, X} = read_adc(ADCX),
    if
        X < ?LOW_RANGE ->
            Pid ! {self(), do_select_game},
            receive
                {spi, SPI} -> snake_game_2led:start(SPI)
            end;
        X > ?HIGH_RANGE ->
            Pid ! {self(), do_select_game},
            receive
                {spi, SPI} -> block_breaker_2led:start(SPI)
            end;
        true ->
            timer:sleep(?DELAY_READ_ADC),
            select_game1(Pid, ADCX)
    end.

% Display functions
display_select_game(P, Times) ->
    receive
        stop ->
            ok
    after 800 ->
        gen_server:cast(P, {display_select_game_flag, Times}),
        case (Times + 8) > 32 of
            true ->
                NewTimes = 0;
            false ->
                NewTimes = Times + 8
        end,
        display_select_game(P, NewTimes)
    end.

display_game_text(SPI, Times) ->
    Data1 = get_data(?EMPTY_MATRIX, 1, Times, snake),
    Data2 = get_data(?EMPTY_MATRIX, 1, Times, breaker),
    write_digit(SPI, ?DIGIT_0, Data1, device_1),
    write_digit(SPI, ?DIGIT_0, Data2, device_2).

% ADC
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

% SPI
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

get_data(Result, 9, _Times, _) ->
    Result;

get_data(Result, Number, Times, snake) ->
    Row = maps:get(Number + Times, ?SELECT_GAME_SNAKE),
    NewResult = Result#{Number := Row},
    get_data(NewResult, Number + 1, Times, snake);

get_data(Result, Number, Times, breaker) ->
    Row = maps:get(Number + Times, ?SELECT_GAME_BREAKER),
    NewResult = Result#{Number := Row},
    get_data(NewResult, Number + 1, Times, breaker).

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
