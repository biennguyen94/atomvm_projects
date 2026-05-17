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

defmodule Encoder do
  @compile {:no_warn_undefined, GPIO}
  @motor_int1 19
  @motor_int2 21
  @en_a 15
  @en_b 2

  def start do
    init()
    loop(0)
  end

  defp init do
    GPIO.set_pin_mode(@motor_int1, :output)
    GPIO.set_pin_mode(@motor_int2, :output)
    GPIO.set_pin_mode(@en_a, :input)
    GPIO.set_pin_pull(@en_a, :down)
    GPIO.set_pin_mode(@en_b, :input)
    GPIO.set_pin_pull(@en_b, :down)
    gpio = GPIO.open()
    GPIO.set_int(gpio, @en_a, :rising)
    GPIO.set_int(gpio, @en_b, :rising)
  end

  defp loop(pulse) do
    GPIO.digital_write(@motor_int1, :high)
    GPIO.digital_write(@motor_int2, :low)

    receive do
      {:gpio_interrupt, _pin} ->
        pulse_new = pulse + 1
        IO.puts("Pulse is #{pulse_new}")
        loop(pulse_new)
    end
  end
end
