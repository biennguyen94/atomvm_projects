% Macro for MPU
-define(GPIO_SCL, 22).
-define(GPIO_SDA, 21).

-define(MPU9250_ADDR, 16#68).
-define(ACC_ADDR, 16#3B).
-define(TEMP_ADDR, 16#41).
-define(GYRO_ADDR, 16#43).
-define(ACC_CONFIG_ADDR, 16#1C).
-define(GYRO_CONFIG_ADDR, 16#1B).
-define(BASE_FREQ, 1000000).

% Macro for config Accelerometer
-define(ACC_FULL_SCALE_2_G, 16#00).
-define(ACC_FULL_SCALE_4_G, 16#08).
-define(ACC_FULL_SCALE_8_G, 16#10).
-define(ACC_FULL_SCALE_16_G, 16#18).

% Number of byte will read
-define(NUM_BYTE, 4).
-define(ACC_SCALE, 4.8828125e-4).         % Equal to 1/16.4
-define(RADIAN_TO_DEGREE, 57.2957795).


-define(TOP, top).
-define(BOTTOM, bot).
-define(LEFT, left).
-define(RIGHT, right).
-define(MIDDLE, mid).
-define(MAX_ROW, 15).

-define(YES, 1).
-define(NO, -1).

-record(state, {spi, data1, data2, predata1, predata2, direction, isstop, timer}).

% Macro for Led Matrix

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

-define(LED0, 0).
-define(LED1, 1).

-define(SPISettings, [
    {bus_config, [
        {miso, 19},
        {mosi, 27},
        {sclk, 5}
    ]},
    {device_config, [
        {device_1, [
            {clock_speed_hz, 1000000},
            {mode, 0},
            {cs, 18},
            {address_len_bits, 8}
        ]},
        {device_2, [
            {clock_speed_hz, 1000000},
            {mode, 0},
            {cs, 23},
            {address_len_bits, 8}
        ]}
    ]}
]).

-define(NUM_OF_BITS, 8).

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

-define(DEFAULT_MATRIX, #{
                        ?DIGIT_0 => 2#00111111,
                        ?DIGIT_1 => 2#00111111,
                        ?DIGIT_2 => 2#11111111,
                        ?DIGIT_3 => 2#11111111,
                        ?DIGIT_4 => 2#11111111,
                        ?DIGIT_5 => 2#11111111,
                        ?DIGIT_6 => 2#11111111,
                        ?DIGIT_7 => 2#11111111
                    }).