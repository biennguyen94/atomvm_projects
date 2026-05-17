# Copyright (c) 2024 AtomVM
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This file is part of AtomVM.
#
# Copyright 2026 Bien Nguyen <nguyennhubientdh94@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

defmodule SelfBalanceRobot do
  defstruct [:accy, :accz, :gyrox, :temp]

  @ledc_high_speed_mode 0
  @ledc_low_speed_mode 1
  @ledc_timer_0 0
  @ledc_timer_1 1
  @ledc_timer_2 2
  @ledc_timer_3 3
  @ledc_channel_0 0
  @ledc_channel_1 1
  @ledc_channel_2 2
  @ledc_channel_3 3
  @ledc_channel_4 4
  @ledc_channel_5 5
  @ledc_channel_6 6
  @ledc_channel_7 7
  @ledc_timer_1_bit 1
  @ledc_timer_2_bit 2
  @ledc_timer_3_bit 3
  @ledc_timer_4_bit 4
  @ledc_timer_5_bit 5
  @ledc_timer_6_bit 6
  @ledc_timer_7_bit 7
  @ledc_timer_8_bit 8
  @ledc_timer_9_bit 9
  @ledc_timer_10_bit 10
  @ledc_timer_11_bit 11
  @ledc_timer_12_bit 12
  @ledc_timer_13_bit 13
  @ledc_timer_14_bit 14
  @ledc_timer_15_bit 15
  @ledc_timer_16_bit 16
  @ledc_timer_17_bit 17
  @ledc_timer_18_bit 18
  @ledc_timer_19_bit 19
  @ledc_timer_20_bit 20
  @ledc_fade_no_wait 0
  @ledc_fade_wait_done 1

  @ledc_hs_timer @ledc_timer_0
  @ledc_hs_mode @ledc_high_speed_mode
  @ledc_hs_ch0_gpio 19
  @ledc_hs_ch0_channel @ledc_channel_0
  @ledc_hs_ch1_gpio 18
  @ledc_hs_ch1_channel @ledc_channel_1
  @cal_bit_div_100 81.91
  @cal_100_div_bit 0.012208521548040533
  @alpha 0.988
  @sample_time_ms 5
  @sample_time_s 0.01
  @div_sample_time_s 100
  @target_angle -2
  @gpio_scl 22
  @gpio_sda 21
  @gpio_led 2
  @motor_left_1 16
  @motor_left_2 4
  @motor_right_1 5
  @motor_right_2 23
  @mpu9250_addr 0x68
  @accel_yout_h 0x3D
  @acc_config_addr 0x1C
  @gyro_config_addr 0x1B
  @i2c_base_freq 400_000
  @gyro_full_scale_250_dps 0x00
  @gyro_full_scale_2000_dps 0x18
  @acc_full_scale_16_g 0x18
  @temp_offset 0
  @temp_sens 0.003115264797507788
  @acc_scale 6.103515625e-5
  @gyro_scale 0.007633587786259542
  @radian_to_degree 57.2957795
  @num_of_byte 8
  @num_of_times 200
  @div_times 0.02
  @acc_offset 4.5
  @gyro_offset -1.75
  @ay_off -0.00247998047
  @az_off 1.00272071
  @gx_off 376.86
  @duty_equal_zero 5000
  @max_speed 8191

  def start do
    :erlang.system_flag(:schedulers_online, 2)
    i2c = i2c_init()
    mpu_config(i2c)
    gpio_init()
    pwm_init()
    process_init(i2c)
    IO.puts("INIT OK")
    loop()
  end

  defp loop do
    receive do
      {:power, power, angle} ->
        new_power = constrain(power, -8191, 8191)
        duty_none_round = abs(new_power)
        if abs(angle) > 10 do
          duty = map(duty_none_round, 0, 8191, 7300, 8191)
        else
          duty = map(duty_none_round, 0, 8191, 5000, 6000)
        end
        IO.puts("Duty #{duty}")
        if abs(angle) < 1 do
          set_counter_channel_1(0)
          set_counter_channel_2(0)
        else
          if new_power <= 0 do
            car_backward()
            set_counter_channel_2(duty)
            set_counter_channel_1(duty)
          else
            car_forward()
            set_counter_channel_2(duty)
            set_counter_channel_1(duty)
          end
        end
      {:angle, angle} ->
        IO.puts("Current Angle is: #{round(angle)}")
      {:stop, angle} ->
        IO.puts("Angle is: #{angle}")
        car_stop()
        set_counter_channel_1(0)
        set_counter_channel_2(0)
    end
    loop()
  end

  defp read(i2c) do
    {:ok, val} = mpu_read_data(i2c)
    <<accy::integer-signed-16, accz::integer-signed-16,
      temp::16, gyrox::integer-signed-16>> = val
    acc_data_y = (accy - @ay_off) * @acc_scale
    acc_data_z = (accz - @az_off) * @acc_scale
    gyro_data_x = (gyrox - @gx_off) * @gyro_scale
    temp_data = get_temp_value(temp)
    %__MODULE__{accy: acc_data_y, accz: acc_data_z, gyrox: gyro_data_x, temp: temp_data}
  end

  defp get_temp_value(temp) do
    (temp - @temp_offset) * @temp_sens + 21
  end

  defp i2c_init do
    I2C.open([scl: @gpio_scl, sda: @gpio_sda, clock_speed_hz: @i2c_base_freq])
  end

  defp mpu_config(i2c) do
    mpu_send_command(i2c, @acc_config_addr, @acc_full_scale_16_g)
    mpu_send_command(i2c, @gyro_config_addr, @gyro_full_scale_250_dps)
  end

  defp mpu_send_command(i2c, register, command) do
    I2C.begin_transmission(i2c, @mpu9250_addr)
    I2C.write_byte(i2c, register)
    I2C.write_byte(i2c, command)
    I2C.end_transmission(i2c)
  end

  defp mpu_read_data(i2c) do
    I2C.begin_transmission(i2c, @mpu9250_addr)
    I2C.write_byte(i2c, @accel_yout_h)
    I2C.end_transmission(i2c)
    I2C.read_bytes(i2c, @mpu9250_addr, @num_of_byte)
  end

  defp gpio_init do
    list = [@motor_left_1, @motor_left_2, @motor_right_1, @motor_right_2, @gpio_led]
    Enum.each(list, fn gpio -> GPIO.set_pin_mode(gpio, :output) end)
    car_stop()
  end

  defp write_motor_left(status1, status2) do
    GPIO.digital_write(@motor_left_1, status1)
    GPIO.digital_write(@motor_left_2, status2)
  end

  defp write_motor_right(status1, status2) do
    GPIO.digital_write(@motor_right_1, status1)
    GPIO.digital_write(@motor_right_2, status2)
  end

  defp car_stop do
    write_motor_left(:low, :low)
    write_motor_right(:low, :low)
  end

  defp car_forward do
    write_motor_left(:low, :high)
    write_motor_right(:low, :high)
  end

  defp car_backward do
    write_motor_left(:high, :low)
    write_motor_right(:high, :low)
  end

  defp pwm_init do
    ledc_hs_timer = [
      duty_resolution: @ledc_timer_13_bit,
      freq_hz: 5000,
      speed_mode: @ledc_hs_mode,
      timer_num: @ledc_hs_timer
    ]
    :ok = :ledc.timer_config(ledc_hs_timer)
    ledc_channel_1 = [
      channel: @ledc_hs_ch0_channel,
      duty: 0,
      gpio_num: @ledc_hs_ch0_gpio,
      speed_mode: @ledc_hs_mode,
      hpoint: 0,
      timer_sel: @ledc_hs_timer
    ]
    ledc_channel_2 = [
      channel: @ledc_hs_ch1_channel,
      duty: 0,
      gpio_num: @ledc_hs_ch1_gpio,
      speed_mode: @ledc_hs_mode,
      hpoint: 0,
      timer_sel: @ledc_hs_timer
    ]
    :ok = :ledc.channel_config(ledc_channel_1)
    :ok = :ledc.channel_config(ledc_channel_2)
    :ok = :ledc.fade_func_install(0)
  end

  defp set_counter_channel_1(duty_num) do
    speed_mode = @ledc_hs_mode
    channel = @ledc_hs_ch0_channel
    duty = round(duty_num)
    :ok = :ledc.set_duty(speed_mode, channel, duty)
    :ok = :ledc.update_duty(speed_mode, channel)
  end

  defp set_counter_channel_2(duty_num) do
    speed_mode = @ledc_hs_mode
    channel = @ledc_hs_ch1_channel
    duty = round(duty_num)
    :ok = :ledc.set_duty(speed_mode, channel, duty)
    :ok = :ledc.update_duty(speed_mode, channel)
  end

  defp process_init(i2c) do
    spawn(fn -> handle_pid(i2c, 0, 0, 0, self()) end)
  end

  def handle_pid(i2c, previous_angle, previous_error, error_sum, parent) do
    data = read(i2c)
    acc_y = data.accy
    acc_z = data.accz
    gyro_x = data.gyrox

    acc_angle = :math.atan2(acc_y, acc_z) * @radian_to_degree
    gyro_angle = gyro_x * @sample_time_s
    current_angle = @alpha * (previous_angle + gyro_angle) + (1 - @alpha) * acc_angle

    kp = 40
    kd = 0.75
    ki = 150

    error = @target_angle - current_angle
    new_error_sum = constrain(error_sum + error, -400, 400)
    power = kp * error + ki * new_error_sum * @sample_time_s + kd * (error - previous_error) * @div_sample_time_s

    case abs(current_angle) > 30 do
      true ->
        send(parent, {:stop, current_angle})
      false ->
        send(parent, {:power, power, current_angle})
        Process.sleep(1)
        handle_pid(i2c, current_angle, error, new_error_sum, parent)
    end
  end

  defp constrain(value, low, high) do
    cond do
      value > high -> high
      value < low -> low
      true -> value
    end
  end

  defp map(value, in_low, in_high, out_low, out_high) do
    res = (value - in_low) * (out_high - out_low) / (in_high - in_low) + out_low
    round(res)
  end
end
