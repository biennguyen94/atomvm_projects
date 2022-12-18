-module(blinky).
-export([start/0]).

-define(PIN, 2).

start() ->
    gpio:set_pin_mode(?PIN, output),
    loop(?PIN, low).

loop(Pin, Level) ->
    io:format("Setting pin ~p ~p~n", [Pin, Level]),
    gpio:digital_write(Pin, Level),
    timer:sleep(1000),
    loop(Pin, toggle(Level)).

toggle(high) ->
    low;
toggle(low) ->
    high.
