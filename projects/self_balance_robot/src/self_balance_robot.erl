-module(self_balance_robot).

-export([start/0, handle_PID/5]).

-include("ledc.hrl").

% Macro for Timer and PWM channel
-define(LEDC_HS_TIMER, ?LEDC_TIMER_0).
-define(LEDC_HS_MODE, ?LEDC_HIGH_SPEED_MODE).
-define(LEDC_HS_CH0_GPIO, 19).
-define(LEDC_HS_CH0_CHANNEL, ?LEDC_CHANNEL_0).
-define(LEDC_HS_CH1_GPIO, 18).
-define(LEDC_HS_CH1_CHANNEL, ?LEDC_CHANNEL_1).

% This macro for (2^?LEDC_TIMER_13_BIT - 1) / 100
-define(CAL_BIT_DIV_100,  81.91).
% This macro for 100 / (2^LEDC_TIMER_13_BIT - 1)
-define(CAL_100_DIV_BIT, 0.012208521548040533).

-define(ALPHA, 0.988).
-define(SAMPLE_TIME_MS, 5).
-define(SAMPLE_TIME_S, 0.01).
-define(DIV_SAMPLE_TIME_S, 100).
-define(TARGET_ANGLE, -2).

-define(GPIO_SCL, 22).
-define(GPIO_SDA, 21).
-define(GPIO_LED, 2).

-define(MOTOR_LEFT_1, 16).
-define(MOTOR_LEFT_2, 4).
-define(MOTOR_RIGHT_1, 5).
-define(MOTOR_RIGHT_2, 23).

-define(MPU9250_ADDR, 16#68).
-define(ACCEL_YOUT_H, 16#3D).
-define(ACC_CONFIG_ADDR, 16#1C).
-define(GYRO_CONFIG_ADDR, 16#1B).

-define(I2C_BASE_FREQ, 400000).

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


% Scale with config Gyro: 2000DPS and Acc: 16G
-define(TEMP_OFFSET, 0).
-define(TEMP_SENS, 0.003115264797507788). % Equal to 1/321
-define(ACC_SCALE, 6.103515625e-5).         % Equal to 1/16384
-define(GYRO_SCALE, 0.007633587786259542). % Equal to 1/131
-define(RADIAN_TO_DEGREE, 57.2957795).

% Number of byte will read
-define(NUM_OF_BYTE, 8).
-define(NUM_OF_TIMES, 200).
-define(DIV_TIMES, 0.02).

-define(ACC_OFFSET, 4.5).
-define(GYRO_OFFSET, -1.75).
-define(AY_OFF, -0.00247998047).
-define(AZ_OFF, 1.00272071).
-define(GX_OFF, 376.86).
-define(DUTY_EQUAL_ZERO, 5000).
-define(MAX_SPEED, 8191).

-record(mpu, {accy, accz, gyrox, temp}).
%-record(error, {accerror, gyroerror}).

start() ->
    erlang:system_flag(schedulers_online, 2),
    I2C = i2c_init(),
    mpu_config(I2C),
    gpio_init(),
    pwm_init(),
    % Error = #error{accerror = 0, gyroerror = 0},
    % ErrorData = read_N_times(I2C, Error, ?NUM_OF_TIMES),
    % io:format("~p~n", [ErrorData]),
    %gpio:digital_write(?GPIO_LED, high),
    process_init(I2C),
    io:format("INIT OK ~n"),
    loop().

loop() ->
    % Use for test, type code here
    receive
        {power, Power, Angle} ->
            NewPower = constrain(Power, -8191, 8191),
            DutyNoneRound = abs(NewPower),
            %Duty = map(DutyNoneRound, 0, 8191, ?DUTY_EQUAL_ZERO, 8191),

            if 
                abs(Angle) > 10 ->
                    Duty = map(DutyNoneRound, 0, 8191, 7300, 8191);
                true ->
                    Duty = map(DutyNoneRound, 0, 8191, 5000, 6000)
            end,

            io:format("Duty ~p~n", [Duty]),
            if
                abs(Angle) < 1 ->
                    set_counter_channel_1(0),
                    set_counter_channel_2(0);
                true ->
                    if 
                        NewPower =< 0 ->
                            car_backward(),
                            set_counter_channel_2(Duty),
                            set_counter_channel_1(Duty);    
                        true ->
                            car_forward(),
                            set_counter_channel_2(Duty),
                            set_counter_channel_1(Duty)
                    end
            end;
        {angle, Angle} ->
            io:format("Current Angle is: ~p ~n", [round(Angle)]);     
        {stop, Angle} ->
            io:format("Angle is: ~p ~n", [Angle]),
            car_stop(),
            set_counter_channel_1(0),
            set_counter_channel_2(0)
    end,
    loop().

% Read value from MPU 6500
read(I2C) ->
    {ok, Val} = mpu_read_data(I2C),
    % Extract bit with format <<AccY_Z:32, Temp:16, GyroX:16>>
    <<AccY:16/integer-signed, AccZ:16/integer-signed,
    Temp:16,
    GyroX:16/integer-signed>> = Val,

    AccDataY = (AccY - ?AY_OFF) * ?ACC_SCALE,
    AccDataZ = (AccZ - ?AZ_OFF) * ?ACC_SCALE,
    GyroDataX = (GyroX - ?GX_OFF) * ?GYRO_SCALE,
    TempData = get_temp_value(Temp),

    #mpu{accy = AccDataY, accz = AccDataZ, gyrox = GyroDataX, temp = TempData}.

get_temp_value(Temp) ->
    (Temp - ?TEMP_OFFSET) * ?TEMP_SENS + 21.

i2c_init() ->
    i2c:open([{scl, ?GPIO_SCL}, {sda, ?GPIO_SDA}, {clock_speed_hz, ?I2C_BASE_FREQ}]).

mpu_config(I2C) ->
    mpu_send_command(I2C, ?ACC_CONFIG_ADDR, ?ACC_FULL_SCALE_2_G),
    mpu_send_command(I2C, ?GYRO_CONFIG_ADDR, ?GYRO_FULL_SCALE_250_DPS).

mpu_send_command(I2C, Register, Command) ->
    i2c:begin_transmission(I2C, ?MPU9250_ADDR),
    i2c:write_byte(I2C, Register),
    i2c:write_byte(I2C, Command),
    i2c:end_transmission(I2C).

% Return bitstring, format: <<AccY_Z:32, Temp:16, GyroX:16>>
mpu_read_data(I2C) ->
    i2c:begin_transmission(I2C, ?MPU9250_ADDR),
    i2c:write_byte(I2C, ?ACCEL_YOUT_H),
    i2c:end_transmission(I2C),
    i2c:read_bytes(I2C, ?MPU9250_ADDR, ?NUM_OF_BYTE).


% GPIO and Car controll API Part

gpio_init() ->
    List = [?MOTOR_LEFT_1, ?MOTOR_LEFT_2, ?MOTOR_RIGHT_1, ?MOTOR_RIGHT_2, ?GPIO_LED],
    lists:foreach(fun(GPIO) -> gpio:set_pin_mode(GPIO, output) end, List),
    car_stop().

write_motor_left(Status1, Status2) ->
    gpio:digital_write(?MOTOR_LEFT_1 , Status1),
    gpio:digital_write(?MOTOR_LEFT_2, Status2).

write_motor_right(Status1, Status2) ->
    gpio:digital_write(?MOTOR_RIGHT_1 , Status1),
    gpio:digital_write(?MOTOR_RIGHT_2, Status2).    

car_stop() ->
    write_motor_left(low, low),
    write_motor_right(low, low).

car_forward() ->
    write_motor_left(low, high),
    write_motor_right(low, high).

car_backward() ->
    write_motor_left(high, low),
    write_motor_right(high, low).

% PWM Part

pwm_init() ->
    LEDCHSTimer = [
        {duty_resolution, ?LEDC_TIMER_13_BIT},
        {freq_hz, 5000},
        {speed_mode, ?LEDC_HS_MODE},
        {timer_num, ?LEDC_HS_TIMER}
    ],
    ok = ledc:timer_config(LEDCHSTimer),
    LEDCChannel_1 = [
                {channel, ?LEDC_HS_CH0_CHANNEL},
                {duty, 0},
                {gpio_num, ?LEDC_HS_CH0_GPIO},
                {speed_mode, ?LEDC_HS_MODE},
                {hpoint, 0},
                {timer_sel, ?LEDC_HS_TIMER}
            ],
    LEDCChannel_2 = [
                {channel, ?LEDC_HS_CH1_CHANNEL},
                {duty, 0},
                {gpio_num, ?LEDC_HS_CH1_GPIO},
                {speed_mode, ?LEDC_HS_MODE},
                {hpoint, 0},
                {timer_sel, ?LEDC_HS_TIMER}
            ],
    ok = ledc:channel_config(LEDCChannel_1),
    ok = ledc:channel_config(LEDCChannel_2),
    ok = ledc:fade_func_install(0).

set_counter_channel_1(DutyNum) ->
    SpeedMode = ?LEDC_HS_MODE,
    Channel = ?LEDC_HS_CH0_CHANNEL,
    Duty = round(DutyNum),
    ok = ledc:set_duty(SpeedMode, Channel, Duty),
    ok = ledc:update_duty(SpeedMode, Channel).

set_counter_channel_2(DutyNum) ->
    SpeedMode = ?LEDC_HS_MODE,
    Channel = ?LEDC_HS_CH1_CHANNEL,
    Duty = round(DutyNum),
    ok = ledc:set_duty(SpeedMode, Channel, Duty),
    ok = ledc:update_duty(SpeedMode, Channel).

% Create process to handle read sensor

process_init(I2C) ->
    spawn(?MODULE, handle_PID, [I2C, 0, 0, 0, self()]).

handle_PID(I2C, PreviousAngle, PreviousError, ErrorSum, Parrent) ->
    Data = read(I2C),

    AccY = Data#mpu.accy,
    AccZ = Data#mpu.accz,
    GyroX = Data#mpu.gyrox,
    
    AccAngle = math:atan2(AccY, AccZ) * ?RADIAN_TO_DEGREE,
    GyroAngle = GyroX * ?SAMPLE_TIME_S,
    CurrentAngle = ?ALPHA*(PreviousAngle + GyroAngle) + (1 - ?ALPHA)*(AccAngle),

    Kp = 40, Kd = 0.75, Ki = 150,
    
    Error = ?TARGET_ANGLE - CurrentAngle,
    NewErrorSum = constrain(ErrorSum + Error, -400, 400),
    %NewErrorSum = ErrorSum + Error,
    Power = Kp*(Error) + Ki*(NewErrorSum)*?SAMPLE_TIME_S + Kd*(Error-PreviousError)*?DIV_SAMPLE_TIME_S,

    case (abs(CurrentAngle) > 30) of
        true ->
            Parrent ! {stop, CurrentAngle};
        false ->
            Parrent ! {power, Power, CurrentAngle},
            %Parrent ! {angle, CurrentAngle},
            timer:sleep(1),
            handle_PID(I2C, CurrentAngle, Error, NewErrorSum, Parrent)
    end.
    
constrain(Value, Low, High) ->
    if
        Value > High ->
            High;
        Value < Low ->
            Low;
        true ->
            Value
    end. 
    

% Read value from 6500 N times and return record contain result
% read_N_times(_I2C, Data, 0) ->
%     AccError = Data#error.accerror * ?DIV_TIMES,
%     GyroError = Data#error.gyroerror * ?DIV_TIMES,
%     #error{accerror = AccError, gyroerror = GyroError};
    
% read_N_times(I2C, PreviousData, Times) ->
% 	Data = read(I2C),
%     AccError = math:atan2(Data#mpu.accy, Data#mpu.accz) * ?RADIAN_TO_DEGREE,
% 	NewData = #error{
%         accerror = AccError + PreviousData#error.accerror,
% 		gyroerror = Data#mpu.gyrox + PreviousData#error.gyroerror
% 		},
%     usleep(5),
% 	read_N_times(I2C, NewData, Times - 1).

% usleep(Time) when is_integer(Time) andalso Time >= 0 ->
%    do_usleep(Time),
%    receive
%        sleep_done ->
%            ok
%    end.
% do_usleep(Time) ->
%     UsSecs = erlang:system_time(microsecond),
%     do_usleep(UsSecs, Time).

% do_usleep(Start, Time) ->
%     UsSecs = erlang:system_time(microsecond),
%     case UsSecs - Start >= Time of
%         true ->
%             self() ! sleep_done;
%         _ ->
%             do_usleep(Start, Time)
%     end.

map(Value, InLow, InHigh, OutLow, OutHigh) ->
    Res = (Value - InLow) * (OutHigh - OutLow) / (InHigh - InLow) + OutLow,
    round(Res).