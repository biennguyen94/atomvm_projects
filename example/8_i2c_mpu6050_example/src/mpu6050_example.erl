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

-module(mpu6050_example).

-export([start/0, read_acc/1, read_gyro/1]).

-define (MPU_addr, 16#68).
-define (PWR_MGMT_1, 16#6B).

-define (ACCEL_XOUT_H, 16#3B).
-define (ACCEL_XOUT_L, 16#3C).
-define (ACCEL_YOUT_H, 16#3D).
-define (ACCEL_YOUT_L, 16#3E).
-define (ACCEL_ZOUT_H, 16#3F).
-define (ACCEL_ZOUT_L, 16#40).

-define (TEMP_OUT_H, 16#41).
-define (TEMP_OUT_L, 16#42).

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
-define(Interval, 0.025). %25ms
-define(Interval_Calib, 0.1). %100ms


-define(Temperature_Inv, 0.00294). %1/340


%Note: This module is used to read the raw values (accelerometer and gyro)

start() ->
    I2C = i2c:open([{scl_io_num, 22}, {sda_io_num, 21}, {i2c_clock_hz, 100000}]),
    setup(I2C),
    loop(I2C).

setup(I2C) ->
    i2c:begin_transmission(I2C, ?MPU_addr), %Start communication with MPU6050
    i2c:write_byte(I2C, ?PWR_MGMT_1), %PWR_MGMT_1 register
    i2c:write_byte(I2C, 0), %Make reset - place a 0 into the 6B register
    i2c:end_transmission(I2C).

loop(I2C) ->
    % {ok, TemperatureRaw} = read_tmp(I2C),
    % Temperature = id(TemperatureRaw)*id(?Temperature_Inv) + id(21),
    % io:format("Temperature: ~p ~n", [Temperature]),
    Pid= self(),
    % spawn(fun() -> print(Pid) end),
    timer_interupt(I2C, 0).

print(Pid1) ->
    receive
        {mpu_value, AngleRoll} ->
            io:format("AngleRoll ~p~n", [AngleRoll])
    after 3000 ->
        Pid1 ! {print, self()}
    end,
    print(Pid1).

timer_interupt(I2C, 0) ->
    % timer:sleep(25),
    AngleRoll_1 = angle_calculation(I2C, 0),
    % {PWM, {Pre_Error, Pre_pre_Error}} = pid_calculation(0, 0, {0, 0}),
    timer_interupt(I2C, AngleRoll_1);
timer_interupt(I2C, AngleRoll) ->
    Start = erlang:timestamp(),
    receive
        {print, From} -> From ! {mpu_value, AngleRoll}
    after 50 ->
        TimeDiff1 = timestamp_util:delta_ms(erlang:timestamp(), Start),
        AngleRoll_1 = angle_calculation(I2C, AngleRoll),
        TimeDiff2 = timestamp_util:delta_ms(erlang:timestamp(), Start),
        io:format("TimeDiff1 ~p~n", [TimeDiff1]),
        io:format("TimeDiff2 ~p~n", [TimeDiff2]),
        timer_interupt(I2C, AngleRoll_1)
    end,
    timer_interupt(I2C, AngleRoll).


% angle_calculation(I2C, _) ->
%     {ok, A_x, A_y, A_z} = read_acc(I2C),

%     {ok, G_x, G_y, G_z} = read_gyro(I2C),

%     GForcex = (id(A_x) - id(?Ax_off))*id(?GForce_Inv),
%     GForcey = (id(A_y) - id(?Ay_off))*id(?GForce_Inv),
%     GForcez = (id(A_z) - id(?Az_off))*id(?GForce_Inv),

%     RotX = (id(G_x) - id(?Gx_off))*id(?RotX_Inv),
%     RotY = (id(G_y) - id(?Gy_off))*id(?RotX_Inv),
%     RotZ = (id(G_z) - id(?Gz_off))*id(?RotX_Inv),
%     ok.

angle_calculation(I2C, AngleRoll) ->
    {ok, _A_x, A_y, A_z} = read_acc(I2C),
    % io:format("A_y, A_z: ~p, ~p ~n", [A_y,A_z]),

    % {ok, G_x, _G_y, _G_z} = read_gyro(I2C),
    % io:format("G_x: ~p ~n", [G_x]),

    GForcey = (id(A_y) - id(?Ay_off))*id(?GForce_Inv),
    GForcez = (id(A_z) - id(?Az_off))*id(?GForce_Inv),
    % io:format("GForcey, GForcez: ~p, ~p ~n", [GForcey, GForcez]),

    % RotX = (id(G_x) - id(?Gx_off))*id(?RotX_Inv),
    % io:format("RotX: ~p ~n", [RotX]),
    % RotX2 = filter(rot, RotX),
    % io:format("RotX2: ~p ~n", [RotX2]),
    Roll = math:atan2(id(GForcey), id(GForcez)),
    % io:format("Roll: ~p ~n", [Roll]),
    Roll1 = id(Roll) * id(57.29577),
    Roll2 = filter(roll, Roll1),
    io:format("Roll2: ~p ~n", [Roll2]),
    Roll2.
    % AngleRollNew = id(0.988)*(id(AngleRoll)  + id(RotX2)*id(?Interval_Calib)) + id(0.012)*id(Roll2),
    % io:format("AngleRollNew: ~p ~n", [AngleRollNew]),
    % AngleRollNew.

% angle_calculation(_I2C, AngleRoll) -> ok.

filter(roll, Roll) when (Roll > -30 andalso Roll < -10)
    or (Roll > 10 andalso Roll < 30) ->
    Roll;
filter(roll, _Roll) -> 0.

% filter(rot, RotX) when (RotX > -100 andalso RotX < -20)
%     or  (RotX > 20 andalso RotX < 100) -> RotX;
% filter(rot, _RotX) -> 0.


% === Read acceleromter data ===
read_acc(I2C) ->
    setup_acc(I2C),
    Bin = i2c:read_bytes(I2C, ?MPU_addr, 6),
    parse_bin(Bin).

setup_acc(I2C) ->
    i2c:begin_transmission(I2C, ?MPU_addr),
    i2c:write_byte(I2C, ?ACCEL_XOUT_H),
    i2c:end_transmission(I2C).


% === Read gyroscope data ===
read_gyro(I2C) ->
    setup_gyro(I2C),
    Bin = i2c:read_bytes(I2C, ?MPU_addr, 6),
    parse_bin(Bin).

setup_gyro(I2C) ->
    i2c:begin_transmission(I2C, ?MPU_addr),
    i2c:write_byte(I2C, ?GYRO_XOUT_H),
    i2c:end_transmission(I2C).

parse_bin(<<ValueX0:8/integer-signed, ValueX1:8/integer-signed,
    ValueY0:8/integer-signed, ValueY1:8/integer-signed,
    ValueZ0:8/integer-signed, ValueZ1:8/integer-signed>>) ->
%this can be (same meaning) parse_bin(<<ValueX:16/integer-signed, ValueY:16/integer-signed, ValueZ:16/integer-signed>>) ->
    ValueX = (ValueX0 bsl 8) bor ValueX1,
    ValueY = (ValueY0 bsl 8) bor ValueY1,
    ValueZ = (ValueZ0 bsl 8) bor ValueZ1,
    {ok, ValueX, ValueY, ValueZ}.

% === Read temperature data ===
read_tmp(I2C) ->
    setup_tmp(I2C),
    Bin = i2c:read_bytes(I2C, ?MPU_addr, 2),
    parse_bin_tmp(Bin).

setup_tmp(I2C) ->
    i2c:begin_transmission(I2C, ?MPU_addr),
    i2c:write_byte(I2C, ?TEMP_OUT_H),
    i2c:end_transmission(I2C).

parse_bin_tmp(B) ->
    ValueX = (binary:at(B, 0) bsl 8) bor binary:at(B, 1),
    {ok, ValueX}.

id(I) -> I.

%   AcX=Wire.read()<<8|Wire.read();  // 0x3B (ACCEL_XOUT_H) & 0x3C (ACCEL_XOUT_L)
%   AcY=Wire.read()<<8|Wire.read();  // 0x3D (ACCEL_YOUT_H) & 0x3E (ACCEL_YOUT_L)
%   AcZ=Wire.read()<<8|Wire.read();  // 0x3F (ACCEL_ZOUT_H) & 0x40 (ACCEL_ZOUT_L)

%   Tmp=Wire.read()<<8|Wire.read();  // 0x41 (TEMP_OUT_H) & 0x42 (TEMP_OUT_L)

%   GyX=Wire.read()<<8|Wire.read();  // 0x43 (GYRO_XOUT_H) & 0x44 (GYRO_XOUT_L)
%   GyY=Wire.read()<<8|Wire.read();  // 0x45 (GYRO_YOUT_H) & 0x46 (GYRO_YOUT_L)
%   GyZ=Wire.read()<<8|Wire.read();  // 0x47 (GYRO_ZOUT_H) & 0x48 (GYRO_ZOUT_L)