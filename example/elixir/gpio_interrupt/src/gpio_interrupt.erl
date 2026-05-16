defmodule :"gpio_interrupt" do
  @pin 2

  def start do
    :gpio.set_pin_mode(@pin, :input)
    :gpio.set_pin_pull(@pin, :down)
    gpio = :gpio.start()
    :gpio.set_int(gpio, @pin, :rising)
    loop()
  end

  defp loop do
    IO.write("Waiting for interrupt ... ")

    receive do
      {:gpio_interrupt, pin} ->
        IO.puts("Interrupt on pin #{pin}")
    end

    loop()
  end
end
