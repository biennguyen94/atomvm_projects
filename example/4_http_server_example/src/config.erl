-module(config).

-export([get/0]).

get() ->
    #{
        port => 8080,
        sta => [
            {ssid, "HBTBK"},
            {psk, "49494949"}
        ]
    }.
