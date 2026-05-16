-module(car_project).
-export([start/0, handle_req/3]).

-include("ledc.hrl").

% Macro for Timer and PWM channel
-define(LEDC_HS_TIMER, ?LEDC_TIMER_0).
-define(LEDC_HS_MODE, ?LEDC_HIGH_SPEED_MODE).
-define(LEDC_HS_CH0_GPIO, 18).
-define(LEDC_HS_CH0_CHANNEL, ?LEDC_CHANNEL_0).
-define(LEDC_HS_CH1_GPIO, 13).
-define(LEDC_HS_CH1_CHANNEL, ?LEDC_CHANNEL_1).

% This macro for (2^?LEDC_TIMER_13_BIT - 1) / 100
-define(CAL_BIT_DIV_100,  81.91).
% This macro for 100 / (2^LEDC_TIMER_13_BIT - 1)
-define(CAL_100_DIV_BIT, 0.012208521548040533).

% Macro for Request
-define(FORWARD, 1).
-define(BACKWARD, 2).
-define(STOP, 3).
-define(LEFT, 4).
-define(RIGHT, 5).
-define(SETDUTY, 6).
-define(NONE, 10).

% Macro for WHEEL
-define(WHEEL_1_1, 26).
-define(WHEEL_1_2, 4).
-define(WHEEL_2_1, 16).
-define(WHEEL_2_2, 17).
-define(WHEEL_3_1, 19).
-define(WHEEL_3_2, 21).
-define(WHEEL_4_1, 22).
-define(WHEEL_4_2, 23).

% Macro for LED GPIO 2
-define(LED, 2).

-define(PWM_1, 50).
-define(PWM_2, 50).

-define(PWM_LOW, 50).

start() ->
    % Setup peripheral
    init_peripheral(),
    % Setup PWM
    LEDCHSTimer = [
        {duty_resolution, ?LEDC_TIMER_13_BIT},
        {freq_hz, 3000},
        {speed_mode, ?LEDC_HS_MODE},
        {timer_num, ?LEDC_HS_TIMER}
    ],
    ok = ledc:timer_config(LEDCHSTimer),
    LEDCChannel_1 = [
                {channel, ?LEDC_HS_CH0_CHANNEL},
                {duty, 0},
                {gpio_num, ?LEDC_HS_CH0_GPIO},
                {speed_mode, ?LEDC_HS_MODE},
                {hpoint, 0},
                {timer_sel, ?LEDC_HS_TIMER}
            ],
    LEDCChannel_2 = [
                {channel, ?LEDC_HS_CH1_CHANNEL},
                {duty, 0},
                {gpio_num, ?LEDC_HS_CH1_GPIO},
                {speed_mode, ?LEDC_HS_MODE},
                {hpoint, 0},
                {timer_sel, ?LEDC_HS_TIMER}
            ],
    ok = ledc:channel_config(LEDCChannel_1),
    ok = ledc:channel_config(LEDCChannel_2),
    ok = ledc:fade_func_install(0),
    set_duty_channel_1(?PWM_1),
    set_duty_channel_2(?PWM_2),

    % Setup HTTP server
    ok = maybe_start_network(atomvm:platform()),
    Router = [
        {"*", ?MODULE, []}
    ],
    Port = maps:get(port, config:get()),
    http_server:start_server(Port, Router),
    timer:sleep(infinity).

%%%%%% PWM controll API
% Setup Duty cycle function

id(A) -> A.

set_duty_channel_1(DutyNum) ->
    SpeedMode = ?LEDC_HS_MODE,
    Channel = ?LEDC_HS_CH0_CHANNEL,
    DutyNoneRound = id(DutyNum) * id(?CAL_BIT_DIV_100),
    Duty = round(id(DutyNoneRound)),
    ok = ledc:set_duty(SpeedMode, Channel, Duty),
    ok = ledc:update_duty(SpeedMode, Channel).

set_duty_channel_2(DutyNum) ->
    SpeedMode = ?LEDC_HS_MODE,
    Channel = ?LEDC_HS_CH1_CHANNEL,
    DutyNoneRound = id(DutyNum) * id(?CAL_BIT_DIV_100),
    Duty = round(id(DutyNoneRound)),
    ok = ledc:set_duty(SpeedMode, Channel, Duty),
    ok = ledc:update_duty(SpeedMode, Channel).

get_duty_channel_1() ->
    SpeedMode = ?LEDC_HS_MODE,
    Channel = ?LEDC_HS_CH0_CHANNEL,
    Duty = ledc:get_duty(SpeedMode, Channel),
    DutyNoneRound = id(Duty) * id(?CAL_100_DIV_BIT),
    round(id(DutyNoneRound)).

get_duty_channel_2() ->
    SpeedMode = ?LEDC_HS_MODE,
    Channel = ?LEDC_HS_CH1_CHANNEL,
    Duty = ledc:get_duty(SpeedMode, Channel),
    DutyNoneRound = id(Duty) * id(?CAL_100_DIV_BIT),
    round(id(DutyNoneRound)).

%%%%%%% HTTP Request Handler

% Handle HTTP init Request
handle_req("GET", [], Conn) ->
    Body = get_HTML(?STOP, 50),
    http_server:reply(200, Body, Conn);

% Hande set Duty request
handle_req("POST", [], Conn) ->
    io:format("Duty ~n"),
    ParamsBody = proplists:get_value(body_chunk, Conn),
    Params = http_server:parse_query_string(ParamsBody),

    DutyCycle = proplists:get_value("duty", Params),
    DutyNum = safe_list_to_integer(DutyCycle),

    set_duty_channel_1(DutyNum),
    set_duty_channel_2(DutyNum),

    Body = get_HTML(?SETDUTY, DutyNum),
    http_server:reply(200, Body, Conn);

% Handle Forward request
handle_req("POST", ["forward"], Conn) ->
    CurrentDuty = get_duty_channel_1(),
    io:format("forward ~p ~n", [CurrentDuty]),
    car_forward(),
    Body = get_HTML(?FORWARD, CurrentDuty),
    http_server:reply(200, Body, Conn);

% % Handle Backward request
handle_req("POST", ["backward"], Conn) ->
    io:format("backward ~n"),
    CurrentDuty = get_duty_channel_1(),
    car_backward(),
    Body = get_HTML(?BACKWARD, CurrentDuty),
    http_server:reply(200, Body, Conn);

% % % Handle Stop request
handle_req("POST", ["stop"], Conn) ->
    io:format("stop ~n"),
    CurrentDuty = get_duty_channel_1(),
    car_stop(),
    Body = get_HTML(?STOP, CurrentDuty),
    http_server:reply(200, Body, Conn);

% % Handle Go left request
handle_req("POST", ["left"], Conn) ->
    io:format("left ~n"),
    CurrentDuty = get_duty_channel_1(),
    car_go_left(),
    Body = get_HTML(?LEFT, CurrentDuty),
    http_server:reply(200, Body, Conn);

% % Handle go right request
handle_req("POST", ["right"], Conn) ->
    io:format("right ~n"),
    CurrentDuty = get_duty_channel_1(),
    car_go_right(),
    Body = get_HTML(?RIGHT, CurrentDuty),
    http_server:reply(200, Body, Conn);

handle_req(_Method, ["north-west"], Conn) ->
    CurrentDuty = get_duty_channel_1(),
    car_diagonal_left_forward(),
    Body = get_HTML(?NONE, CurrentDuty),
    http_server:reply(200, Body, Conn);

handle_req("POST", ["north-east"], Conn) ->
    CurrentDuty = get_duty_channel_1(),
    car_diagonal_right_forward(),
    Body = get_HTML(?NONE, CurrentDuty),
    http_server:reply(200, Body, Conn);

% Handle error request
handle_req(Method, Path, Conn) ->
    erlang:display(Conn),
    erlang:display({Method, Path}),
    Body = <<"<html><body><h1>Not Found</h1></body></html>">>,
    http_server:reply(404, Body, Conn).

%%%% Setup HTTP Server function

safe_list_to_integer(L) ->
    try erlang:list_to_integer(L) of
        Res -> Res
    catch
        _:_ -> undefined
    end.

to_string({A, B, C, D}) ->
    io_lib:format("~p.~p.~p.~p", [A, B, C, D]);
to_string({Address, Port}) ->
    io_lib:format("~s:~p", [to_string(Address), Port]).

maybe_start_network(esp32) ->
    Config = maps:get(sta, config:get()),
    case network:wait_for_sta(Config, 30000) of
        {ok, {Address, Netmask, Gateway}} ->
            io:format(
                "Acquired IP address: ~p Netmask: ~p Gateway: ~p~n",
                [to_string(Address), to_string(Netmask), to_string(Gateway)]
            ),
            gpio:digital_write(?LED , high),
            ok;
        Error ->
            io:format("An error occurred starting network: ~p~n", [Error]),
            Error
    end;
maybe_start_network(_Platform) ->
    ok.

%%%% Peripheral controll and setup

init_peripheral() ->
    List = [?WHEEL_1_1, ?WHEEL_1_2, ?WHEEL_2_1, ?WHEEL_2_2,
            ?WHEEL_3_1, ?WHEEL_3_2, ?WHEEL_4_1, ?WHEEL_4_2, ?LED],
    lists:foreach(fun(GPIO) -> gpio:set_pin_mode(GPIO, output) end, List),
    car_stop().

write_wheel_1(Status1, Status2) ->
    gpio:digital_write(?WHEEL_1_1 , Status1),
    gpio:digital_write(?WHEEL_1_2, Status2).

write_wheel_2(Status1, Status2) ->
    gpio:digital_write(?WHEEL_2_1 , Status1),
    gpio:digital_write(?WHEEL_2_2, Status2).

write_wheel_3(Status1, Status2) ->
    gpio:digital_write(?WHEEL_3_1 , Status1),
    gpio:digital_write(?WHEEL_3_2, Status2).

write_wheel_4(Status1, Status2) ->
    gpio:digital_write(?WHEEL_4_1 , Status1),
    gpio:digital_write(?WHEEL_4_2, Status2).

%%% Car controll API

car_stop() ->
    car_reset_pwm(),
    write_wheel_1(low, low),
    write_wheel_2(low, low),
    write_wheel_3(low, low),
    write_wheel_4(low, low).

car_forward() ->
    write_wheel_1(low, high),
    write_wheel_2(low, high),
    write_wheel_3(low, high),
    write_wheel_4(low, high).

car_backward() ->
    write_wheel_1(high, low),
    write_wheel_2(high, low),
    write_wheel_3(high, low),
    write_wheel_4(high, low).

% PWM channel 1 will faster than channel 2
car_go_left() ->
    set_duty_channel_2(?PWM_LOW),
    car_forward().

% PWM channel 2 will faster than channel 1
car_go_right() ->
    set_duty_channel_1(?PWM_LOW),
    car_forward().

car_reset_pwm() ->
    DutyChannel1 = get_duty_channel_1(),
    DutyChannel2 = get_duty_channel_2(),
    case DutyChannel1 > DutyChannel2 of
        true ->
            set_duty_channel_2(DutyChannel1);
        false ->
            set_duty_channel_1(DutyChannel2)
    end.

car_diagonal_right_forward() ->
    car_go_right(),
    timer:sleep(300),
    car_reset_pwm(),
    car_forward().

car_diagonal_left_forward() ->
    car_go_left(),
    timer:sleep(300),
    car_reset_pwm(),
    car_forward().

% Get HTML content
get_HTML(Request, Duty) ->
    [<<"
        <!DOCTYPE html>
        <html lang=\"en\">
        <head>
            <meta charset=\"UTF-8\" />
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />
            <meta http-equiv=\"X-UA-Compatible\" content=\"ie=edge\" />
            <title>ESP32 Webserver</title>
            <style type=\"text/css\">
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
                -webkit-user-select: none;
                -khtml-user-select: none;
                -moz-user-select: none;
                -ms-user-select: none;
                -o-user-select: none;
                user-select: none;
            }
            h2 {
                padding: 0;
                margin: 0;
            }
            body {
                display: flex;
                width: 100vw;
                background-color: #efefef;
                flex-direction: column;
            }
            .main-title {
                text-align: center;
                margin-top: 24px;
                color: #262626;
            }
            .wrapper {
                margin: auto;
                background-color: #fff;
                box-shadow: 0 0px 4px -2px #000;
                border-radius: 8px;
                overflow: hidden;
                margin-top: 24px;
            }
            .form {
                margin: auto;
                padding: 24px;
                background-color: #fff;
            }
            .form-header {
                text-align: center;
                margin-bottom: 12px;
            }
            .form-body {
                margin-bottom: 12px;
            }
            .form-body .form-group {
                text-align: center;
            }
            .form-body .form-group input {
                position: relative;
                width: 90%;
                margin-top: 12px;
            }
            .form-footer {
                padding-top: 12px;
                text-align: center;
            }
            .form-footer .form-btn {
                background-color: cornflowerblue;
            }
            #duty::before {
                display: block;
                content: \"0\";
                width: 12px;
                height: 12px;
                position: absolute;
                left: 0;
                top: 100%;
            }
            #duty::after {
                display: block;
                content: \"100\";
                width: 12px;
                height: 12px;
                position: absolute;
                right: 0;
                top: 100%;
            }

            /* Additional CSS for the button interface */
            .button-container {
                display: flex;
                justify-content: center;
                align-items: center;
                margin-top: 24px;
            }

            .button {
                display: inline-block;
                width: 100px;
                height: 40px;
                text-align: center;
                line-height: 40px;
                border-radius: 5px;
                font-family: Arial, sans-serif;
                font-size: 14px;
                color: #fff;
                cursor: pointer;
                margin: 5px;
                background-color: cornflowerblue;
            }
            .btn {
                border: none;
                text-decoration: none;
            }

            .btn-center {
                display: flex;
                flex-direction: column;
            }

            #forward {
                background-color: #3498db;
            }

            #backward {
                background-color: #9b59b6;
            }

            #go-left {
                background-color: #ffcb0e;
            }

            #go-right {
                background-color: #2ecc71;
            }

            #stop {
                background-color: #e74c3c;
            }
            .direction {
                display: flex;
                flex-direction: column;
                align-items: center;
            }
            .direction-top {
                display: flex;
                flex-direction: row;
                flex-wrap: nowrap;
            }
            .arrow {
                font-size: 30px;
            }
            .arrow-center {
                display: flex;
                flex-direction: column;
            }
            .button.active {
                animation-name: buttonActive;
                animation-duration: 6s;
                animation-iteration-count: infinite;
            }
            @keyframes buttonActive {
                0% {
                box-shadow: 0 0 24px #3498db;
                }
                20% {
                box-shadow: 0 0 24px #ffcb0e;
                }
                40% {
                box-shadow: 0 0 24px #e74c3c;
                }
                60% {
                box-shadow: 0 0 24px #2ecc71;
                }
                80% {
                box-shadow: 0 0 24px #9b59b6;
                }
                100% {
                box-shadow: 0 0 24px #3498db;
                }
            }
            </style>
        </head>
        <body>
            <h2 class=\"main-title\">
            Car Controller
            </h2>
            <div class=\"wrapper\">
            <div class=\"button-container\">
                <div>
                <button class=\"button btn\" id=\"go-left\"
                <onmousedown=\"toggleCheckbox('left');\"
                ontouchstart=\"toggleCheckbox('left');\"
                onmouseup=\"toggleCheckbox('stop');\"
                ontouchend=\"toggleCheckbox('stop');\">
                    Go Left</button>
                </div>
                <div class=\"btn btn-center\">
                <div>
                    <button class=\"button btn\" id=\"forward\"
                    onmousedown=\"toggleCheckbox('forward');\"
                    ontouchstart=\"toggleCheckbox('forward');\"
                    onmouseup=\"toggleCheckbox('stop');\"
                    ontouchend=\"toggleCheckbox('stop');\">
                    Forward</button>
                </div>
                <div>
                    <button class=\"button btn\" id=\"stop\"
                    onmouseup=\"toggleCheckbox('stop');\"
                    ontouchend=\"toggleCheckbox('stop');\">
                    Stop</button>
                </div>
                <div>
                    <button class=\"button btn\" id=\"backward\"
                    onmousedown=\"toggleCheckbox('backward');\"
                    ontouchstart=\"toggleCheckbox('backward');\"
                    onmouseup=\"toggleCheckbox('stop');\"
                    ontouchend=\"toggleCheckbox('stop');\">
                    Backward</button>
                </div>
                </div>
                <div>
                <button class=\"button btn\" id=\"go-right\"
                onmousedown=\"toggleCheckbox('right');\"
                ontouchstart=\"toggleCheckbox('right');\"
                onmouseup=\"toggleCheckbox('stop');\"
                ontouchend=\"toggleCheckbox('stop');\">
                Go Right</button>
                </div>
            </div>
            <br />
            <!-- Start Direction -->
            <div class=\"direction\">
                <div class=\"direction-top\">
                <button class=\"button btn arrow\" id=\"north-west\"
                    onmousedown=\"toggleCheckbox('north-west');\"
                    ontouchstart=\"toggleCheckbox('north-west');\"><span>&nwarr;</span>
                </button>
                <button class=\"button btn arrow\" id=\"
                    onmousedown=\"toggleCheckbox('forward');\"
                    ontouchstart=\"toggleCheckbox('forward');\">
                    <span>&uarr;</span>
                </button>
                <button class=\"button btn arrow\" id=\"
                    onmousedown=\"toggleCheckbox('north-east');\"
                    ontouchstart=\"toggleCheckbox('north-east');\">
                    <span>&nearr;</span>
                </button>
                </div>
                <button class=\"button btn arrow\" id=\"
                onmousedown=\"toggleCheckbox('backward');\"
                ontouchstart=\"toggleCheckbox('backward');\">
                <span>&darr;<span>
                </button>
            </div>
            <!-- End Direction -->
            <form action=\"#\" method=\"POST\" class=\"form\">
                <div class=\"form-header\">
                </div>
                <div class=\"form-body\">
                <div class=\"form-group\">
                    <label for=\"duty\"
                    >Current Duty Cycle:
                    <output id=\"dutyoutput\" name=\"dutyoutput\">50</output>%
                    </label>
                    <br />
                    <input
                    id=\"duty\"
                    type=\"range\"
                    name=\"duty\"
                    min=\"0\"
                    max=\"100\"
                    step=\"1\"
                    oninput=\"dutyoutput.value=duty.value\"
                    />
                </div>
                </div>
                <div class=\"form-footer\">
                <button type=\"submit\" class=\"button\">Save</button>
                </div>
            </form>
            </div>
        </body>
        <script>
            let Duty = \"">>, Duty ,<<"\".charCodeAt(0);
            let Request = \"">>, Request ,<<"\".charCodeAt(0);
            if(Duty > 100) Duty = 0;
            document.getElementById(\"duty\").value = Duty;
            document.getElementById(\"dutyoutput\").innerHTML = Duty;

            function toggleCheckbox(x) {
                var xhr = new XMLHttpRequest();
                xhr.open(\"POST\", x, true);
                xhr.send();
            }
        </script>
    </html>
    ">>].