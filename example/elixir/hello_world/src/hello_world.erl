defmodule :"hello_world" do
  def start do
    loop()
  end

  defp loop do
    IO.puts("Hello World")
    :timer.sleep(1000)
    loop()
  end
end
