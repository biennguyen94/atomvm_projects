defmodule SntpClock do
  use Bitwise

  @digit_0 0x1
  @digit_1 0x2
  @digit_2 0x3
  @digit_3 0x4
  @digit_4 0x5
  @digit_5 0x6
  @digit_6 0x7
  @digit_7 0x8
  @decode_mode 0x9
  @intensity 0xA
  @scan_limit 0xB
  @shutdown 0xC
  @display_test 0xF

  @num_of_bits 8

  @spisettings [
    bus_config: [miso: 19, mosi: 27, sclk: 5],
    device_config: [
      device_1: [clock_speed_hz: 1_000_000, mode: 0, cs: 18, address_len_bits: 8],
      device_2: [clock_speed_hz: 1_000_000, mode: 0, cs: 23, address_len_bits: 8]
    ]
  ]

  @wifi_ssid "HBTBK"
  @wifi_passphrase "49494949"
  @sntp_host "pool.ntp.org"
  @timezone_offset_ms 7 * 3600 * 1000

  @empty_matrix %{
    1 => 0b00000000,
    2 => 0b00000000,
    3 => 0b00000000,
    4 => 0b00000000,
    5 => 0b00000000,
    6 => 0b00000000,
    7 => 0b00000000,
    8 => 0b00000000
  }

  @digit_left %{
    0 => %{1 => 0b00111100, 2 => 0b01000010, 3 => 0b01000010, 4 => 0b00111100, 5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    1 => %{1 => 0b01000100, 2 => 0b01111110, 3 => 0b01000000, 4 => 0b00000000, 5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    2 => %{1 => 0b01000100, 2 => 0b01100010, 3 => 0b01010010, 4 => 0b01001100, 5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    3 => %{1 => 0b01000010, 2 => 0b01001010, 3 => 0b01111110, 4 => 0b00000000, 5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    4 => %{1 => 0b00010000, 2 => 0b00011000, 3 => 0b00010100, 4 => 0b01111110, 5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    5 => %{1 => 0b01001110, 2 => 0b01001010, 3 => 0b01001010, 4 => 0b01111010, 5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    6 => %{1 => 0b01111110, 2 => 0b01001010, 3 => 0b01001010, 4 => 0b01111010, 5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    7 => %{1 => 0b01000010, 2 => 0b00100010, 3 => 0b00010010, 4 => 0b00001110, 5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    8 => %{1 => 0b01111110, 2 => 0b01001010, 3 => 0b01001010, 4 => 0b01111110, 5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000},
    9 => %{1 => 0b01001110, 2 => 0b01001010, 3 => 0b01001010, 4 => 0b01111110, 5 => 0b00000000, 6 => 0b00000000, 7 => 0b00000000, 8 => 0b00000000}
  }

  @digit_right %{
    0 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000, 5 => 0b00111100, 6 => 0b01000010, 7 => 0b01000010, 8 => 0b00111100},
    1 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000, 5 => 0b00000000, 6 => 0b01000100, 7 => 0b01111110, 8 => 0b01000000},
    2 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000, 5 => 0b01000100, 6 => 0b01100010, 7 => 0b01010010, 8 => 0b01001100},
    3 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000, 5 => 0b00000000, 6 => 0b01000010, 7 => 0b01001010, 8 => 0b01111110},
    4 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000, 5 => 0b00010000, 6 => 0b00011000, 7 => 0b00010100, 8 => 0b01111110},
    5 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000, 5 => 0b01001110, 6 => 0b01001010, 7 => 0b01001010, 8 => 0b01111010},
    6 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000, 5 => 0b01111110, 6 => 0b01001010, 7 => 0b01001010, 8 => 0b01111010},
    7 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000, 5 => 0b01000010, 6 => 0b00100010, 7 => 0b00010010, 8 => 0b00001110},
    8 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000, 5 => 0b01111110, 6 => 0b01001010, 7 => 0b01001010, 8 => 0b01111110},
    9 => %{1 => 0b00000000, 2 => 0b00000000, 3 => 0b00000000, 4 => 0b00000000, 5 => 0b01001110, 6 => 0b01001010, 7 => 0b01001010, 8 => 0b01111110}
  }

  def start do
    IO.puts("Starting SNTP Clock...")

    maybe_provision()
    wifi_ssid = nvs_get(:wifi_ssid) || @wifi_ssid
    wifi_passphrase = nvs_get(:wifi_passphrase) || @wifi_passphrase

    sta_opts =
      [ssid: wifi_ssid, connected: &wifi_connected/0, got_ip: &wifi_got_ip/1]
      |> maybe_put(:psk, wifi_passphrase)

    :network.start_link(
      sta: sta_opts,
      sntp: [
        host: @sntp_host,
        synchronized: &handle_sntp_synced/1
      ]
    )

    {:ok, spi} = init_max7219(@spisettings)

    wait_for_sntp(60)
    IO.puts("sntp: starting clock display")

    clock_loop(spi, @empty_matrix, @empty_matrix, 0)
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp maybe_provision do
    if @wifi_ssid != nil and @wifi_ssid != "" do
      case nvs_get(:wifi_ssid) do
        nil ->
          nvs_put(:wifi_ssid, @wifi_ssid)
          if @wifi_passphrase != nil and @wifi_passphrase != "" do
            nvs_put(:wifi_passphrase, @wifi_passphrase)
          end
          IO.puts("wifi: provisioned credentials to NVS")
        _ ->
          :ok
      end
    end
  end

  defp nvs_get(key) do
    case :esp.nvs_get_binary(:sntp, key) do
      :undefined -> nil
      <<>> -> nil
      value when is_binary(value) -> value
    end
  end

  defp nvs_put(key, value) do
    :esp.nvs_put_binary(:sntp, key, value)
  end

  def wifi_connected, do: IO.puts("wifi: connected to AP")

  def wifi_got_ip(ip_info), do: IO.puts("wifi: got IP #{inspect(ip_info)}")

  def handle_sntp_synced(timeval) do
    IO.puts("sntp: synced #{inspect(timeval)}")
  end

  defp wait_for_sntp(0) do
    epoch_ms = :erlang.system_time(:millisecond)
    IO.puts("sntp: timeout, epoch=#{epoch_ms}")
  end

  defp wait_for_sntp(retries) do
    epoch_ms = :erlang.system_time(:millisecond)
    if epoch_ms > 1_600_000_000_000 do
      IO.puts("sntp: time is valid (epoch=#{epoch_ms})")
    else
      IO.puts("sntp: waiting for sync... retries=#{retries} epoch=#{epoch_ms}")
      Process.sleep(1000)
      wait_for_sntp(retries - 1)
    end
  end

  defp init_max7219(spi_settings) do
    spi = :spi.open(spi_settings)
    for dev <- [:device_1, :device_2] do
      write_register(spi, @decode_mode, 0x0, dev)
      write_register(spi, @intensity, 0x0, dev)
      write_register(spi, @scan_limit, 0x7, dev)
      write_register(spi, @shutdown, 0x1, dev)
      write_register(spi, @display_test, 0x0, dev)
    end
    {:ok, spi}
  end

  defp clock_loop(spi, prev_left, prev_right, effect_idx) do
    epoch_ms = :erlang.system_time(:millisecond)
    local_ms = epoch_ms + @timezone_offset_ms

    {{_year, _month, _day}, {hour, minute, _second}} =
      :calendar.system_time_to_universal_time(local_ms, :millisecond)

    hour_tens = div(hour, 10)
    hour_ones = rem(hour, 10)
    mins_tens = div(minute, 10)
    mins_ones = rem(minute, 10)

    left_data = stack_digits(hour_tens, hour_ones)
    right_data = stack_digits(mins_tens, mins_ones)

    left_change = left_data != prev_left
    right_change = right_data != prev_right

    if right_change do
      apply_effect(spi, prev_right, right_data, :device_2, rem(effect_idx, 3))
    end
    if left_change do
      apply_effect(spi, prev_left, left_data, :device_1, random_effect())
    end

    IO.puts("Time: #{pad(hour)}:#{pad(minute)}")

    Process.sleep(1000)
    clock_loop(spi, left_data, right_data, if(right_change, do: effect_idx + 1, else: effect_idx))
  end

  defp random_effect do
    rem(:erlang.system_time(:millisecond), 3)
  end

  defp apply_effect(spi, old, new, device, 0) do
    IO.puts("effect: rain_v (#{device})")
    effect_rain(spi, old, new, device)
  end
  defp apply_effect(spi, old, new, device, 1) do
    IO.puts("effect: rain_h (#{device})")
    effect_rain_h(spi, old, new, device)
  end
  defp apply_effect(spi, old, new, device, 2) do
    IO.puts("effect: scroll_up (#{device})")
    effect_scroll_up(spi, old, new, device)
  end

  defp effect_rain(spi, _old, new, device) do
    write_digit(spi, @digit_0, @empty_matrix, device)
    Process.sleep(12)
    effect_rain_cols(spi, new, 0, @empty_matrix, device)
    write_digit(spi, @digit_0, new, device)
  end

  defp effect_rain_cols(_spi, _new, 8, cur, _device), do: cur

  defp effect_rain_cols(spi, new, col, cur, device) do
    cur = effect_rain_fall(spi, col, 1, cur, device)
    cur = effect_rain_lock(spi, new, col, cur, device)
    effect_rain_cols(spi, new, col + 1, cur, device)
  end

  defp effect_rain_fall(_spi, _col, 9, cur, _device), do: cur

  defp effect_rain_fall(spi, col, row, cur, device) do
    mask = 1 <<< (7 - col)
    frame = for r <- 1..8, into: %{} do
      if r == row do
        {r, Map.get(cur, r, 0) ||| mask}
      else
        {r, Map.get(cur, r, 0) &&& (~~~mask &&& 0xFF)}
      end
    end
    write_digit(spi, @digit_0, frame, device)
    Process.sleep(8)
    effect_rain_fall(spi, col, row + 1, cur, device)
  end

  defp effect_rain_lock(spi, new, col, cur, device) do
    mask = 1 <<< (7 - col)
    cur = for r <- 1..8, into: %{} do
      existing = Map.get(cur, r, 0)
      new_bit = Map.get(new, r, 0) &&& mask
      {r, (existing &&& (~~~mask &&& 0xFF)) ||| new_bit}
    end
    write_digit(spi, @digit_0, cur, device)
    Process.sleep(8)
    cur
  end

  defp effect_rain_h(spi, _old, new, device) do
    write_digit(spi, @digit_0, @empty_matrix, device)
    Process.sleep(12)
    effect_rain_rows(spi, new, 1, @empty_matrix, device)
    write_digit(spi, @digit_0, new, device)
  end

  defp effect_rain_rows(_spi, _new, 9, cur, _device), do: cur

  defp effect_rain_rows(spi, new, row, cur, device) do
    cur = effect_rain_flow(spi, row, 0, cur, device)
    cur = effect_rain_lock_row(spi, new, row, cur, device)
    effect_rain_rows(spi, new, row + 1, cur, device)
  end

  defp effect_rain_flow(_spi, _row, 8, cur, _device), do: cur

  defp effect_rain_flow(spi, row, col, cur, device) do
    mask = 1 <<< (7 - col)
    frame = for r <- 1..8, into: %{} do
      if r == row do
        {r, mask}
      else
        {r, Map.get(cur, r, 0)}
      end
    end
    write_digit(spi, @digit_0, frame, device)
    Process.sleep(8)
    effect_rain_flow(spi, row, col + 1, cur, device)
  end

  defp effect_rain_lock_row(spi, new, row, cur, device) do
    new_row = Map.get(new, row, 0)
    cur = %{cur | row => new_row}
    write_digit(spi, @digit_0, cur, device)
    Process.sleep(8)
    cur
  end

  defp effect_scroll_up(spi, old, new, device) do
    for step <- 0..7 do
      frame = for row <- 1..8, into: %{} do
        src = row + step
        if src <= 8 do
          {row, Map.get(old, src, 0)}
        else
          {row, Map.get(new, src - 8, 0)}
        end
      end
      write_digit(spi, @digit_0, frame, device)
      Process.sleep(20)
    end
    write_digit(spi, @digit_0, new, device)
  end

  defp refresh_effect(spi, data, device, _effect_num) do
    IO.puts("effect: scroll_up (refresh #{device})")
    effect_scroll_up(spi, @empty_matrix, data, device)
  end

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: Integer.to_string(n)

  defp stack_digits(top, bot) do
    top_map = Map.get(@digit_left, top, @digit_left[0])
    bot_map = Map.get(@digit_right, bot, @digit_right[0])
    for row <- 1..8, into: %{} do
      t = Map.get(top_map, row, 0)
      b = Map.get(bot_map, row, 0)
      {row, t ||| b}
    end
  end

  defp write_digit(spi, 8, data, device) do
    write_register(spi, 8, Map.get(data, 8, 0), device)
    :ok
  end

  defp write_digit(spi, number, data, device) do
    write_register(spi, number, Map.get(data, number, 0), device)
    write_digit(spi, number + 1, data, device)
  end

  defp write_register(spi, address, data, device) do
    :spi.write_at(spi, device, address, @num_of_bits, data)
  end
end
