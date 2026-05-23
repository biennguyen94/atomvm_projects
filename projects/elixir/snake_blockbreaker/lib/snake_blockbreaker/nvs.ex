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

defmodule SnakeBlockbreaker.NVS do
  @moduledoc """
  Hardcoded Wi-Fi credentials (NVS is not available on this firmware).
  Edit `@wifi_ssid` and `@wifi_passphrase` below to match your network.
  """

  @wifi_ssid "your_SSID"
  @wifi_passphrase "your_password"

  def get_binary(:wifi_ssid), do: @wifi_ssid
  def get_binary(:wifi_passphrase), do: @wifi_passphrase
  def get_binary(_), do: nil

  def put_binary(_key, _value), do: :ok
  def delete(_key), do: :ok
end
