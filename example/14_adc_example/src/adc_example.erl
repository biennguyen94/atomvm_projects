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

-module(adc_example).

-export([start/0]).

start() ->
    Pin = 34,
    Pin2 = 35,
    {ok, ADC} = adc:start(Pin, [{attenuation, db_11},{bit_width, bit_12}]),
    {ok, ADC2} = adc:start(Pin2, [{attenuation, db_11}, {bit_width, bit_12}]),
    loop(ADC, ADC2).

loop(ADC, ADC2) ->
    case adc:read(ADC) of
        {ok, {Raw, MilliVolts}} ->
            io:format("Raw: ~p Voltage: ~pmV~n", [Raw, MilliVolts]);
        Error ->
            io:format("Error taking reading: ~p~n", [Error])
    end,
    timer:sleep(1000),
    case adc:read(ADC2) of
        {ok, {Raw2, MilliVolts2}} ->
            io:format("Raw2: ~p Voltage2: ~pmV~n", [Raw2, MilliVolts2]);
        Error2 ->
            io:format("Error taking reading: ~p~n", [Error2])
    end,
    timer:sleep(1000),
    loop(ADC, ADC2).
