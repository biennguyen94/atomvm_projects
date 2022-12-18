-module(http_server_example).

-export([start/0, handle_req/3]).

start() ->
    ok = maybe_start_network(atomvm:platform()),
    Router = [
        {"*", ?MODULE, []}
    ],
    Port = maps:get(port, config:get()),
    http_server:start_server(Port, Router),
    timer:sleep(infinity).


handle_req("GET", [], Conn) ->
    Body = <<"<html><body><h1>Hello World!</h1></body></html>">>,
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
