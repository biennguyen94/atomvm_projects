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

defmodule CarProject do
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
  @ledc_hs_ch0_gpio 18
  @ledc_hs_ch0_channel @ledc_channel_0
  @ledc_hs_ch1_gpio 13
  @ledc_hs_ch1_channel @ledc_channel_1
  @cal_bit_div_100 81.91
  @cal_100_div_bit 0.012208521548040533
  @forward 1
  @backward 2
  @stop 3
  @left 4
  @right 5
  @setduty 6
  @none 10
  @wheel_1_1 26
  @wheel_1_2 4
  @wheel_2_1 16
  @wheel_2_2 17
  @wheel_3_1 19
  @wheel_3_2 21
  @wheel_4_1 22
  @wheel_4_2 23
  @led 2
  @pwm_1 50
  @pwm_2 50
  @pwm_low 50

  def start do
    init_peripheral()
    ledc_hs_timer = [
      duty_resolution: @ledc_timer_13_bit,
      freq_hz: 3000,
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
    set_duty_channel_1(@pwm_1)
    set_duty_channel_2(@pwm_2)

    :ok = maybe_start_network(:atomvm.platform())
    router = [{"*", __MODULE__, []}]
    port = Config.get() |> Map.get(:port)
    :http_server.start_server(port, router)
    Process.sleep(:infinity)
  end

  defp id(a), do: a

  defp set_duty_channel_1(duty_num) do
    speed_mode = @ledc_hs_mode
    channel = @ledc_hs_ch0_channel
    duty_none_round = id(duty_num) * id(@cal_bit_div_100)
    duty = round(id(duty_none_round))
    :ok = :ledc.set_duty(speed_mode, channel, duty)
    :ok = :ledc.update_duty(speed_mode, channel)
  end

  defp set_duty_channel_2(duty_num) do
    speed_mode = @ledc_hs_mode
    channel = @ledc_hs_ch1_channel
    duty_none_round = id(duty_num) * id(@cal_bit_div_100)
    duty = round(id(duty_none_round))
    :ok = :ledc.set_duty(speed_mode, channel, duty)
    :ok = :ledc.update_duty(speed_mode, channel)
  end

  defp get_duty_channel_1 do
    speed_mode = @ledc_hs_mode
    channel = @ledc_hs_ch0_channel
    duty = :ledc.get_duty(speed_mode, channel)
    duty_none_round = id(duty) * id(@cal_100_div_bit)
    round(id(duty_none_round))
  end

  defp get_duty_channel_2 do
    speed_mode = @ledc_hs_mode
    channel = @ledc_hs_ch1_channel
    duty = :ledc.get_duty(speed_mode, channel)
    duty_none_round = id(duty) * id(@cal_100_div_bit)
    round(id(duty_none_round))
  end

  def handle_req("GET", [], conn) do
    body = get_html(@stop, 50)
    :http_server.reply(200, body, conn)
  end

  def handle_req("POST", [], conn) do
    IO.puts("Duty")
    params_body = Keyword.get(conn, :body_chunk)
    params = :http_server.parse_query_string(params_body)
    duty_cycle = Keyword.get(params, "duty")
    duty_num = safe_string_to_integer(duty_cycle)
    set_duty_channel_1(duty_num)
    set_duty_channel_2(duty_num)
    body = get_html(@setduty, duty_num)
    :http_server.reply(200, body, conn)
  end

  def handle_req("POST", ["forward"], conn) do
    current_duty = get_duty_channel_1()
    IO.puts("forward #{inspect(current_duty)}")
    car_forward()
    body = get_html(@forward, current_duty)
    :http_server.reply(200, body, conn)
  end

  def handle_req("POST", ["backward"], conn) do
    IO.puts("backward")
    current_duty = get_duty_channel_1()
    car_backward()
    body = get_html(@backward, current_duty)
    :http_server.reply(200, body, conn)
  end

  def handle_req("POST", ["stop"], conn) do
    IO.puts("stop")
    current_duty = get_duty_channel_1()
    car_stop()
    body = get_html(@stop, current_duty)
    :http_server.reply(200, body, conn)
  end

  def handle_req("POST", ["left"], conn) do
    IO.puts("left")
    current_duty = get_duty_channel_1()
    car_go_left()
    body = get_html(@left, current_duty)
    :http_server.reply(200, body, conn)
  end

  def handle_req("POST", ["right"], conn) do
    IO.puts("right")
    current_duty = get_duty_channel_1()
    car_go_right()
    body = get_html(@right, current_duty)
    :http_server.reply(200, body, conn)
  end

  def handle_req(_method, ["north-west"], conn) do
    current_duty = get_duty_channel_1()
    car_diagonal_left_forward()
    body = get_html(@none, current_duty)
    :http_server.reply(200, body, conn)
  end

  def handle_req("POST", ["north-east"], conn) do
    current_duty = get_duty_channel_1()
    car_diagonal_right_forward()
    body = get_html(@none, current_duty)
    :http_server.reply(200, body, conn)
  end

  def handle_req(method, path, conn) do
    IO.inspect(conn)
    IO.inspect({method, path})
    body = ~s|<html><body><h1>Not Found</h1></body></html>|
    :http_server.reply(404, body, conn)
  end

  defp safe_string_to_integer(l) do
    String.to_integer(l)
  rescue
    _ -> nil
  end

  defp to_string({a, b, c, d}) do
    :io_lib.format("~p.~p.~p.~p", [a, b, c, d])
  end

  defp to_string({address, port}) do
    :io_lib.format("~s:~p", [to_string(address), port])
  end

  defp maybe_start_network(:esp32) do
    config = Config.get() |> Map.get(:sta)
    case :network.wait_for_sta(config, 30000) do
      {:ok, {address, netmask, gateway}} ->
        IO.puts(
          :io_lib.format(
            "Acquired IP address: ~p Netmask: ~p Gateway: ~p~n",
            [to_string(address), to_string(netmask), to_string(gateway)]
          )
        )
        GPIO.digital_write(@led, :high)
        :ok
      error ->
        IO.puts(:io_lib.format("An error occurred starting network: ~p~n", [error]))
        error
    end
  end

  defp maybe_start_network(_platform), do: :ok

  defp init_peripheral do
    list = [@wheel_1_1, @wheel_1_2, @wheel_2_1, @wheel_2_2,
            @wheel_3_1, @wheel_3_2, @wheel_4_1, @wheel_4_2, @led]
    Enum.each(list, fn gpio -> GPIO.set_pin_mode(gpio, :output) end)
    car_stop()
  end

  defp write_wheel_1(status1, status2) do
    GPIO.digital_write(@wheel_1_1, status1)
    GPIO.digital_write(@wheel_1_2, status2)
  end

  defp write_wheel_2(status1, status2) do
    GPIO.digital_write(@wheel_2_1, status1)
    GPIO.digital_write(@wheel_2_2, status2)
  end

  defp write_wheel_3(status1, status2) do
    GPIO.digital_write(@wheel_3_1, status1)
    GPIO.digital_write(@wheel_3_2, status2)
  end

  defp write_wheel_4(status1, status2) do
    GPIO.digital_write(@wheel_4_1, status1)
    GPIO.digital_write(@wheel_4_2, status2)
  end

  defp car_stop do
    car_reset_pwm()
    write_wheel_1(:low, :low)
    write_wheel_2(:low, :low)
    write_wheel_3(:low, :low)
    write_wheel_4(:low, :low)
  end

  defp car_forward do
    write_wheel_1(:low, :high)
    write_wheel_2(:low, :high)
    write_wheel_3(:low, :high)
    write_wheel_4(:low, :high)
  end

  defp car_backward do
    write_wheel_1(:high, :low)
    write_wheel_2(:high, :low)
    write_wheel_3(:high, :low)
    write_wheel_4(:high, :low)
  end

  defp car_go_left do
    set_duty_channel_2(@pwm_low)
    car_forward()
  end

  defp car_go_right do
    set_duty_channel_1(@pwm_low)
    car_forward()
  end

  defp car_reset_pwm do
    duty_channel_1 = get_duty_channel_1()
    duty_channel_2 = get_duty_channel_2()
    case duty_channel_1 > duty_channel_2 do
      true -> set_duty_channel_2(duty_channel_1)
      false -> set_duty_channel_1(duty_channel_2)
    end
  end

  defp car_diagonal_right_forward do
    car_go_right()
    Process.sleep(300)
    car_reset_pwm()
    car_forward()
  end

  defp car_diagonal_left_forward do
    car_go_left()
    Process.sleep(300)
    car_reset_pwm()
    car_forward()
  end

  defp get_html(request, duty) do
    [
      ~s"""
          <!DOCTYPE html>
          <html lang="en">
          <head>
              <meta charset="UTF-8" />
              <meta name="viewport" content="width=device-width, initial-scale=1.0" />
              <meta http-equiv="X-UA-Compatible" content="ie=edge" />
              <title>ESP32 Webserver</title>
              <style type="text/css">
              * {
                  margin: 0;
                  padding: 0;
                  box-sizing: border-box;
                  -webkit-user-select: none;
                  -khtml-user-select: none;
                  -moz-user-select: none;
                  -ms-user-select: none;
                  -o-user-select: none;
                  user-select: none;
              }
              h2 {
                  padding: 0;
                  margin: 0;
              }
              body {
                  display: flex;
                  width: 100vw;
                  background-color: #efefef;
                  flex-direction: column;
              }
              .main-title {
                  text-align: center;
                  margin-top: 24px;
                  color: #262626;
              }
              .wrapper {
                  margin: auto;
                  background-color: #fff;
                  box-shadow: 0 0px 4px -2px #000;
                  border-radius: 8px;
                  overflow: hidden;
                  margin-top: 24px;
              }
              .form {
                  margin: auto;
                  padding: 24px;
                  background-color: #fff;
              }
              .form-header {
                  text-align: center;
                  margin-bottom: 12px;
              }
              .form-body {
                  margin-bottom: 12px;
              }
              .form-body .form-group {
                  text-align: center;
              }
              .form-body .form-group input {
                  position: relative;
                  width: 90%;
                  margin-top: 12px;
              }
              .form-footer {
                  padding-top: 12px;
                  text-align: center;
              }
              .form-footer .form-btn {
                  background-color: cornflowerblue;
              }
              #duty::before {
                  display: block;
                  content: "0";
                  width: 12px;
                  height: 12px;
                  position: absolute;
                  left: 0;
                  top: 100%;
              }
              #duty::after {
                  display: block;
                  content: "100";
                  width: 12px;
                  height: 12px;
                  position: absolute;
                  right: 0;
                  top: 100%;
              }

              /* Additional CSS for the button interface */
              .button-container {
                  display: flex;
                  justify-content: center;
                  align-items: center;
                  margin-top: 24px;
              }

              .button {
                  display: inline-block;
                  width: 100px;
                  height: 40px;
                  text-align: center;
                  line-height: 40px;
                  border-radius: 5px;
                  font-family: Arial, sans-serif;
                  font-size: 14px;
                  color: #fff;
                  cursor: pointer;
                  margin: 5px;
                  background-color: cornflowerblue;
              }
              .btn {
                  border: none;
                  text-decoration: none;
              }

              .btn-center {
                  display: flex;
                  flex-direction: column;
              }

              #forward {
                  background-color: #3498db;
              }

              #backward {
                  background-color: #9b59b6;
              }

              #go-left {
                  background-color: #ffcb0e;
              }

              #go-right {
                  background-color: #2ecc71;
              }

              #stop {
                  background-color: #e74c3c;
              }
              .direction {
                  display: flex;
                  flex-direction: column;
                  align-items: center;
              }
              .direction-top {
                  display: flex;
                  flex-direction: row;
                  flex-wrap: nowrap;
              }
              .arrow {
                  font-size: 30px;
              }
              .arrow-center {
                  display: flex;
                  flex-direction: column;
              }
              .button.active {
                  animation-name: buttonActive;
                  animation-duration: 6s;
                  animation-iteration-count: infinite;
              }
              @keyframes buttonActive {
                  0% {
                  box-shadow: 0 0 24px #3498db;
                  }
                  20% {
                  box-shadow: 0 0 24px #ffcb0e;
                  }
                  40% {
                  box-shadow: 0 0 24px #e74c3c;
                  }
                  60% {
                  box-shadow: 0 0 24px #2ecc71;
                  }
                  80% {
                  box-shadow: 0 0 24px #9b59b6;
                  }
                  100% {
                  box-shadow: 0 0 24px #3498db;
                  }
              }
              </style>
          </head>
          <body>
              <h2 class="main-title">
              Car Controller
              </h2>
              <div class="wrapper">
              <div class="button-container">
                  <div>
                  <button class="button btn" id="go-left"
                  <onmousedown="toggleCheckbox('left');"
                  ontouchstart="toggleCheckbox('left');"
                  onmouseup="toggleCheckbox('stop');"
                  ontouchend="toggleCheckbox('stop');">
                      Go Left</button>
                  </div>
                  <div class="btn btn-center">
                  <div>
                      <button class="button btn" id="forward"
                      onmousedown="toggleCheckbox('forward');"
                      ontouchstart="toggleCheckbox('forward');"
                      onmouseup="toggleCheckbox('stop');"
                      ontouchend="toggleCheckbox('stop');">
                      Forward</button>
                  </div>
                  <div>
                      <button class="button btn" id="stop"
                      onmouseup="toggleCheckbox('stop');"
                      ontouchend="toggleCheckbox('stop');">
                      Stop</button>
                  </div>
                  <div>
                      <button class="button btn" id="backward"
                      onmousedown="toggleCheckbox('backward');"
                      ontouchstart="toggleCheckbox('backward');"
                      onmouseup="toggleCheckbox('stop');"
                      ontouchend="toggleCheckbox('stop');">
                      Backward</button>
                  </div>
                  </div>
                  <div>
                  <button class="button btn" id="go-right"
                  onmousedown="toggleCheckbox('right');"
                  ontouchstart="toggleCheckbox('right');"
                  onmouseup="toggleCheckbox('stop');"
                  ontouchend="toggleCheckbox('stop');">
                  Go Right</button>
                  </div>
              </div>
              <br />
              <!-- Start Direction -->
              <div class="direction">
                  <div class="direction-top">
                  <button class="button btn arrow" id="north-west"
                      onmousedown="toggleCheckbox('north-west');"
                      ontouchstart="toggleCheckbox('north-west');"><span>&nwarr;</span>
                  </button>
                  <button class="button btn arrow" id="
                      onmousedown="toggleCheckbox('forward');"
                      ontouchstart="toggleCheckbox('forward');">
                      <span>&uarr;</span>
                  </button>
                  <button class="button btn arrow" id="
                      onmousedown="toggleCheckbox('north-east');"
                      ontouchstart="toggleCheckbox('north-east');">
                      <span>&nearr;</span>
                  </button>
                  </div>
                  <button class="button btn arrow" id="
                  onmousedown="toggleCheckbox('backward');"
                  ontouchstart="toggleCheckbox('backward');">
                  <span>&darr;<span>
                  </button>
              </div>
              <!-- End Direction -->
              <form action="#" method="POST" class="form">
                  <div class="form-header">
                  </div>
                  <div class="form-body">
                  <div class="form-group">
                      <label for="duty"
                      >Current Duty Cycle:
                      <output id="dutyoutput" name="dutyoutput">50</output>%
                      </label>
                      <br />
                      <input
                      id="duty"
                      type="range"
                      name="duty"
                      min="0"
                      max="100"
                      step="1"
                      oninput="dutyoutput.value=duty.value"
                      />
                  </div>
                  </div>
                  <div class="form-footer">
                  <button type="submit" class="button">Save</button>
                  </div>
              </form>
              </div>
          </body>
          <script>
              let Duty = "">>, duty, ~s|".charCodeAt(0);
              let Request = "">>, request, ~s|".charCodeAt(0);
              if(Duty > 100) Duty = 0;
              document.getElementById("duty").value = Duty;
              document.getElementById("dutyoutput").innerHTML = Duty;

              function toggleCheckbox(x) {
                  var xhr = new XMLHttpRequest();
                  xhr.open("POST", x, true);
                  xhr.send();
              }
          </script>
      </html>

      """
    ]
  end
end
