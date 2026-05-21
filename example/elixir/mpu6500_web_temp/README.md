# Mpu6500WebTemp

Reads temperature from MPU6500 sensor on ESP32 via I2C and sends it to a web server via HTTP POST.

## Setup

1. **Set WiFi credentials** in `lib/mpu6500_web_temp.ex`:

```elixir
@wifi_ssid "your_wifi_ssid"
@wifi_passphrase "your_wifi_password"
```

2. **Set server address** (your machine's LAN IP, from `ip addr show`):

```elixir
@server_host '192.168.1.x'
@server_port 4000
```

3. **Install dependencies and build**:

```bash
mix deps.get && mix atomvm.packbeam
```

## Flash to ESP32

```bash
mix atomvm.esp32.flash --port /dev/ttyUSB0
```

To monitor serial output:

```bash
minicom -D /dev/ttyUSB0
```

## How it works

1. ESP32 connects to WiFi
2. Reads temperature from MPU6500 sensor via I2C (GPIO 22 SCL, GPIO 21 SDA)
3. Sends `POST /api/temperature` with `{"temperature": <value>}` as JSON
4. Repeats every 3 seconds
