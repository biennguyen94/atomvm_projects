defmodule :"ledc" do
  @ledc_hs_timer 0
  @ledc_hs_mode 0
  @ledc_hs_ch0_gpio 18
  @ledc_hs_ch0_channel 0
  @ledc_timer_13_bit 13

  def start do
    ledc_hs_timer = [
      {:duty_resolution, @ledc_timer_13_bit},
      {:freq_hz, 3000},
      {:speed_mode, @ledc_hs_mode},
      {:timer_num, @ledc_hs_timer}
    ]

    :ok = :ledc.timer_config(ledc_hs_timer)

    ledc_channel_1 = [
      {:channel, @ledc_hs_ch0_channel},
      {:duty, 0},
      {:gpio_num, @ledc_hs_ch0_gpio},
      {:speed_mode, @ledc_hs_mode},
      {:hpoint, 0},
      {:timer_sel, @ledc_hs_timer}
    ]

    :ok = :ledc.channel_config(ledc_channel_1)
    :ok = :ledc.fade_func_install(0)
    :ok = maybe_start_network(:atomvm.platform())

    router = [{"*", __MODULE__, []}]
    port = config().port
    :http_server.start_server(port, router)
    :timer.sleep(:infinity)
  end

  def handle_req("GET", [], conn) do
    body = get_html(0)
    :http_server.reply(200, body, conn)
  end

  def handle_req("POST", [], conn) do
    params_body = Keyword.get(conn, :body_chunk)
    params = :http_server.parse_query_string(params_body)
    duty_cycle = Keyword.get(params, "duty")
    duty_num = safe_list_to_integer(duty_cycle)
    set_duty_channel_1(duty_num)
    body = get_html(duty_num)
    :http_server.reply(200, body, conn)
  end

  def handle_req(method, path, conn) do
    IO.inspect(conn, label: "Conn")
    IO.inspect({method, path})
    body = "<html><body><h1>Not Found</h1></body></html>"
    :http_server.reply(404, body, conn)
  end

  defp safe_list_to_integer(l) when is_list(l) do
    try do
      String.to_integer(List.to_string(l))
    rescue
      _ -> nil
    end
  end

  defp safe_list_to_integer(_), do: nil

  defp private_to_string({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp private_to_string({address, port}), do: "#{private_to_string(address)}:#{port}"

  defp maybe_start_network(:esp32) do
    config = config().sta

    case :network.wait_for_sta(config, 30000) do
      {:ok, {address, netmask, gateway}} ->
        IO.puts(
          "Acquired IP address: #{private_to_string(address)} Netmask: #{private_to_string(netmask)} Gateway: #{private_to_string(gateway)}"
        )

        :ok

      error ->
        IO.puts("An error occurred starting network: #{inspect(error)}")
        error
    end
  end

  defp maybe_start_network(_platform), do: :ok

  defp get_html(duty) do
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta http-equiv="X-UA-Compatible" content="ie=edge" />
        <title>ESP32 Webserver</title>
        <style type="text/css">
          * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            -webkit-user-select: none;
            -khtml-user-select: none;
            -moz-user-select: none;
            -ms-user-select: none;
            -o-user-select: none;
            user-select: none;
          }
          h2 {
            padding: 0;
            margin: 0;
          }
          body {
            display: flex;
            width: 100vw;
            background-color: #efefef;
            flex-direction: column;
          }
          .main-title {
            text-align: center;
            margin-top: 24px;
            color: #262626;
          }
          .wrapper {
            margin: auto;
            background-color: #fff;
            box-shadow: 0 0px 4px -2px #000;
            border-radius: 8px;
            overflow: hidden;
            margin-top: 24px;
          }
          .form {
            margin: auto;
            padding: 24px;
            background-color: #fff;
          }
          .form-header {
            text-align: center;
            margin-bottom: 12px;
          }
          .form-body {
            margin-bottom: 12px;
          }
          .form-body .form-group {
            text-align: center;
          }
          .form-body .form-group input {
            position: relative;
            width: 90%;
            margin-top: 12px;
          }
          .form-footer {
            padding-top: 12px;
            text-align: center;
          }
          .form-footer .form-btn {
            background-color: cornflowerblue;
          }
          #duty::before {
            display: block;
            content: "0";
            width: 12px;
            height: 12px;
            position: absolute;
            left: 0;
            top: 100%;
          }
          #duty::after {
            display: block;
            content: "100";
            width: 12px;
            height: 12px;
            position: absolute;
            right: 0;
            top: 100%;
          }
        </style>
      </head>
      <body>
        <h2 class="main-title">ESP32 - LEDC</h2>
        <form action="#" method="POST" class="form">
          <div class="form-header"></div>
          <div class="form-body">
            <div class="form-group">
              <label for="duty">Current Duty Cycle:
                <output id="dutyoutput" name="dutyoutput">50</output>%
              </label>
              <br />
              <input
                id="duty"
                type="range"
                name="duty"
                min="0"
                max="100"
                step="5"
                oninput="dutyoutput.value=duty.value"
              />
            </div>
          </div>
          <div class="form-footer">
            <button type="submit" class="button">Save</button>
          </div>
        </form>
      </div>
      <script>
        document.getElementById("duty").value = #{duty};
        document.getElementById("dutyoutput").innerHTML = #{duty};
      </script>
    </body>
    </html>
    """
  end

  defp set_duty_channel_1(duty_num) do
    IO.puts("Set duty cycle: #{duty_num}")
    speed_mode = @ledc_hs_mode
    channel = @ledc_hs_ch0_channel
    duty = div(8191 * duty_num, 100)
    :ok = :ledc.set_duty(speed_mode, channel, duty)
    :ok = :ledc.update_duty(speed_mode, channel)
  end

  defp config do
    :config.get()
  end
end
