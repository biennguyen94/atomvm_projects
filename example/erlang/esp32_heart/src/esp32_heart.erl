-module(esp32_heart).

-export([start/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
        terminate/2, code_change/3]).

-define(NO_OP, 16#0).
-define(DIGIT_0, 16#1).
-define(DIGIT_1, 16#2).
-define(DIGIT_2, 16#3).
-define(DIGIT_3, 16#4).
-define(DIGIT_4, 16#5).
-define(DIGIT_5, 16#6).
-define(DIGIT_6, 16#7).
-define(DIGIT_7, 16#8).
-define(DECODE_MODE, 16#9).
-define(INTENSITY, 16#A).
-define(SCAN_LIMIT, 16#B).
-define(SHUTDOWN, 16#C).
-define(DISPLAY_TEST, 16#F).

-define(NUM_OF_BITS, 8).

-define(DEVICE_NAME, device_1).

-define(SPISettings, [
    {bus_config, [
        {miso, 19},
        {mosi, 27},
        {sclk, 5}
    ]},
    {device_config, [
        {?DEVICE_NAME, [
            {clock_speed_hz, 1000000},
            {mode, 0},
            {cs, 18},
            {address_len_bits, 8}
        ]}
    ]}
]).

start() ->
    {ok, P} = gen_server:start(?MODULE, [], []),
    gen_server:call(P, init).

init(_) ->
    {ok, {}}.

handle_call(init, _From, _State) ->
    {ok, SPI} = init_max7219(?SPISettings),
    io:format("Init SPI and MAX7219 OK~n"),
    display_heart(SPI),
    {reply, ok, SPI}.

handle_info(_Info, State) -> {noreply, State}.
handle_cast(_Msg, State) -> {noreply, State}.
code_change(_OldVsn, State, _Extra) -> {ok, State}.
terminate(_Reason, _State) ->
    ok.

init_max7219(SPISettings) ->
    SPI = spi:open(SPISettings),
    write_register(SPI, ?DECODE_MODE, 16#0),    % No decoding
    write_register(SPI, ?INTENSITY, 16#3),      % Brightness intensity
    write_register(SPI, ?SCAN_LIMIT, 16#7),     % Scan limit = 8 LEDs
    write_register(SPI, ?SHUTDOWN, 16#1),       % Power down = 0, Normal mode = 1
    write_register(SPI, ?DISPLAY_TEST, 16#0),   % No display Test
    {ok, SPI}.

display_heart(SPI) ->
    HeartList = [
        2#01100110,
        2#11111111,
        2#11111111,
        2#11111111,
        2#01111110,
        2#00111100,
        2#00011000,
        2#00000000
        ],
    ok = write_digit(SPI, HeartList, 1).

% Recursive to write Data from Digit 1 to 8
write_digit(SPI, [Data|_], 8) ->
    write_register(SPI, 8, Data),
    ok;
write_digit(SPI, [Data|TailList], Number) ->
    write_register(SPI, Number, Data),
    write_digit(SPI, TailList, Number + 1).

write_register(SPI, Address, Data) ->
    spi:write_at(SPI, ?DEVICE_NAME, Address, ?NUM_OF_BITS, Data).
