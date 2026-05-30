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

defmodule SnakeBlockbreakerClock.WiFi do
  @moduledoc """
  Start Wi-Fi (STA) and trigger DistErl start once an IP address is obtained.
  """

  @compile {:no_warn_undefined, :network}

  @dhcp_hostname "snake_blockbreaker_clock"
  @sntp_host "pool.ntp.org"

  def start_link(_opts \\ []) do
    case fetch_wifi_credentials() do
      {:ok, {wifi_ssid, wifi_passphrase}} ->
        :network.start_link(
          sta:
            [
              dhcp_hostname: @dhcp_hostname,
              connected: &handle_sta_connected/0,
              got_ip: &handle_sta_got_ip/1,
              ssid: wifi_ssid
            ]
            |> maybe_put(:psk, wifi_passphrase),
          sntp: [
            host: @sntp_host,
            synchronized: &handle_sntp_synchronized/1
          ]
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_wifi_credentials do
    wifi_ssid = SnakeBlockbreakerClock.NVS.get_binary(:wifi_ssid)

    if is_nil(wifi_ssid) do
      IO.puts("wifi: missing SSID in NVS (key: wifi_ssid). Provision first.")
      {:error, {:missing_nvs_key, :wifi_ssid}}
    else
      wifi_passphrase = SnakeBlockbreakerClock.NVS.get_binary(:wifi_passphrase)
      {:ok, {wifi_ssid, wifi_passphrase}}
    end
  end

  defp maybe_put(keyword, _key, nil), do: keyword
  defp maybe_put(keyword, key, value) when is_binary(value), do: Keyword.put(keyword, key, value)

  def handle_sta_connected, do: IO.puts("wifi: connected to AP")

  def handle_sta_got_ip(ip_info) do
    IO.puts("wifi: got IP #{inspect(ip_info)}")
    SnakeBlockbreakerClock.DistErl.maybe_start(ip_info)
  end

  def handle_sntp_synchronized(timeval), do: IO.puts("sntp: synced #{inspect(timeval)}")
end
