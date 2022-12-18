% Copyright 2022 Bien Nguyen <nguyennhubientdh94@gmail.com>


-module(encoder_example).

-export([start/0]).

-define(PIN, 2).
-define(PINB, 0).
-define(Interval, 25). %25ms
-define(Interval_Inv, 40). %25ms

start() ->
    case verify_platform(atomvm:platform()) of
        ok ->
            gpio:set_pin_mode(?PIN, input),
            gpio:set_pin_pull(?PIN, up),
            % gpio:set_pin_mode(?PINB, input),
            % gpio:set_pin_pull(?PINB, up),
            GPIO = gpio:start(),
            gpio:set_direction(GPIO, ?PINB, input),
            gpio:set_pin_pull(?PINB, up),
            gpio:set_int(GPIO, ?PIN, falling),
            main();
        Error ->
            Error
    end.

main()->
    Pid= self(),
    Pid1 = spawn(fun() -> sample_time(Pid, 0) end),
    spawn(fun() -> print(Pid1) end),
    interrupt(0, 0).

print(Pid1) ->
    receive
        {velocity_value, VelocityValue} ->
            io:format("Velocity ~p~n", [VelocityValue])
    after 2000 ->
        Pid1 ! {print, self()}
    end,
    print(Pid1).

sample_time(Pid, VelocityValue) ->
    receive
        {pulse_value, NewPulse, Pulse} ->
            VelocityValueNew = calculate_velocity(NewPulse, Pulse),
            sample_time(Pid, VelocityValueNew);
        {print, From} -> From ! {velocity_value, VelocityValue}
    after 25 ->
        % io:format("sample_time, pid, self: ~p, ~p ~n", [Pid, self()]),
        Pid ! {get_pulse, self()}
    end,
    sample_time(Pid, VelocityValue).

calculate_velocity(NewPulse, Pulse) ->
    (NewPulse-Pulse)*?Interval_Inv.

interrupt(NewPulse, Pulse) ->
    % io:format("Waiting for interrupt ... "),
    receive
        {gpio_interrupt, ?PIN} ->
            io:format("Interrupt on pin ~p~n", [?PIN]),
            NewPulse2 = do_interrupt(NewPulse),
            io:format("Interrupt on pin, NewPulse2 ~p~n", [NewPulse2]),
            % From ! {init_timer, NewPulse2, NewPulse},
            interrupt(NewPulse2, NewPulse);
        {get_pulse, From} ->
            % io:format("interrupt ~n"),
            From ! {pulse_value, NewPulse, Pulse},
            interrupt(NewPulse, Pulse)
    end.

do_interrupt(Pulse) ->
    case gpio:digital_read(?PINB) of
        low -> Pulse + 1;
        high -> Pulse - 1
    end.

verify_platform(esp32) ->
    ok;
verify_platform(stm32) ->
    ok;
verify_platform(Platform) ->
    {error, {unsupported_platform, Platform}}.
