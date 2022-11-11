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

-module(remote_robot_web_server).

-export([start/0, handle_req/3]).

-define(MOTOR_1_PIN_1, 4).
-define(MOTOR_1_PIN_2, 16).
-define(MOTOR_2_PIN_1, 5).
-define(MOTOR_2_PIN_2, 18).

start() ->
    setup_motor(),
    Self = self(),
    Config = [
        {sta, [
            {ssid, esp:nvs_get_binary(atomvm, sta_ssid, <<"HBTBK">>)},
            {psk,  esp:nvs_get_binary(atomvm, sta_psk, <<"49494949">>)},
            {connected, fun() -> Self ! connected end},
            {got_ip, fun(IpInfo) -> Self ! {ok, IpInfo} end},
            {disconnected, fun() -> Self ! disconnected end}
        ]}
    ],
    case network:start(Config) of
        ok ->
            wait_for_message();
        Error ->
            erlang:display(Error)
    end.

setup_motor() ->
    MotorPinList = [?MOTOR_1_PIN_1, ?MOTOR_1_PIN_2,
        ?MOTOR_2_PIN_1, ?MOTOR_2_PIN_2],
    setup_motor(MotorPinList).

setup_motor(MotorPinList) ->
    lists:foreach(
        fun(MotorPin) ->
            gpio:set_pin_mode(MotorPin, output)
        end,
        MotorPinList
    ).

handle_req("GET", [], Conn) ->
    Body = [<<"
    <body>
        <h1>ESP32 Robot</h1>
        <table>
            <tr><td colspan=\"3\" align=\"center\"><button class=\"button\" onmousedown=\"toggleCheckbox('forward');\" ontouchstart=\"toggleCheckbox('forward');\" onmouseup=\"toggleCheckbox('stop');\" ontouchend=\"toggleCheckbox('stop');\">Forward</button></td></tr>
            <tr><td align=\"center\"><button class=\"button\" onmousedown=\"toggleCheckbox('left');\" ontouchstart=\"toggleCheckbox('left');\" onmouseup=\"toggleCheckbox('stop');\" ontouchend=\"toggleCheckbox('stop');\">Left</button></td><td align=\"center\"><button class=\"button\" onmousedown=\"toggleCheckbox('stop');\" ontouchstart=\"toggleCheckbox('stop');\">Stop</button></td><td align=\"center\"><button class=\"button\" onmousedown=\"toggleCheckbox('right');\" ontouchstart=\"toggleCheckbox('right');\" onmouseup=\"toggleCheckbox('stop');\" ontouchend=\"toggleCheckbox('stop');\">Right</button></td></tr>
            <tr><td colspan=\"3\" align=\"center\"><button class=\"button\" onmousedown=\"toggleCheckbox('backward');\" ontouchstart=\"toggleCheckbox('backward');\" onmouseup=\"toggleCheckbox('stop');\" ontouchend=\"toggleCheckbox('stop');\">Backward</button></td></tr>
        </table>
        <script>
        function toggleCheckbox(x) {
            var xhr = new XMLHttpRequest();
            xhr.open(\"POST\", x, true);
            xhr.send();
        }
        </script>

        <p><span id=\"textSliderValue\">%SLIDERVALUE%</span></p>
        <p><input type=\"range\" onchange=\"updateSliderPWM(this)\" id=\"pwmSlider\" min=\"0\" max=\"1023\" value=\"%SLIDERVALUE%\" step=\"1\" class=\"slider\"></p>
        <script>
            function updateSliderPWM(element) {
                var sliderValue = document.getElementById(\"pwmSlider\").value;
                document.getElementById(\"textSliderValue\").innerHTML = sliderValue;
                console.log(sliderValue);
                var xhr = new XMLHttpRequest();
                xhr.open(\"POST\", sliderValue, true);
                xhr.send();
            }
        </script>

    </body>">>],
    http_server:reply(200, Body, Conn);

handle_req("POST", ["forward"], Conn) ->
    erlang:display(forward),
    move(1, forward),
    move(2, forward),
    Body = <<"<html><body><h1>anything</h1></body></html>">>,
    http_server:reply(200, Body, Conn);

handle_req("POST", ["backward"], Conn) ->
    erlang:display(backward),
    move(1, backward),
    move(2, backward),
    Body = <<"<html><body><h1>anything</h1></body></html>">>,
    http_server:reply(200, Body, Conn);

handle_req("POST", ["right"], Conn) ->
    erlang:display(right),
    move(1, forward),
    move(2, backward),
    Body = <<"<html><body><h1>anything</h1></body></html>">>,
    http_server:reply(200, Body, Conn);

handle_req("POST", ["left"], Conn) ->
    erlang:display(left),
    move(1, backward),
    move(2, forward),
    Body = <<"<html><body><h1>anything</h1></body></html>">>,
    http_server:reply(200, Body, Conn);

handle_req("POST", ["stop"], Conn) ->
    erlang:display(stop),
    move(anything, stop),
    Body = <<"<html><body><h1>anything</h1></body></html>">>,
    http_server:reply(200, Body, Conn);

handle_req("POST", [SliderValue], Conn) ->
    SliderValueInt = safe_list_to_integer(SliderValue),
    erlang:display({slider_pwm, SliderValueInt}),
    Body = <<"<html><body><h1>anything</h1></body></html>">>,
    http_server:reply(200, Body, Conn);

handle_req(Method, Path, Conn) ->
    erlang:display(Conn),
    erlang:display({Method, Path}),
    Body = <<"<html><body><h1>Not Found</h1></body></html>">>,
    http_server:reply(200, Body, Conn).

move(1, forward) ->
    gpio:digital_write(?MOTOR_1_PIN_1, high),
    gpio:digital_write(?MOTOR_1_PIN_2, low);
move(1, backward) ->
    gpio:digital_write(?MOTOR_1_PIN_1, low),
    gpio:digital_write(?MOTOR_1_PIN_2, high);
move(2, forward) ->
    gpio:digital_write(?MOTOR_2_PIN_1, high),
    gpio:digital_write(?MOTOR_2_PIN_2, low);
move(2, backward) ->
    gpio:digital_write(?MOTOR_2_PIN_1, low),
    gpio:digital_write(?MOTOR_2_PIN_2, high);
move(_, stop) ->
    gpio:digital_write(?MOTOR_1_PIN_1, low),
    gpio:digital_write(?MOTOR_1_PIN_2, low),
    gpio:digital_write(?MOTOR_2_PIN_1, low),
    gpio:digital_write(?MOTOR_2_PIN_2, low).

safe_list_to_integer(L) ->
    try erlang:list_to_integer(L) of
        Res -> Res
    catch
        _:_ -> undefined
    end.

wait_for_message() ->
    Router = [
        {"*", ?MODULE, []}
    ],
    receive
        connected ->
            erlang:display(connected);
        {ok, IpInfo} ->
            erlang:display(IpInfo),
            http_server:start_server(8080, Router);
        disconnected ->
            erlang:display(disconnected)
    after 15000 ->
        ok
    end,
    wait_for_message().
