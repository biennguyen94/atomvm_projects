defmodule :"encoder" do
  @motor_int1 19
  @motor_int2 21
  @en_a 15
  @en_b 2

  def start do
    init()
    loop(0)
  end

  defp init do
    :gpio.set_pin_mode(@motor_int1, :output)
    :gpio.set_pin_mode(@motor_int2, :output)
    :gpio.set_pin_mode(@en_a, :input)
    :gpio.set_pin_pull(@en_a, :down)
    :gpio.set_pin_mode(@en_b, :input)
    :gpio.set_pin_pull(@en_b, :down)
    gpio = :gpio.start()
    :gpio.set_int(gpio, @en_a, :rising)
    :gpio.set_int(gpio, @en_b, :rising)
  end

  defp loop(pulse) do
    :gpio.digital_write(@motor_int1, :high)
    :gpio.digital_write(@motor_int2, :low)

    receive do
      {:gpio_interrupt, _pin} ->
        pulse_new = pulse + 1
        IO.puts("Pulse is #{pulse_new}")
        loop(pulse_new)
    end
  end
end
