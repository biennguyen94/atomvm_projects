-module(control_led).

-export([start/0, handle_req/3]).
-define(PIN, 2).

start() ->
    init_led(),
    ok = maybe_start_network(atomvm:platform()),
    Router = [
        {"*", ?MODULE, []}
    ],
    Port = maps:get(port, config:get()),
    http_server:start_server(Port, Router),
    timer:sleep(infinity).


handle_req("GET", [], Conn) ->
    Button = [<<"<p><a href=\"/?led=on\"><button class=\"button button2\">OFF</button></a></p">>],
    Body = get_HTML(Button),
    http_server:reply(200, Body, Conn);

handle_req("GET", ["?led=on"], Conn) ->
    set_led_level(?PIN, high),
    Button = [<<"<p><a href=\"/?led=off\"><button class=\"button\">ON</button></a></p">>],
    Body = get_HTML(Button),
    http_server:reply(200, Body, Conn);

handle_req(_Method, ["?led=off"], Conn) ->
    set_led_level(?PIN, low),
    Button = [<<"<p><a href=\"/?led=on\"><button class=\"button button2\">OFF</button></a></p">>],
    Body = get_HTML(Button),
    http_server:reply(200, Body, Conn);

handle_req(Method, Path, Conn) ->
    io:format("Method: ~p Path: ~p~n", [Method, Path]),
    Body = <<"<html><body><h1>Not Found</h1></body></html>">>,
    http_server:reply(404, Body, Conn).


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
get_HTML(Button) ->
    [<<"
        <html>
            <head>
                <title>ESP Web Server</title>
                <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
                <link rel=\"icon\" href=\"data:,\">
                <style>
                    html{font-family: Helvetica; display:inline-block; margin: 0px auto; text-align: center;}
                    h1{color: #0F3376; padding: 2vh;}
                    p{font-size: 1.5rem;}
                    .button {
                        display: inline-block;
                        width: 200px;
                        background-color: green;
                        border: none;
                        border-radius: 4px;
                        color: white;
                        padding: 16px 40px;
                        text-decoration: none;
                        font-size: 30px;
                        margin: 2px;
                        cursor: pointer;
                    }
                    .button2 {background-color: red;}
                </style>
            </head>
            <body>
                <h1>ESP32 Web Server</h1>
                <p>with Erlang and AtomVM</p>">>,
            Button,
            <<"
            </body>
        </html>
    ">>].

% Device controll

% Init peripheral
init_led() ->
    io:format("Init led ~n"),
    gpio:set_pin_mode(?PIN, output),
    gpio:digital_write(?PIN, low).
% Controll led
set_led_level(Pin, Level) ->
    io:format("Setting pin ~p ~p~n", [Pin, Level]),
    gpio:digital_write(Pin, Level).