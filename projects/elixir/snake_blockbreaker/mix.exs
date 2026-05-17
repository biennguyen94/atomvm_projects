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
defmodule SnakeBlockbreaker.MixProject do
  use Mix.Project

  def project do
    [
      app: :snake_blockbreaker,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      atomvm: [
        start: SnakeBlockbreaker,
        flash_offset: 0x250000
      ]
    ]
  end

  def application do
    [
      extra_applications: [],
      mod: {SnakeBlockbreaker, []}
    ]
  end

  defp deps do
    [
      {:exatomvm, git: "https://github.com/atomvm/exatomvm.git", branch: "main"}
    ]
  end
end
