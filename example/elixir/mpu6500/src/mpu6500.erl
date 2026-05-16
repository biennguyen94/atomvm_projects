defmodule :"mpu6500" do
  @gpio_scl 22
  @gpio_sda 21

  @mpu9250_addr 0x68
  @acc_addr 0x3B
  @temp_addr 0x41
  @gyro_addr 0x43
  @acc_config_addr 0x1C
  @gyro_config_addr 0x1B
  @base_freq 1000000

  @gyro_full_scale_2000_dps 0x18
  @acc_full_scale_16_g 0x18

  @num_byte 14
  @temp_offset 0
  @temp_sens 0.003115264797507788
  @acc_scale 4.8828125e-4
  @gyro_scale 0.06097560975609757

  def start do
    i2c = i2c_init()
    mpu_config(i2c)
    read(i2c)
  end

  defp read(i2c) do
    {:ok, val} = mpu_read_data(i2c)

    <<
      accx::signed-integer-16,
      accy::signed-integer-16,
      accz::signed-integer-16,
      temp::integer-16,
      gyrox::signed-integer-16,
      gyroy::signed-integer-16,
      gyroz::signed-integer-16
    >> = val

    temp_data = get_temp_value(temp)
    acc_data = {accx * @acc_scale, accy * @acc_scale, accz * @acc_scale}
    gyro_data = {gyrox * @gyro_scale, gyroy * @gyro_scale, gyroz * @gyro_scale}

    IO.puts("Acc: #{inspect(acc_data)} Temp: #{inspect(temp_data)} Gyro: #{inspect(gyro_data)}")
    :timer.sleep(3000)
    read(i2c)
  end

  defp i2c_init do
    :i2c.open([{:scl, @gpio_scl}, {:sda, @gpio_sda}, {:clock_speed_hz, @base_freq}])
  end

  defp mpu_config(i2c) do
    mpu_send_command(i2c, @acc_config_addr, @acc_full_scale_16_g)
    mpu_send_command(i2c, @gyro_config_addr, @gyro_full_scale_2000_dps)
  end

  defp mpu_send_command(i2c, register, command) do
    :i2c.begin_transmission(i2c, @mpu9250_addr)
    :i2c.write_byte(i2c, register)
    :i2c.write_byte(i2c, command)
    :i2c.end_transmission(i2c)
  end

  defp mpu_read_data(i2c) do
    :i2c.begin_transmission(i2c, @mpu9250_addr)
    :i2c.write_byte(i2c, @acc_addr)
    :i2c.end_transmission(i2c)
    :timer.sleep(20)
    :i2c.read_bytes(i2c, @mpu9250_addr, @num_byte)
  end

  defp get_temp_value(temp) do
    round((temp - @temp_offset) * @temp_sens + 21)
  end
end
