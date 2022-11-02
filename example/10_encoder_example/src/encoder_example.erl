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

-module(encoder_example).

-export([start/0]).

-define(PINA, 2).
-define(PINB, 3).
-define(Interval, 25). %25ms

start() ->
    gpio:set_pin_mode(?PINA, input),
    gpio:set_pin_mode(?PINB, input),
    gpio:set_pin_pull(?PINA, up),
    gpio:set_pin_pull(?PINB, up),
    GPIO = gpio:start(),
    gpio:set_int(GPIO, ?PINA, falling),
    timer:sleep(1000),
    main().

main()->
    Pid = spawn(fun() -> interrupt(0, 0) end),
    spawn(fun() -> sample_time(Pid) end).

sample_time(Pid) ->
    erlang:send_after(?Interval, Pid, {get_pulse, self()}),
    receive
        {pulse_value, NewPulse, Pulse} -> calculate_velocity(NewPulse, Pulse)
    end,
    sample_time(Pid).

calculate_velocity(NewPulse, Pulse) ->
    Vel = (NewPulse-Pulse)*1000/?Interval,
    io:format("Velocity ~p~n", [Vel]),
    ok.

interrupt(NewPulse, Pulse) ->
    io:format("Waiting for interrupt ... "),
    receive
        {gpio_interrupt, ?PINA} ->
            io:format("Interrupt on pin ~p~n", [?PINA]),
            NewPulse2 = do_interrupt(NewPulse),
            interrupt(NewPulse2, NewPulse);
        {get_pulse, From} ->
            From ! {pulse_value, NewPulse, Pulse},
            interrupt(NewPulse, Pulse)
    end.

do_interrupt(Pulse) ->
    case not gpio:digital_read(?PINB) of
        true -> Pulse + 1;
        _ -> Pulse - 1
    end.

