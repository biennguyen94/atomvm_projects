% Copyright 2022 Bien Nguyen <nguyennhubientdh94@gmail.com>

-module(remote_robot_web_server).

-export([start/0, handle_req/3]).

-include("ledc.hrl").

-define(MOTOR_1_PIN_1, 4).
-define(MOTOR_1_PIN_2, 16).
-define(MOTOR_1_EN, 17).

-define(MOTOR_2_PIN_1, 5).
-define(MOTOR_2_PIN_2, 18).
-define(MOTOR_2_EN, 19).

-define(LEDC_HS_MODE, ?LEDC_HIGH_SPEED_MODE).
-define(LEDC_HS_TIMER, ?LEDC_TIMER_0).
-define(LEDC_HS_CH0_CHANNEL, ?LEDC_CHANNEL_0).
-define(LEDC_HS_CH1_CHANNEL, ?LEDC_CHANNEL_1).

-define(LEDC_PWM, 6000). %half of 13bit

start() ->
    setup_pwm(),
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

setup_pwm() ->
    LEDCHSTimer = [
        {duty_resolution, ?LEDC_TIMER_13_BIT},
        {freq_hz, 5000},
        {speed_mode, ?LEDC_HS_MODE},
        {timer_num, ?LEDC_HS_TIMER}
    ],
    ok = ledc:timer_config(LEDCHSTimer),
    LEDCChannel = [
        [
            {channel, ?LEDC_HS_CH0_CHANNEL},
            {duty, 0},
            {gpio_num, ?MOTOR_1_EN},
            {speed_mode, ?LEDC_HS_MODE},
            {hpoint, 0},
            {timer_sel, ?LEDC_HS_TIMER}
        ],[
            {channel, ?LEDC_HS_CH1_CHANNEL},
            {duty, 0},
            {gpio_num, ?MOTOR_2_EN},
            {speed_mode, ?LEDC_HS_MODE},
            {hpoint, 0},
            {timer_sel, ?LEDC_HS_TIMER}
        ]
    ],
    lists:foreach(
        fun(ChannelConfig) ->
            ok = ledc:channel_config(ChannelConfig)
        end,
        LEDCChannel
    ).

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
    move(1, forward, ?LEDC_PWM),
    move(2, forward, ?LEDC_PWM),
    Body = <<"<html><body><h1>anything</h1></body></html>">>,
    http_server:reply(200, Body, Conn);

handle_req("POST", ["backward"], Conn) ->
    erlang:display(backward),
    move(1, backward, ?LEDC_PWM),
    move(2, backward, ?LEDC_PWM),
    Body = <<"<html><body><h1>anything</h1></body></html>">>,
    http_server:reply(200, Body, Conn);

handle_req("POST", ["right"], Conn) ->
    erlang:display(right),
    move(1, forward, ?LEDC_PWM),
    move(2, backward, ?LEDC_PWM),
    Body = <<"<html><body><h1>anything</h1></body></html>">>,
    http_server:reply(200, Body, Conn);

handle_req("POST", ["left"], Conn) ->
    erlang:display(left),
    move(1, backward, ?LEDC_PWM),
    move(2, forward, ?LEDC_PWM),
    Body = <<"<html><body><h1>anything</h1></body></html>">>,
    http_server:reply(200, Body, Conn);

handle_req("POST", ["stop"], Conn) ->
    erlang:display(stop),
    move(anything, stop, 0),
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

move(1, forward, PWM) ->
    gpio:digital_write(?MOTOR_1_PIN_1, high),
    gpio:digital_write(?MOTOR_1_PIN_2, low),
    ok = ledc:set_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL, PWM),
    ok = ledc:update_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL);   
move(1, backward, PWM) ->
    gpio:digital_write(?MOTOR_1_PIN_1, low),
    gpio:digital_write(?MOTOR_1_PIN_2, high),
    ok = ledc:set_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL, PWM),
    ok = ledc:update_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL);     
move(2, forward, PWM) ->
    gpio:digital_write(?MOTOR_2_PIN_1, high),
    gpio:digital_write(?MOTOR_2_PIN_2, low),
    ok = ledc:set_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL, PWM),
    ok = ledc:update_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL);     
move(2, backward, PWM) ->
    gpio:digital_write(?MOTOR_2_PIN_1, low),
    gpio:digital_write(?MOTOR_2_PIN_2, high),
    ok = ledc:set_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL, PWM),
    ok = ledc:update_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL);     
move(_, stop, _PWM) ->
    gpio:digital_write(?MOTOR_1_PIN_1, low),
    gpio:digital_write(?MOTOR_1_PIN_2, low),
    gpio:digital_write(?MOTOR_2_PIN_1, low),
    gpio:digital_write(?MOTOR_2_PIN_2, low),
    ok = ledc:set_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL, 0),
    ok = ledc:update_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL),
    ok = ledc:set_duty(?LEDC_HS_MODE, ?LEDC_HS_CH1_CHANNEL, 0),
    ok = ledc:update_duty(?LEDC_HS_MODE, ?LEDC_HS_CH1_CHANNEL).    

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
