-module(config).
-export([get/0]).
% Setup wifi SSID and Password
get() ->
    #{
        port => 1111,
        sta => [
            {ssid, esp:nvs_get_binary(atomvm, sta_ssid, <<"wifi">>)},
            {psk, esp:nvs_get_binary(atomvm, sta_psk, <<"password">>)}
        ]
    }.