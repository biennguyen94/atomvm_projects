defmodule :"config" do
  def get do
    %{
      port: 1111,
      sta: [
        ssid: :esp.nvs_get_binary(:atomvm, :sta_ssid, "wifi"),
        psk: :esp.nvs_get_binary(:atomvm, :sta_psk, "password")
      ]
    }
  end
end
