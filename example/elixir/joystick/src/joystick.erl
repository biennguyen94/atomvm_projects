defmodule :"joystick" do
  @gpio_vrx 34
  @gpio_vry 35
  @gpio_sw 32

  @low_range 700
  @high_range 3000
  @delay_read_adc 5

  def start do
    {adcx, adcy} = setup_adc()
    IO.puts("Init success")
    loop(adcx, adcy)
  end

  defp setup_adc do
    :ok = :esp_adc.start(@gpio_vrx)
    :ok = :esp_adc.start(@gpio_vry)
    {@gpio_vrx, @gpio_vry}
  end

  defp loop(adcx, adcy) do
    {:ok, x} = read_adc(adcx)
    {:ok, y} = read_adc(adcy)

    cond do
      x < @low_range ->
        IO.puts("Current position is: LEFT")

      y < @low_range ->
        IO.puts("Current position is: BOTTOM")

      x > @high_range ->
        IO.puts("Current position is: RIGHT")

      y > @high_range ->
        IO.puts("Current position is: TOP")

      true ->
        IO.puts("Current position is: MIDDLE")
    end

    :timer.sleep(@delay_read_adc)
    loop(adcx, adcy)
  end

  defp read_adc(adc) do
    case :esp_adc.read(adc) do
      {:ok, {raw, _millivolts}} ->
        {:ok, raw}

      error ->
        IO.puts("Error taking reading: #{inspect(error)}")
        error
    end
  end
end
