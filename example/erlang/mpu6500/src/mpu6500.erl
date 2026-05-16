-module(mpu6500).

-export([start/0, mpu_read_data/1]).

-define(GPIO_SCL, 22).
-define(GPIO_SDA, 21).

-define(MPU9250_ADDR, 16#68).
-define(ACC_ADDR, 16#3B).
-define(TEMP_ADDR, 16#41).
-define(GYRO_ADDR, 16#43).
-define(ACC_CONFIG_ADDR, 16#1C).
-define(GYRO_CONFIG_ADDR, 16#1B).
-define(BASE_FREQ, 1000000).

% Macro for config Gyro
-define(GYRO_FULL_SCALE_250_DPS, 16#00).
-define(GYRO_FULL_SCALE_500_DPS, 16#08).
-define(GYRO_FULL_SCALE_1000_DPS, 16#10).
-define(GYRO_FULL_SCALE_2000_DPS, 16#18).

% Macro for config Accelerometer
-define(ACC_FULL_SCALE_2_G, 16#00).
-define(ACC_FULL_SCALE_4_G, 16#08).
-define(ACC_FULL_SCALE_8_G, 16#10).
-define(ACC_FULL_SCALE_16_G, 16#18).

% Number of byte will read
-define(NUM_BYTE, 14).

% Scale with config Gyro: 2000DPS and Acc: 16G
-define(TEMP_OFFSET, 0).
-define(TEMP_SENS, 0.003115264797507788). % Equal to 1/321
-define(ACC_SCALE, 4.8828125e-4).         % Equal to 1/16.4
-define(GYRO_SCALE, 0.06097560975609757). % Equal to 1/2048

-define(RADIAN_TO_DEGREE, 57.2957795).

start() ->
    I2C = i2c_init(),
    mpu_config(I2C),
    read(I2C).

% Read value after 3s
read(I2C) ->
    {ok, Val} = mpu_read_data(I2C),
    % Extract bit with format <<Acc:48, Temp:16, Gyro:48>>
    <<AccX:16/integer-signed, AccY:16/integer-signed, AccZ:16/integer-signed,
    Temp:16,
    GyroX:16/integer-signed, GyroY:16/integer-signed, GyroZ:16/integer-signed>> = Val,

    TempData = get_temp_value(Temp),
    AccData = {AccX * id(?ACC_SCALE), AccY * id(?ACC_SCALE), AccZ * id(?ACC_SCALE)},
    GyroData = {GyroX * id(?GYRO_SCALE), GyroY * id(?GYRO_SCALE), GyroZ * id(?GYRO_SCALE)},

    io:format("Acc: ~p ~nTemp: ~p ~nGyro: ~p ~n~n", [AccData, TempData, GyroData]),
    timer:sleep(3000),
    read(I2C).

i2c_init() ->
    i2c:open([{scl, ?GPIO_SCL}, {sda, ?GPIO_SDA}, {clock_speed_hz, ?BASE_FREQ}]).

mpu_config(I2C) ->
    mpu_send_command(I2C, ?ACC_CONFIG_ADDR, ?ACC_FULL_SCALE_16_G),
    mpu_send_command(I2C, ?GYRO_CONFIG_ADDR, ?GYRO_FULL_SCALE_2000_DPS).

mpu_send_command(I2C, Register, Command) ->
    i2c:begin_transmission(I2C, ?MPU9250_ADDR),
    i2c:write_byte(I2C, Register),
    i2c:write_byte(I2C, Command),
    i2c:end_transmission(I2C).

% Return bitstring, format: <<Acc:48, Temp:16, Gyro:48>>
mpu_read_data(I2C) ->
    i2c:begin_transmission(I2C, ?MPU9250_ADDR),
    i2c:write_byte(I2C, ?ACC_ADDR),
    i2c:end_transmission(I2C),
    timer:sleep(20),
    i2c:read_bytes(I2C, ?MPU9250_ADDR, ?NUM_BYTE).

% Convert Temp to correct value in C degree
id(A) -> A.

get_temp_value(Temp) ->
    round((id(Temp) - (?TEMP_OFFSET)) * id(?TEMP_SENS) + id(21)).


