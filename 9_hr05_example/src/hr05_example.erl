-module(hr05_example).
-export([start/0]).

-define(TRIG, 2).
-define(ECHO, 3).

start() ->
    gpio:set_pin_mode(?TRIG, output),
    gpio:set_pin_mode(?ECHO, input),
    timer:sleep(2),
    loop().

loop() ->
    trigger_pin_setup(),
    SensorTime = read_echo_time(0),
    Distance = SensorTime * 0.034/2,
    io:format("Distance: ~p~n", [Distance]),
    timer:sleep(3000),
    loop().


trigger_pin_setup() ->
    gpio:digital_write(?TRIG, low),
    usleep(2),
    gpio:digital_write(?TRIG, high),
    usleep(10),
    gpio:digital_write(?TRIG, low).

read_echo_time(0) ->
    LocalTime = do_read_echo_time(0),
    read_echo_time(LocalTime);
read_echo_time(LocalTime) ->
    LocalTime.

do_read_echo_time(LocalTime) ->
    case gpio:digital_read(?ECHO) == high of
        true ->
            usleep(1),
            do_read_echo_time(LocalTime+1);
        _ ->
            LocalTime
    end.

usleep(Time) when is_integer(Time) andalso Time >= 0 ->
    do_usleep(Time),
    receive
        sleep_done -> ok
    end.
do_usleep(Time) ->
    MonotonicTime = erlang:monotonic_time(microsecond),
    do_usleep(MonotonicTime, Time).

do_usleep(Start, Time) ->
    case erlang:monotonic_time(microsecond) - Start >= Time of
        true ->
            self() ! sleep_done;
        _ ->
            do_usleep(Start, Time)
    end.
