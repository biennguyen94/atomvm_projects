-module(hello_world).
-export([start/0]).

start() ->
    loop().
loop() ->
    io:format("Hello World~n"),
    timer:sleep(1000),
    loop().
