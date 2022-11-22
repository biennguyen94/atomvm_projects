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

-module(spi_example).
-export([start/0]).
-export([init/1, handle_call/3, handle_info/2, terminate/2]).

-define (SPISettings, [
    {bus_config, [
            % {miso_io_num, 19},
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
    gen_server:call(P, init),
    loop(P).

loop(P) ->
    timer:sleep(1000),
    TheList = "AVM",
    gen_server:call(P, {send, TheList}),
    io:format("Sending: ~s~n", [TheList]),
    loop(P).

init(_) ->
    {ok, {}}.

handle_call(init, _From, _State) ->
    GPIO = gpio:open(),
    {ok, SPI} = init_sx127x(GPIO, ?SPISettings),
    {reply, ok, SPI};

handle_call({send, _Msg}, _From, SPI) ->
    {reply, ok, SPI};

handle_call(Call, _From, State) ->
    erlang:display(Call),
    {reply, ok, State}.

handle_info({gpio_interrupt, 26}, SPI) ->
    {noreply, SPI}.

terminate(_Reason, _State) ->
    ok.

init_sx127x(GPIO, SPISettings) ->
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

    write_register(SPI, 1, 16#18, GPIO),
    write_register(SPI, 2, 16#24, GPIO),
    write_register(SPI, 3, 16#42, GPIO),
    write_register(SPI, 4, 16#42, GPIO),
    write_register(SPI, 5, 16#7E, GPIO),
    write_register(SPI, 6, 16#42, GPIO),
    write_register(SPI, 7, 16#42, GPIO),
    write_register(SPI, 8, 16#42, GPIO),
    {ok, SPI}.

% read_register(SPI, Address) ->
%     spi:read_at(SPI, Address, 8).

write_register(SPI, Address, Data, GPIO) ->
    % gpio:set_level(GPIO, 18, 0),
    spi:write_at(SPI, Address, 8, Data).
    % gpio:set_level(GPIO, 18, 1).
