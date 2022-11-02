%
% This file is part of AtomVM.
%
% Copyright 2019-2020 Bien Nguyen <nguyennhubientdh94@gmail.com>
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

-module(hr05_example).
-export([start/0]).

-define(TRIG, 2).
-define(ECHO, 3).

start() ->
    gpio:set_pin_mode(?TRIG, output),
    gpio:set_pin_mode(?ECHO, input),
    timer:sleep(2),
    loop().

loop() ->
    trigger_pin_setup(),
    SensorTime = read_echo_time(0),
    Distance = SensorTime * 0.034/2,
    io:format("Distance: ~p~n", [Distance]),
    timer:sleep(3000),
    loop().


trigger_pin_setup() ->
    gpio:digital_write(?TRIG, low),
    usleep(2),
    gpio:digital_write(?TRIG, high),
    usleep(10),
    gpio:digital_write(?TRIG, low).

read_echo_time(0) ->
    LocalTime = do_read_echo_time(0),
    read_echo_time(LocalTime);
read_echo_time(LocalTime) ->
    LocalTime.

do_read_echo_time(LocalTime) ->
    case gpio:digital_read(?ECHO) == high of
        true ->
            usleep(1),
            do_read_echo_time(LocalTime+1);
        _ ->
            LocalTime
    end.

usleep(Time) when is_integer(Time) andalso Time >= 0 ->
    do_usleep(Time),
    receive
        sleep_done -> ok
    end.
do_usleep(Time) ->
    MonotonicTime = erlang:system_time(microsecond),
    do_usleep(MonotonicTime, Time).

do_usleep(Start, Time) ->
    case erlang:system_time(microsecond) - Start >= Time of
        true ->
            self() ! sleep_done;
        _ ->
            do_usleep(Start, Time)
    end.

% usleep(Time) when is_integer(Time) andalso Time >= 0 ->
%     do_usleep(Time),
%     receive
%         sleep_done -> ok
%     end.
% do_usleep(Time) ->
%     MonotonicTime = erlang:monotonic_time(microsecond),
%     do_usleep(MonotonicTime, Time).

% do_usleep(Start, Time) ->
%     case erlang:monotonic_time(microsecond) - Start >= Time of
%         true ->
%             self() ! sleep_done;
%         _ ->
%             do_usleep(Start, Time)
%     end.
