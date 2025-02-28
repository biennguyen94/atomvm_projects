-module(config).
-export([get/0]).
% Setup wifi SSID and Password
get() ->
    #{
        port => 1111,
        sta => [
            {ssid, esp:nvs_get_binary(atomvm, sta_ssid, <<"DEKVN-Mobile">>)},
            {psk, esp:nvs_get_binary(atomvm, sta_psk, <<"++u*1o*rebriSip!b=l4ur7vaM_sWLdE">>)}
        ]
    }.