-module(gpio_interrupt).
-export([start/0]).

-define(PIN, 2).

start() ->
    gpio:set_pin_mode(?PIN, input),
    gpio:set_pin_pull(?PIN, down),
    GPIO = gpio:start(),
    gpio:set_int(GPIO, ?PIN, rising),
    loop().

loop() ->
    io:format("Waiting for interrupt ... "),
    receive
        {gpio_interrupt, Pin} ->
            io:format("Interrupt on pin ~p~n", [Pin])
    end,
    loop().