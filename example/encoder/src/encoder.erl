-module(encoder).

-export([start/0]).
-define(Motor_int1,19).
-define(Motor_int2,21).
-define(En_A,15).
-define (En_B,2).

init() ->
    gpio:set_pin_mode(?Motor_int1,output),
    gpio:set_pin_mode(?Motor_int2,output),

    gpio:set_pin_mode(?En_A,input),
    gpio:set_pin_pull(?En_A, down),

    gpio:set_pin_mode(?En_B,input),
    gpio:set_pin_pull(?En_B, down),

    GPIO = gpio:start(),
    gpio:set_int(GPIO, ?En_A, rising),
    gpio:set_int(GPIO, ?En_B, rising).

loop(Pulse) ->
    gpio:digital_write(?Motor_int1,high),
    gpio:digital_write(?Motor_int2,low),
    receive
        {gpio_interrupt,Pin} ->
            Pulse_new= Pulse+1,
            io:format("Pulse is ~p~n", [Pulse_new])
    end,
    loop(Pulse_new).

start() ->
    init(),
    Pulse = 0,
    loop(Pulse).
