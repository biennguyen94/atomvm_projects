%
% This file is part of AtomVM.
%
% Copyright 2019-2020 Bien Nguyen <nguyennhubientdh94@gmail.com>
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
%    http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%

-module(self_balancing_robot).

-include("ledc.hrl").

-export([start/0]).


% Setup MPU
-define (MPU_addr, 16#68).
-define (PWR_MGMT_1, 16#6B).

-define (ACCEL_XOUT_H, 16#3B).
-define (ACCEL_XOUT_L, 16#3C).
-define (ACCEL_YOUT_H, 16#3D).
-define (ACCEL_YOUT_L, 16#3E).
-define (ACCEL_ZOUT_H, 16#3F).
-define (ACCEL_ZOUT_L, 16#40).

-define (GYRO_XOUT_H, 16#43).
-define (GYRO_XOUT_L, 16#44).
-define (GYRO_YOUT_H, 16#45).
-define (GYRO_YOUT_L, 16#46).
-define (GYRO_ZOUT_H, 16#47).
-define (GYRO_ZOUT_L, 16#48).

-define(Ax_off, 0.0306123048).
-define(Ay_off, -0.00247998047).
-define(Az_off, 1.00272071).

-define(Gx_off, 376.86).
-define(Gy_off, 93.00).
-define(Gz_off, -92.64).

-define(RotX_Inv, 0.0076335877862595). %1/131
-define(GForce_Inv, 0.00006103515625). %1/16384

% PID
-define(Kp1, 34). %//28 //30 //26
-define(Ki1, 440). %//230//350//390
-define(Kd1, 1.182). %//1.14//1.18//1.18

-define(Setpoint, -2).
-define(MaxPID, 8192).
-define(MaxPIDNeg, -8192).


% Setup PWM
-define(LEDC_HS_TIMER, ?LEDC_TIMER_0).
-define(LEDC_HS_MODE, ?LEDC_HIGH_SPEED_MODE).
-define(LEDC_HS_CH0_GPIO, 17).
-define(LEDC_HS_CH0_CHANNEL, ?LEDC_CHANNEL_0).
-define(LEDC_HS_CH1_GPIO, 19).
-define(LEDC_HS_CH1_CHANNEL, ?LEDC_CHANNEL_1).

-define(MOTOR_1_PIN_1, 4).
-define(MOTOR_1_PIN_2, 16).
-define(MOTOR_2_PIN_1, 5).
-define(MOTOR_2_PIN_2, 18).

-define(MOTOR_1_EN, ?LEDC_HS_CH0_GPIO).
-define(MOTOR_2_EN, ?LEDC_HS_CH1_GPIO).


-define(Interval, 0.025). %25ms
-define(Interval_Inv, 40). %1/25ms

start() ->
    setup_pwm(),
    setup_motor(),
    I2C = setup_mpu(),
    timer_interupt(I2C, 0, {0, 0}).


setup_pwm() ->
    LEDCHSTimer = [
        {duty_resolution, ?LEDC_TIMER_13_BIT},
        {freq_hz, 5000},
        {speed_mode, ?LEDC_HS_MODE},
        {timer_num, ?LEDC_HS_TIMER}
    ],
    ok = ledc:timer_config(LEDCHSTimer),
    LEDCChannel = [
        [
            {channel, ?LEDC_HS_CH0_CHANNEL},
            {duty, 0},
            {gpio_num, ?MOTOR_1_EN},
            {speed_mode, ?LEDC_HS_MODE},
            {hpoint, 0},
            {timer_sel, ?LEDC_HS_TIMER}
        ],[
            {channel, ?LEDC_HS_CH1_CHANNEL},
            {duty, 0},
            {gpio_num, ?MOTOR_2_EN},
            {speed_mode, ?LEDC_HS_MODE},
            {hpoint, 0},
            {timer_sel, ?LEDC_HS_TIMER}
        ]
    ],
    lists:foreach(
        fun(ChannelConfig) ->
            ok = ledc:channel_config(ChannelConfig)
        end,
        LEDCChannel
    ).

setup_motor() ->
    MotorPinList = [?MOTOR_1_PIN_1, ?MOTOR_1_PIN_2,
        ?MOTOR_2_PIN_1, ?MOTOR_2_PIN_2],
    setup_motor(MotorPinList).

setup_motor(MotorPinList) ->
    lists:foreach(
        fun(MotorPin) ->
            gpio:set_pin_mode(MotorPin, output)
        end,
        MotorPinList
    ).

setup_mpu() ->
    I2C = i2c:open([{scl_io_num, 22}, {sda_io_num, 21}, {i2c_clock_hz, 1000000}]),
    do_setup_mpu(I2C),
    I2C.

do_setup_mpu(I2C) ->
    i2c:begin_transmission(I2C, ?MPU_addr), %Start communication with MPU6050
    i2c:write_byte(I2C, ?PWR_MGMT_1), %PWR_MGMT_1 register
    i2c:write_byte(I2C, 0), %Make reset - place a 0 into the 6B register
    i2c:end_transmission(I2C).


timer_interupt(I2C, PWM, {Pre_Error, Pre_pre_Error}) ->
    Start = erlang:timestamp(),
    receive a -> ok
    after 55 ->
        TimeDiff1 = timestamp_util:delta_ms(erlang:timestamp(), Start),
        AngleRoll_1 = angle_calculation(I2C),
        TimeDiff2 = timestamp_util:delta_ms(erlang:timestamp(), Start),
        io:format("TimeDiff1 ~p~n", [TimeDiff1]),
        io:format("TimeDiff2 ~p~n", [TimeDiff2]),
        TimeDiff3 = timestamp_util:delta_ms(erlang:timestamp(), Start),
        {PWM2, {Pre_Error_1, Pre_pre_Error_1}} =
            pid_calculation(PWM, AngleRoll_1, {Pre_Error, Pre_pre_Error}),
        TimeDiff4 = timestamp_util:delta_ms(erlang:timestamp(), Start),
        io:format("TimeDiff3 ~p~n", [TimeDiff3]),
        io:format("TimeDiff4 ~p~n", [TimeDiff4]),
        timer_interupt(I2C, PWM2, {Pre_Error_1, Pre_pre_Error_1})
    end.


move(motor1, PWM, 0) ->
    io:format("motor1 low: ~p ~n", [PWM]),
    gpio:digital_write(?MOTOR_1_PIN_1, low),
    gpio:digital_write(?MOTOR_1_PIN_2, high),
    ok = ledc:set_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL, PWM),
    ok = ledc:update_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL);
move(motor1, PWM, 1) ->
    io:format("motor1 high: ~p ~n", [PWM]),
    gpio:digital_write(?MOTOR_1_PIN_1, high),
    gpio:digital_write(?MOTOR_1_PIN_2, low),
    ok = ledc:set_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL, PWM),
    ok = ledc:update_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL);
move(motor2, PWM, 0) ->
    gpio:digital_write(?MOTOR_2_PIN_1, low),
    gpio:digital_write(?MOTOR_2_PIN_2, high),
    ok = ledc:set_duty(?LEDC_HS_MODE, ?LEDC_HS_CH1_CHANNEL, PWM),
    ok = ledc:update_duty(?LEDC_HS_MODE, ?LEDC_HS_CH1_CHANNEL);
move(motor2, PWM, 1) ->
    gpio:digital_write(?MOTOR_2_PIN_1, high),
    gpio:digital_write(?MOTOR_2_PIN_2, low),
    ok = ledc:set_duty(?LEDC_HS_MODE, ?LEDC_HS_CH1_CHANNEL, PWM),
    ok = ledc:update_duty(?LEDC_HS_MODE, ?LEDC_HS_CH1_CHANNEL);
move(stop_motor, _PWM, _Dir) ->
    io:format("motor1 stop ~n", []),
    ok = ledc:set_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL, 0),
    ok = ledc:update_duty(?LEDC_HS_MODE, ?LEDC_HS_CH0_CHANNEL),
    ok = ledc:set_duty(?LEDC_HS_MODE, ?LEDC_HS_CH1_CHANNEL, 0),
    ok = ledc:update_duty(?LEDC_HS_MODE, ?LEDC_HS_CH1_CHANNEL).

pid_calculation(PrePWM, CurrentAngle, {Pre_Error, Pre_pre_Error}) when
     (CurrentAngle > -30 andalso CurrentAngle < -10)
    or (CurrentAngle > 10 andalso CurrentAngle < 30) ->
    io:format("PrePWM: ~p ~n", [PrePWM]),
    io:format("CurrentAngle: ~p ~n", [CurrentAngle]),
    io:format("Pre_Error, Pre_pre_Error: ~p, ~p ~n", [Pre_Error, Pre_pre_Error]),
    Error = case CurrentAngle > 0 of
            true -> id(5) - id(CurrentAngle);
            false -> id(-2) - id(CurrentAngle)
        end,
    P_part = id(?Kp1)*(id(Error) - id(Pre_Error)),
    I_part = id(0.5)*id(?Ki1)*id(?Interval)*(id(Error) + id(Pre_Error)),
    D_part= id(?Kd1)*id(?Interval_Inv)*(id(Error) - id(2)*id(Pre_Error)+ id(Pre_pre_Error)),
    io:format("P_part, I_part, D_part: ~p, ~p, ~p ~n", [P_part, I_part, D_part]),
    PWM1 = id(PrePWM) + id(P_part) + id(I_part) + id(D_part),
    PWM11 = if
        (PWM1 > ?MaxPID) -> ?MaxPID;
        (PWM1 < ?MaxPIDNeg) -> ?MaxPIDNeg;
        true -> PWM1
    end,
    PWM2 = trunc(PWM11),
    if PWM2 == 0 ->
            move(stop_motor, undef, undef);
       PWM2 > 0 ->
            move(motor1, PWM2, 1),
            move(motor2, PWM2, 1);
       PWM2 < 0 ->
            move(motor1, abs(PWM2), 0),
            move(motor2, abs(PWM2), 0)
    end,
    Pre_pre_Error_1 = Pre_Error,
    Pre_Error_1 = Error,
    {PWM2, {Pre_Error_1, Pre_pre_Error_1}};
pid_calculation(PrePWM, _CurrentAngle, {Pre_Error, Pre_pre_Error}) ->
     move(stop_motor, undef, undef),
     {PrePWM, {Pre_Error, Pre_pre_Error}}.

angle_calculation(I2C) ->
    {ok, _A_x, A_y, A_z} = read_acc(I2C),
    GForcey = (id(A_y) - id(?Ay_off))*id(?GForce_Inv),
    GForcez = (id(A_z) - id(?Az_off))*id(?GForce_Inv),
    Roll = math:atan2(id(GForcey), id(GForcez)),
    Roll1 = id(Roll) * id(57.29577),
    Roll2 = filter(roll, Roll1),
    Roll2.

filter(roll, Roll) when (Roll > -30 andalso Roll < -10)
    or (Roll > 10 andalso Roll < 30) ->
    Roll;
filter(roll, _Roll) -> 0.

% === Read acceleromter data ===
read_acc(I2C) ->
    setup_acc(I2C),
    Bin = i2c:read_bytes(I2C, ?MPU_addr, 6),
    parse_bin(Bin).

setup_acc(I2C) ->
    i2c:begin_transmission(I2C, ?MPU_addr),
    i2c:write_byte(I2C, ?ACCEL_XOUT_H),
    i2c:end_transmission(I2C).


parse_bin(<<ValueX:16/integer-signed, ValueY:16/integer-signed,
    ValueZ:16/integer-signed>>) ->
    {ok, ValueX, ValueY, ValueZ}.

id(I) -> I.
