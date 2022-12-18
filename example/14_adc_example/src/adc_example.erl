-module(adc_example).

-export([start/0]).

start() ->
    Pin = 34,
    Pin2 = 35,
    {ok, ADC} = adc:start(Pin, [{attenuation, db_11},{bit_width, bit_12}]),
    {ok, ADC2} = adc:start(Pin2, [{attenuation, db_11}, {bit_width, bit_12}]),
    loop(ADC, ADC2).

loop(ADC, ADC2) ->
    case adc:read(ADC) of
        {ok, {Raw, MilliVolts}} ->
            io:format("Raw: ~p Voltage: ~pmV~n", [Raw, MilliVolts]);
        Error ->
            io:format("Error taking reading: ~p~n", [Error])
    end,
    timer:sleep(1000),
    case adc:read(ADC2) of
        {ok, {Raw2, MilliVolts2}} ->
            io:format("Raw2: ~p Voltage2: ~pmV~n", [Raw2, MilliVolts2]);
        Error2 ->
            io:format("Error taking reading: ~p~n", [Error2])
    end,
    timer:sleep(1000),
    loop(ADC, ADC2).
