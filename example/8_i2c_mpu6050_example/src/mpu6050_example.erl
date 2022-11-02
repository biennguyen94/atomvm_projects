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

-define (GYRO_XOUT_H, 16#43).
-define (GYRO_XOUT_L, 16#44).
-define (GYRO_YOUT_H, 16#45).
-define (GYRO_YOUT_L, 16#46).
-define (GYRO_ZOUT_H, 16#47).
-define (GYRO_ZOUT_L, 16#48).

%Note: This module is used to read the raw values (accelerometer and gyro)

start() ->
    I2C = i2c:open([{scl_io_num, 15}, {sda_io_num, 4}, {i2c_clock_hz, 1000000}]),
    setup(I2C),
    loop(I2C).

setup(I2C) ->
    i2c:begin_transmission(I2C, ?MPU_addr), %Start communication with MPU6050
    i2c:write_byte(I2C, ?PWR_MGMT_1), %PWR_MGMT_1 register
    i2c:write_byte(I2C, 0), %Make reset - place a 0 into the 6B register
    i2c:end_transmission(I2C).

loop(I2C) ->
    ValAcc = read_acc(I2C),
    ValGyro = read_gyro(I2C),
    erlang:display(ValAcc),
    erlang:display(ValGyro),
    timer:sleep(10000),
    loop(I2C).

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

parse_bin(B) ->
    ValueX = (binary:at(B, 0) bsl 8) bor binary:at(B, 1),
    ValueY = (binary:at(B, 2) bsl 8) bor binary:at(B, 3),
    ValueZ = (binary:at(B, 4) bsl 8) bor binary:at(B, 5),
    {ok, ValueX, ValueY, ValueZ}.


%   AcX=Wire.read()<<8|Wire.read();  // 0x3B (ACCEL_XOUT_H) & 0x3C (ACCEL_XOUT_L)
%   AcY=Wire.read()<<8|Wire.read();  // 0x3D (ACCEL_YOUT_H) & 0x3E (ACCEL_YOUT_L)
%   AcZ=Wire.read()<<8|Wire.read();  // 0x3F (ACCEL_ZOUT_H) & 0x40 (ACCEL_ZOUT_L)

%   Tmp=Wire.read()<<8|Wire.read();  // 0x41 (TEMP_OUT_H) & 0x42 (TEMP_OUT_L)

%   GyX=Wire.read()<<8|Wire.read();  // 0x43 (GYRO_XOUT_H) & 0x44 (GYRO_XOUT_L)
%   GyY=Wire.read()<<8|Wire.read();  // 0x45 (GYRO_YOUT_H) & 0x46 (GYRO_YOUT_L)
%   GyZ=Wire.read()<<8|Wire.read();  // 0x47 (GYRO_ZOUT_H) & 0x48 (GYRO_ZOUT_L)