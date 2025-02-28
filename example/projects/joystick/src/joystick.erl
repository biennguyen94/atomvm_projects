
-module(joystick).

-export([start/0]).

-define(GPIO_VRx, 34).
-define(GPIO_VRy, 35).
-define(GPIO_SW, 32).

-define(LOW_RANGE, 700).
-define(HIGH_RANGE, 3000).

-define(DELAY_READ_ADC, 5).

start() ->
    {ADCX, ADCY} = setup_adc(),
    io:format("Init success~n"),
    loop(ADCX, ADCY).

setup_adc() ->
    ok = esp_adc:start(?GPIO_VRx),
    ok = esp_adc:start(?GPIO_VRy),    
    {?GPIO_VRx, ?GPIO_VRy}.

loop(ADCX, ADCY) ->
    {ok, X} = read_adc(ADCX),
    {ok, Y} = read_adc(ADCY),
    if
        X < ?LOW_RANGE ->
            io:format("Current position is: LEFT ~n");
        Y < ?LOW_RANGE ->
            io:format("Current position is: BOTTOM ~n");
        X > ?HIGH_RANGE ->
            io:format("Current position is: RIGHT ~n");
        Y > ?HIGH_RANGE ->
            io:format("Current position is: TOP ~n");
        true ->
            io:format("Current position is: MIDDLE ~n")
    end,
    timer:sleep(?DELAY_READ_ADC),
    loop(ADCX, ADCY).

read_adc(ADC) ->
    case esp_adc:read(ADC) of
        {ok, {Raw, _MilliVolts}} ->
            {ok, Raw};
        Error ->
            io:format("Error taking reading: ~p~n", [Error])
    end.