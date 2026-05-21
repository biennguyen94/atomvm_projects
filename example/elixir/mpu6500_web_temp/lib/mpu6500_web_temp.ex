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

defmodule Mpu6500WebTemp do
  @compile {:no_warn_undefined, :network}

  @gpio_scl 22
  @gpio_sda 21

  @mpu9250_addr 0x68
  @acc_addr 0x3B
  @gyro_addr 0x43
  @acc_config_addr 0x1C
  @gyro_config_addr 0x1B
  @base_freq 1000000

  @gyro_full_scale_2000_dps 0x18
  @acc_full_scale_16_g 0x18

  @num_byte 14
  @temp_offset 0
  @temp_sens 0.003115264797507788
  @acc_scale 4.8828125e-4
  @gyro_scale 0.06097560975609757

  @wifi_ssid "ssid"
  @wifi_passphrase "password"
  @server_host '192.168.1.90'
  @server_port 4000

  def start do
    connect_wifi()
    i2c = i2c_init()
    mpu_config(i2c)
    read(i2c)
  end

  defp connect_wifi do
    :network.start_link(
      sta: [
        ssid: @wifi_ssid,
        psk: @wifi_passphrase,
        connected: &on_wifi_connected/0,
        got_ip: &on_got_ip/1
      ]
    )

    Process.sleep(5000)
  end

  defp on_wifi_connected do
    IO.puts("WiFi: connected to AP")
  end

  defp on_got_ip(ip_info) do
    IO.puts("WiFi: got IP #{inspect(ip_info)}")
  end

  defp read(i2c) do
    {:ok, val} = mpu_read_data(i2c)

    <<
      accx::signed-integer-16,
      accy::signed-integer-16,
      accz::signed-integer-16,
      temp::integer-16,
      gyrox::signed-integer-16,
      gyroy::signed-integer-16,
      gyroz::signed-integer-16
    >> = val

    temp_data = get_temp_value(temp)
    acc_data = {accx * @acc_scale, accy * @acc_scale, accz * @acc_scale}
    gyro_data = {gyrox * @gyro_scale, gyroy * @gyro_scale, gyroz * @gyro_scale}

    IO.puts("Acc: #{inspect(acc_data)} Temp: #{inspect(temp_data)} Gyro: #{inspect(gyro_data)}")

    send_temperature(temp_data)

    :timer.sleep(3000)
    read(i2c)
  end

  defp i2c_init do
    I2C.open([{:scl, @gpio_scl}, {:sda, @gpio_sda}, {:clock_speed_hz, @base_freq}])
  end

  defp mpu_config(i2c) do
    mpu_send_command(i2c, @acc_config_addr, @acc_full_scale_16_g)
    mpu_send_command(i2c, @gyro_config_addr, @gyro_full_scale_2000_dps)
  end

  defp mpu_send_command(i2c, register, command) do
    I2C.begin_transmission(i2c, @mpu9250_addr)
    I2C.write_byte(i2c, register)
    I2C.write_byte(i2c, command)
    I2C.end_transmission(i2c)
  end

  defp mpu_read_data(i2c) do
    I2C.begin_transmission(i2c, @mpu9250_addr)
    I2C.write_byte(i2c, @acc_addr)
    I2C.end_transmission(i2c)
    :timer.sleep(20)
    I2C.read_bytes(i2c, @mpu9250_addr, @num_byte)
  end

  defp get_temp_value(temp) do
    round((temp - @temp_offset) * @temp_sens + 21)
  end

  defp send_temperature(temp) do
    temp_str = :erlang.integer_to_list(temp)
    body = ['{"temperature":', temp_str, '}']
    content_length = :erlang.iolist_size(body)
    port_str = :erlang.integer_to_list(@server_port)

    request = [
      'POST /api/temperature HTTP/1.1\r\n',
      'Host: ', @server_host, ':', port_str, '\r\n',
      'Content-Type: application/json\r\n',
      'Content-Length: ', :erlang.integer_to_list(content_length), '\r\n',
      '\r\n',
      body
    ]

    case :gen_tcp.connect(@server_host, @server_port, [{:binary, true}, {:active, false}, {:timeout, 5000}]) do
      {:ok, sock} ->
        :gen_tcp.send(sock, request)

        case :gen_tcp.recv(sock, 0, 5000) do
          {:ok, response} -> IO.puts("Server: #{response}")
          {:error, reason} -> IO.puts("Recv error: #{inspect(reason)}")
        end

        :gen_tcp.close(sock)

      {:error, reason} ->
        IO.puts("Connect error: #{inspect(reason)}")
    end
  end
end
