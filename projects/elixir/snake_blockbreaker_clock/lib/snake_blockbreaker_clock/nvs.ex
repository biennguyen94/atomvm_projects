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

defmodule SnakeBlockbreakerClock.NVS do
  @moduledoc """
  Non-volatile storage access on ESP32.
 
  ## Wi-Fi credentials
  Hardcoded placeholders (NVS provisioning is not used on this firmware).
  Edit `@wifi_ssid` and `@wifi_passphrase` below to match your network.
 
  ## High scores
  Highest score per game is persisted in the `high_scores` namespace using the
  AtomVM `esp` NVS API (`esp:nvs_put_binary/3`, `esp:nvs_get_binary/2`).

  Keys (atoms, max 15 chars):
  - `:snake_hs` -> Snake Game score (snake length)
  - `:breaker_hs` -> Block Breaker score (blocks cleared)
  - `:flappy_hs` -> Flappy Bird score (pipes passed)

  Values are stored as Erlang terms (integers) via `:erlang.term_to_binary/1`.

  All operations degrade gracefully to a no-op / 0 if NVS is unavailable.
  """

  @wifi_ssid "wifi_name"
  @wifi_passphrase "password"

  @high_score_namespace :high_scores
  @high_score_keys %{snake: :snake_hs, breaker: :breaker_hs, flappy: :flappy_hs, pong: :pong_hs}

  def get_binary(:wifi_ssid), do: @wifi_ssid
  def get_binary(:wifi_passphrase), do: @wifi_passphrase
  def get_binary(_), do: nil

  def put_binary(_key, _value), do: :ok
  def delete(_key), do: :ok

  @doc """
  Return the stored highest score for a game (`:snake`, `:breaker`, `:flappy`).
  Returns 0 if nothing was ever stored or if NVS is unavailable.
  """
  def high_score(game) do
    case get_high_score_binary(game) do
      nil -> 0
      value -> decode_score(value)
    end
  end

  @doc """
  Update the stored highest score for a game, but only when `score` beats the
  currently stored value. Returns `{:ok, high_score}` with the effective
  high score (the max of the stored and the passed score).
  """
  def update_high_score(game, score) when is_integer(score) do
    current = high_score(game)

    if score > current do
      :ok = put_high_score_binary(game, :erlang.term_to_binary(score))
      IO.puts("NVS: new high score #{game} = #{score} (was #{current})")
    else
      IO.puts("NVS: keep high score #{game} = #{current} (score=#{score})")
    end

    {:ok, max(current, score)}
  end

  defp high_score_key(game), do: Map.fetch!(@high_score_keys, game)

  defp get_high_score_binary(game) do
    case :esp.nvs_get_binary(@high_score_namespace, high_score_key(game)) do
      :undefined -> nil
      <<>> -> nil
      value when is_binary(value) -> value
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp put_high_score_binary(game, value) do
    :esp.nvs_put_binary(@high_score_namespace, high_score_key(game), value)
  rescue
    _ -> :ok
  end

  defp decode_score(binary) do
    case :erlang.binary_to_term(binary) do
      value when is_integer(value) and value >= 0 -> value
      _ -> 0
    end
  rescue
    _ -> 0
  end
end
