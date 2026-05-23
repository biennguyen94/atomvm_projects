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

defmodule SnakeBlockbreaker.DistErl do
  @moduledoc """
  Starts Distributed Erlang once Wi-Fi has an IPv4 address, and provides a
  registered process `:snake_speed` that receives speed commands from remote nodes.

  ## Remote usage
  On a remote Erlang node with the same cookie `"AtomVM"`:
  ```
  # Set snake game speed (200 = fast, 1000 = slow)
  send({:snake_speed, :'biennguyen@192.168.1.100'}, {:set_speed, 500})
  ```
  """

  use GenServer

  @compile {:no_warn_undefined, :epmd}
  @compile {:no_warn_undefined, :net_kernel}

  @cookie "AtomVM"
  @listen_port 9100
  @node_base "biennguyen"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put(opts, :name, __MODULE__))
  end

  def maybe_start(ip_info) do
    GenServer.cast(__MODULE__, {:maybe_start, ip_info})
  end

  def init(:ok) do
    {:ok, %{started?: false, node_name: nil}}
  end

  def handle_cast({:maybe_start, {address, _netmask, _gateway}}, %{started?: false} = state) do
    case start_distribution(address) do
      {:ok, node_name} ->
        IO.puts("disterl: started")
        IO.puts("disterl: node #{inspect(node_name)}")
        IO.puts("disterl: cookie #{inspect(@cookie)}")
        start_speed_control()
        IO.puts("disterl: registered process :snake_speed")
        {:noreply, %{state | started?: true, node_name: node_name}}

      {:error, reason} ->
        IO.puts("disterl: failed to start #{inspect(reason)}")
        {:noreply, state}
    end
  end

  def handle_cast({:maybe_start, _ip_info}, state) do
    {:noreply, state}
  end

  def handle_info(message, state) do
    IO.puts("disterl: received #{inspect(message)}")
    {:noreply, state}
  end

  defp start_distribution({a, b, c, d}) do
    node_name = :"#{@node_base}@#{a}.#{b}.#{c}.#{d}"

    with :ok <- ensure_epmd_started(),
         :ok <- ensure_net_kernel_started(node_name),
         :ok <- :net_kernel.set_cookie(@cookie),
         :ok <- ensure_registered(:disterl, self()) do
      {:ok, node_name}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_epmd_started do
    case :epmd.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      other -> {:error, {:epmd_start_failed, other}}
    end
  end

  defp ensure_net_kernel_started(node_name) do
    options = %{
      name_domain: :longnames,
      avm_dist_opts: %{
        listen_port_min: @listen_port,
        listen_port_max: @listen_port
      }
    }

    case :net_kernel.start(node_name, options) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      other -> {:error, {:net_kernel_start_failed, other}}
    end
  end

  defp ensure_registered(name, pid) do
    case Process.whereis(name) do
      nil ->
        true = :erlang.register(name, pid)
        :ok

      ^pid ->
        :ok

      other_pid ->
        {:error, {:already_registered, name, other_pid}}
    end
  end

  defp start_speed_control do
    spawn(fn ->
      :erlang.register(:snake_speed, self())
      speed_loop(nil)
    end)
  end

  defp speed_loop(loop_pid) do
    receive do
      {:register_loop, pid} ->
        speed_loop(pid)

      {:set_speed, speed} when is_integer(speed) ->
        if is_pid(loop_pid) do
          send(loop_pid, {:newspeed, speed})
        end
        speed_loop(loop_pid)

      :stop ->
        :ok
    end
  end

  def register_loop(pid) do
    case Process.whereis(:snake_speed) do
      nil -> :ok
      speed_pid -> send(speed_pid, {:register_loop, pid})
    end
  end
end
