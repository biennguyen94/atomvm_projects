-module(gpio_interrupt).

-export([start/0]).

% -define(OUTPUT_PIN, 2).
% -define(INPUT_PIN, 22).

% start() ->
%     case verify_platform(atomvm:platform()) of
%         ok ->

%             gpio:set_pin_mode(?INPUT_PIN, input),
%             gpio:set_pin_pull(?INPUT_PIN, down),
%             GPIO = gpio:start(),
%             gpio:set_int(GPIO, ?INPUT_PIN, rising),
%             spawn(fun receive_interrupt/0),

%             gpio:set_pin_mode(?OUTPUT_PIN, output),
%             loop(?OUTPUT_PIN, low);
%         Error ->
%             Error
%     end.

% loop(Pin, Level) ->
%     io:format("Setting pin ~p ~p~n", [Pin, Level]),
%     gpio:digital_write(Pin, Level),
%     timer:sleep(1000),
%     loop(
%         Pin,
%         case Level of
%             low -> high;
%             high -> low
%         end
%     ).

% receive_interrupt() ->
%     io:format("Waiting for interrupt ... "),
%     receive
%         {gpio_interrupt, Pin} ->
%             io:format("Interrupt on pin ~p~n", [Pin]);
%         X -> erlang:display(X)
%     end,
%     receive_interrupt().

% verify_platform(esp32) ->
%     ok;
% verify_platform(stm32) ->
%     ok;
% verify_platform(Platform) ->
%     {error, {unsupported_platform, Platform}}.

-define(PIN, 2).

start() ->
    case verify_platform(atomvm:platform()) of
        ok ->
            gpio:set_pin_mode(?PIN, input),
            gpio:set_pin_pull(?PIN, down),
            GPIO = gpio:start(),
            gpio:set_int(GPIO, ?PIN, rising),
            loop();
        Error ->
            Error
    end.

loop() ->
    io:format("Waiting for interrupt ... "),
    receive
        {gpio_interrupt, Pin} ->
            io:format("Interrupt on pin ~p~n", [Pin])
    end,
    loop().

verify_platform(esp32) ->
    ok;
verify_platform(stm32) ->
    ok;
verify_platform(Platform) ->
    {error, {unsupported_platform, Platform}}.
