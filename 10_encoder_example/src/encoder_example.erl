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

