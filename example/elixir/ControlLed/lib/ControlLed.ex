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

defmodule ControlLed do

  @compile {:no_warn_undefined, :atomvm}
  @compile {:no_warn_undefined, :network}
  @compile {:no_warn_undefined, :http_server}
  @compile {:no_warn_undefined, GPIO}

  @pin 2

  def start do
    init_led()
    :ok = maybe_start_network(:atomvm.platform())
    router = [{"*", __MODULE__, []}]
    port = Config1.get().port
    :http_server.start_server(port, router)
    :timer.sleep(:infinity)
  end

  def handle_req("GET", [], conn) do
    button = ~s(<p><a href="/?led=on"><button class="button button2">OFF</button></a></p>)
    body = get_html(button)
    :http_server.reply(200, body, conn)
  end

  def handle_req("GET", ["?led=on"], conn) do
    set_led_level(@pin, :high)
    button = ~s(<p><a href="/?led=off"><button class="button">ON</button></a></p>)
    body = get_html(button)
    :http_server.reply(200, body, conn)
  end

  def handle_req(_method, ["?led=off"], conn) do
    set_led_level(@pin, :low)
    button = ~s(<p><a href="/?led=on"><button class="button button2">OFF</button></a></p>)
    body = get_html(button)
    :http_server.reply(200, body, conn)
  end

  def handle_req(_method, _path, conn) do
    # IO.inspect({method, path}, label: "Request")
    body = "<html><body><h1>Not Found</h1></body></html>"
    :http_server.reply(404, body, conn)
  end

  defp private_to_string({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp private_to_string({address, port}), do: "#{private_to_string(address)}:#{port}"

  defp maybe_start_network(:esp32) do
    config = Config1.get().sta

    case :network.wait_for_sta(config, 30000) do
      {:ok, {address, netmask, gateway}} ->
        IO.puts(
          "Acquired IP address: #{private_to_string(address)} Netmask: #{private_to_string(netmask)} Gateway: #{private_to_string(gateway)}"
        )

        :ok

      error ->
        IO.puts("An error occurred starting network: #{inspect(error)}")
        error
    end
  end

  defp maybe_start_network(_platform), do: :ok

  defp get_html(button) do
    """
    <html>
      <head>
        <title>ESP Web Server</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="icon" href="data:,">
        <style>
          html{font-family: Helvetica; display:inline-block; margin: 0px auto; text-align: center;}
          h1{color: #0F3376; padding: 2vh;}
          p{font-size: 1.5rem;}
          .button {
            display: inline-block;
            width: 200px;
            background-color: green;
            border: none;
            border-radius: 4px;
            color: white;
            padding: 16px 40px;
            text-decoration: none;
            font-size: 30px;
            margin: 2px;
            cursor: pointer;
          }
          .button2 {background-color: red;}
        </style>
      </head>
      <body>
        <h1>ESP32 Web Server</h1>
        <p>with Erlang and AtomVM</p>
        #{button}
      </body>
    </html>
    """
  end

  defp init_led do
    IO.puts("Init led")
    GPIO.set_pin_mode(@pin, :output)
    GPIO.digital_write(@pin, :low)
  end

  defp set_led_level(pin, level) do
    IO.puts("Setting pin #{inspect(pin)}")
    IO.puts("Setting level #{inspect(level)}")
    GPIO.digital_write(pin, level)
  end
end
