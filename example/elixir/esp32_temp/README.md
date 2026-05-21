# Esp32Temp

```
ESP32 -> HTTP POST -> Phoenix(Elixir) -> LiveView Web
```

```
ESP32
  |
HTTP POST
  |
Phoenix API
  |
PubSub
  |
LiveView dashboard
```

## Create a new Phoenix project

```bash
mix archive.install hex phx_new
mix phx.new esp32_temp --live
```

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

## API Endpoint

The ESP32 sends temperature data to this endpoint:

```
POST /api/temperature
Content-Type: application/json

{"temperature": 35}
```

The controller (`Esp32TempWeb.TemperatureController`) broadcasts the value to the dashboard via PubSub.

### Router

Key routes (see `lib/esp32_temp_web/router.ex`):

| Method | Path               | Handler                          |
|--------|--------------------|----------------------------------|
| GET    | `/`                | `DashboardLive`                  |
| GET    | `/temperatures`    | `TemperatureLive.Index :index`   |
| POST   | `/api/temperature` | `TemperatureController :create`  |

### Dashboard (LiveView)

Visit `http://<your-lan-ip>:4000/` to see real-time temperature updates via LiveView WebSocket.

The dashboard (`DashboardLive`) subscribes to the `"temperature"` PubSub topic on mount. When the ESP32 posts a new reading, the controller broadcasts it and the dashboard updates instantly without page refresh.

### Temperature CRUD (LiveView)

| Route                | Page            |
|----------------------|-----------------|
| `/temperatures`      | List all records |
| `/temperatures/new`  | Create new      |
| `/temperatures/:id`  | Show detail     |
| `/temperatures/:id/edit` | Edit       |

These pages use LiveView streams for efficient list rendering (insert/delete without full re-render).

### Key files modified

| File                              | What changed                                      |
|-----------------------------------|---------------------------------------------------|
| `router.ex`                       | Added TemperatureLive routes, moved API to main scope |
| `temperature_controller.ex`       | `POST /api/temperature` — receives ESP32 data     |
| `dashboard_live.ex`               | Subscribes PubSub, displays live temperature       |
| `dashboard_live.html.heex`        | Simple UI showing `@temperature °C`                |
| `temperature_live/index.ex`       | List temperatures with stream delete               |
| `temperature_live/show.ex`        | Show single temperature record                     |
| `temperature_live/form.ex`        | Create/edit temperature form                       |

### UI Highlights

- Real-time updates via WebSocket (no polling)
- LiveView streams for smooth list operations
- Phoenix flash messages for success/error feedback
- Tailwind CSS responsive design

### Quick start

```bash
mix setup
mix phx.server
```

Make sure Docker port is exposed on your LAN:

```bash
docker run -p 4000:4000 ...
```

## Future expansion ideas (learning web)

| Idea | Skills to learn |
|------|-----------------|
| **Store temperature in database** | Ecto, migrations, Postgres queries |
| **Temperature history chart** | Chart.js, Alpine.js, LiveView hooks |
| **Auth & user accounts** | Phoenix auth generator, session, plugs |
| **Email alerts on high temp** | Swoosh mailer, background jobs |
| **Real-time alerts (SMS/Telegram)** | Webhooks, 3rd-party API integration |
| **Full REST API** | JSON API design, pagination, versioning |
| **Multi-sensor dashboard** | Ecto associations, complex queries |
| **Deploy to VPS** | Docker compose, Caddy/Nginx, production config |
| **CI/CD pipeline** | GitHub Actions, tests, auto-deploy |
| **Multiple ESP32 devices** | Device auth, unique IDs, channel grouping |
| **OTA firmware update for ESP32** | AtomVM OTA, file upload, device management |

Verify from another machine:

```bash
curl http://<your-lan-ip>:4000/api/temperature -X POST \
  -H "Content-Type: application/json" \
  -d '{"temperature":31.5}'
```
