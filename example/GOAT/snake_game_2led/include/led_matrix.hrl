% Macro for using LED Matrix and MAX7219

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

-define(GPIO_VRx, 34).
-define(GPIO_VRy, 35).
-define(GPIO_SW, 32).
-define(GPIO_RESISTOR, 33).

-define(GPIO_MISO, 19).
-define(GPIO_MOSI, 27).
-define(GPIO_SLCK, 5).
-define(GPIO_CS, 18).

-define(LOW_RANGE, 700).
-define(HIGH_RANGE, 3900).

-define(DELAY_READ_ADC, 20).
-define(MAX_SPEED, 200).
-define(MIN_SPEED, 1000).
-define(BLINK_RATE, 200).
-define(BIT_RESOLUTION, 4095).

-define(NUM_OF_BITS, 8).

-define(DEVICE_NAME, device_1).

-define(SPISettings, [
    {bus_config, [
        {miso_io_num, 19},
        {mosi_io_num, 27},
        {sclk_io_num, 5}
    ]},
    {device_config, [
        {device_1, [
            {spi_clock_hz, 1000000},
            {mode, 0},
            {spi_cs_io_num, 18},
            {address_len_bits, 8}
        ]},
        {device_2, [
            {spi_clock_hz, 1000000},
            {mode, 0},
            {spi_cs_io_num, 23},
            {address_len_bits, 8}
        ]}
    ]}
]).
% Default Snake Status
-define(LED0, 0).
-define(LED1, 1).

-define(HEAD, {?LED0, {2, 4}}).
-define(BODY, #{0 => {?LED0, {1, 4}}, 1 => {?LED0, {2,4}}}).
-define(DIRECTION, {1, 0}).
-define(SNAKE_LENGTH, 2).

-record(snake, {spi, snakehead, snakebody, snakelen, food, data1, data2, direction, gameover, goverproc}).

-define(EMPTY_MATRIX, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00000000,
                        ?DIGIT_3 => 2#00000000,
                        ?DIGIT_4 => 2#00000000,
                        ?DIGIT_5 => 2#00000000,
                        ?DIGIT_6 => 2#00000000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_0_LEFT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#01100000,
                        ?DIGIT_3 => 2#10010000,
                        ?DIGIT_4 => 2#10010000,
                        ?DIGIT_5 => 2#10010000,
                        ?DIGIT_6 => 2#01100000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_1_LEFT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#01000000,
                        ?DIGIT_3 => 2#11000000,
                        ?DIGIT_4 => 2#01000000,
                        ?DIGIT_5 => 2#01000000,
                        ?DIGIT_6 => 2#11100000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_2_LEFT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#01100000,
                        ?DIGIT_3 => 2#10010000,
                        ?DIGIT_4 => 2#00100000,
                        ?DIGIT_5 => 2#01000000,
                        ?DIGIT_6 => 2#11110000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_3_LEFT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#01100000,
                        ?DIGIT_3 => 2#10010000,
                        ?DIGIT_4 => 2#00100000,
                        ?DIGIT_5 => 2#10010000,
                        ?DIGIT_6 => 2#01100000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_4_LEFT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00010000,
                        ?DIGIT_3 => 2#00110000,
                        ?DIGIT_4 => 2#01010000,
                        ?DIGIT_5 => 2#11110000,
                        ?DIGIT_6 => 2#00010000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_5_LEFT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#11110000,
                        ?DIGIT_3 => 2#10000000,
                        ?DIGIT_4 => 2#11110000,
                        ?DIGIT_5 => 2#00010000,
                        ?DIGIT_6 => 2#11110000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_6_LEFT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#11110000,
                        ?DIGIT_3 => 2#10000000,
                        ?DIGIT_4 => 2#11110000,
                        ?DIGIT_5 => 2#10010000,
                        ?DIGIT_6 => 2#11110000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_7_LEFT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#11110000,
                        ?DIGIT_3 => 2#00010000,
                        ?DIGIT_4 => 2#00100000,
                        ?DIGIT_5 => 2#01000000,
                        ?DIGIT_6 => 2#10000000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_8_LEFT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#11110000,
                        ?DIGIT_3 => 2#10010000,
                        ?DIGIT_4 => 2#11110000,
                        ?DIGIT_5 => 2#10010000,
                        ?DIGIT_6 => 2#11110000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_9_LEFT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#11110000,
                        ?DIGIT_3 => 2#10010000,
                        ?DIGIT_4 => 2#11110000,
                        ?DIGIT_5 => 2#00010000,
                        ?DIGIT_6 => 2#11110000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_0_RIGHT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00000110,
                        ?DIGIT_3 => 2#00001001,
                        ?DIGIT_4 => 2#00001001,
                        ?DIGIT_5 => 2#00001001,
                        ?DIGIT_6 => 2#00000110,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_1_RIGHT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00000010,
                        ?DIGIT_3 => 2#00000110,
                        ?DIGIT_4 => 2#00000010,
                        ?DIGIT_5 => 2#00000010,
                        ?DIGIT_6 => 2#00000111,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_2_RIGHT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00000110,
                        ?DIGIT_3 => 2#00001001,
                        ?DIGIT_4 => 2#00000010,
                        ?DIGIT_5 => 2#00000100,
                        ?DIGIT_6 => 2#00001111,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_3_RIGHT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00000110,
                        ?DIGIT_3 => 2#00001001,
                        ?DIGIT_4 => 2#00000010,
                        ?DIGIT_5 => 2#00001001,
                        ?DIGIT_6 => 2#00000110,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_4_RIGHT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00000001,
                        ?DIGIT_3 => 2#00000011,
                        ?DIGIT_4 => 2#00000101,
                        ?DIGIT_5 => 2#00001111,
                        ?DIGIT_6 => 2#00000001,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_5_RIGHT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00001111,
                        ?DIGIT_3 => 2#00001000,
                        ?DIGIT_4 => 2#00001111,
                        ?DIGIT_5 => 2#00000001,
                        ?DIGIT_6 => 2#00001111,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_6_RIGHT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00001111,
                        ?DIGIT_3 => 2#00001000,
                        ?DIGIT_4 => 2#00001111,
                        ?DIGIT_5 => 2#00001001,
                        ?DIGIT_6 => 2#00001111,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_7_RIGHT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00001111,
                        ?DIGIT_3 => 2#00000001,
                        ?DIGIT_4 => 2#00000010,
                        ?DIGIT_5 => 2#00000100,
                        ?DIGIT_6 => 2#00001000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_8_RIGHT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00001111,
                        ?DIGIT_3 => 2#00001001,
                        ?DIGIT_4 => 2#00001111,
                        ?DIGIT_5 => 2#00001001,
                        ?DIGIT_6 => 2#00001111,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_9_RIGHT, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00001111,
                        ?DIGIT_3 => 2#00001001,
                        ?DIGIT_4 => 2#00001111,
                        ?DIGIT_5 => 2#00000001,
                        ?DIGIT_6 => 2#00001111,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_0, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00111100,
                        ?DIGIT_3 => 2#01000010,
                        ?DIGIT_4 => 2#01000010,
                        ?DIGIT_5 => 2#00111100,
                        ?DIGIT_6 => 2#00000000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_1, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#01000000,
                        ?DIGIT_3 => 2#01000010,
                        ?DIGIT_4 => 2#01111110,
                        ?DIGIT_5 => 2#01000000,
                        ?DIGIT_6 => 2#00000000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_2, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#01000100,
                        ?DIGIT_3 => 2#01100010,
                        ?DIGIT_4 => 2#01010010,
                        ?DIGIT_5 => 2#01001100,
                        ?DIGIT_6 => 2#00000000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_3, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00100100,
                        ?DIGIT_3 => 2#01000010,
                        ?DIGIT_4 => 2#01011010,
                        ?DIGIT_5 => 2#00100100,
                        ?DIGIT_6 => 2#00000000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_4, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00011000,
                        ?DIGIT_3 => 2#00010100,
                        ?DIGIT_4 => 2#01111110,
                        ?DIGIT_5 => 2#00010000,
                        ?DIGIT_6 => 2#00000000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_5, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#01001110,
                        ?DIGIT_3 => 2#01001010,
                        ?DIGIT_4 => 2#01001010,
                        ?DIGIT_5 => 2#01111010,
                        ?DIGIT_6 => 2#00000000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_6, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#01111110,
                        ?DIGIT_3 => 2#01001010,
                        ?DIGIT_4 => 2#01001010,
                        ?DIGIT_5 => 2#01111010,
                        ?DIGIT_6 => 2#00000000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_7, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#01000010,
                        ?DIGIT_3 => 2#00100010,
                        ?DIGIT_4 => 2#00010010,
                        ?DIGIT_5 => 2#00001110,
                        ?DIGIT_6 => 2#00000000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_8, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#00110100,
                        ?DIGIT_3 => 2#01001010,
                        ?DIGIT_4 => 2#01001010,
                        ?DIGIT_5 => 2#00110100,
                        ?DIGIT_6 => 2#00000000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(NUMBER_9, #{
                        ?DIGIT_0 => 2#00000000,
                        ?DIGIT_1 => 2#00000000,
                        ?DIGIT_2 => 2#01001110,
                        ?DIGIT_3 => 2#01001010,
                        ?DIGIT_4 => 2#01001010,
                        ?DIGIT_5 => 2#01111110,
                        ?DIGIT_6 => 2#00000000,
                        ?DIGIT_7 => 2#00000000
                    }).

-define(GAME_OVER, #{
                1 => 2#00111100,
                2 => 2#01000010,
                3 => 2#01001010,
                4 => 2#00111010,
                5 => 2#00001000, % G
                6 => 2#00000000,
                7 => 2#01111100,
                8 => 2#00001010,
                9 => 2#00001010,
                10 => 2#01111100, % A
                11 => 2#00000000,
                12 => 2#01111110,
                13 => 2#00000100,
                14 => 2#00001000,
                15 => 2#00000100,
                16 => 2#01111110, % M
                17 => 2#00000000,
                18 => 2#01111110,
                19 => 2#01001010,
                20 => 2#01001010,
                21 => 2#01000010, % E
                22 => 2#00000000,
                23 => 2#00000000,
                24 => 2#00111100,
                25 => 2#01000010,
                26 => 2#01000010,
                27 => 2#00111100, % O
                28 => 2#00000000,
                29 => 2#00011110,
                30 => 2#00100000,
                31 => 2#01000000,
                32 => 2#00100000,
                33 => 2#00011110, % V
                34 => 2#00000000,
                35 => 2#01111110,
                36 => 2#01001010,
                37 => 2#01001010,
                38 => 2#01000010, % E
                39 => 2#00000000,
                40 => 2#01111110,
                41 => 2#00001010,
                42 => 2#00001010,
                43 => 2#01110110, % R
                44 => 2#00000000,
                45 => 2#00000000
    }).