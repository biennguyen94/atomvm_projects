-module(ledc).
-export([start/0, handle_req/3]).

-include("ledc.hrl").

% Macro for PWM
-define(LEDC_HS_TIMER, ?LEDC_TIMER_0).
-define(LEDC_HS_MODE, ?LEDC_HIGH_SPEED_MODE).
-define(LEDC_HS_CH0_GPIO, 18).
-define(LEDC_HS_CH0_CHANNEL, ?LEDC_CHANNEL_0).

start() ->
    % PWM cofiguration
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
    ok = ledc:channel_config(LEDCChannel_1),
    ok = ledc:fade_func_install(0),

    % Network setup
    ok = maybe_start_network(atomvm:platform()),
    Router = [
        {"*", ?MODULE, []}
    ],
    Port = maps:get(port, config:get()),
    http_server:start_server(Port, Router),
    timer:sleep(infinity).

% set duty cycle to specific value (%)
set_duty_channel_1(DutyNum) ->
    io:format("Set duty cycle: ~p ~n", [DutyNum]),
    SpeedMode = ?LEDC_HS_MODE,
    Channel = ?LEDC_HS_CH0_CHANNEL,
    Duty = (8191 * DutyNum div 100),
    ok = ledc:set_duty(SpeedMode, Channel, Duty),
    ok = ledc:update_duty(SpeedMode, Channel).

% Handle request from client
handle_req("GET", [], Conn) ->
    Body = get_HTML(0),
    http_server:reply(200, Body, Conn);
handle_req("POST", [], Conn) ->
    % parser message from client to get Duty value
    ParamsBody = proplists:get_value(body_chunk, Conn),
    Params = http_server:parse_query_string(ParamsBody),
    DutyCycle = proplists:get_value("duty", Params),
    DutyNum = safe_list_to_integer(DutyCycle),
    % Set duty cycle
    set_duty_channel_1(DutyNum),
    % Repply to client
    Body = get_HTML(DutyNum),
    http_server:reply(200, Body, Conn);
handle_req(Method, Path, Conn) ->
    erlang:display(Conn),
    erlang:display({Method, Path}),
    Body = <<"<html><body><h1>Not Found</h1></body></html>">>,
    http_server:reply(404, Body, Conn).

%  Setup network function
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
            ok;
        Error ->
            io:format("An error occurred starting network: ~p~n", [Error]),
            Error
    end;
maybe_start_network(_Platform) ->
    ok.

% Get HTML content
get_HTML(Duty) ->
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
            </style>
        </head>
        <body>
            <h2 class=\"main-title\">
            ESP32 - LEDC
            </h2>
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
                    step=\"5\"
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
            if(Duty > 100) Duty = 0;
            document.getElementById(\"duty\").value = Duty;
            document.getElementById(\"dutyoutput\").innerHTML = Duty;
        </script>
    </html>
    ">>].