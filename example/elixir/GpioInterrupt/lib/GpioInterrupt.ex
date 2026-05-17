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

defmodule GpioInterrupt do
  @pin 2

  def start do
    GPIO.set_pin_mode(@pin, :input)
    GPIO.set_pin_pull(@pin, :down)
    gpio = GPIO.open()
    GPIO.set_int(gpio, @pin, :rising)
    loop()
  end

  defp loop do
    IO.puts("Waiting for interrupt ... ")

    receive do
      {:gpio_interrupt, pin} ->
        IO.puts("Interrupt on pin #{pin}")
    end

    loop()
  end
end
