# Elixir Reference — Advanced & Ecosystem Topics (Addendum)

> Topics beyond the core language comparison, sourced from
> [hexdocs.pm/elixir](https://hexdocs.pm/elixir),
> [elixir-lang.org/learning](https://elixir-lang.org/learning.html),
> and the [Mix & OTP guide](https://hexdocs.pm/elixir/introduction-to-mix.html).

---

## 37. OTP Supervision Trees

```elixir
children = [
  MyApp.Cache,
  MyApp.Worker
]

Supervisor.start_link(children, strategy: :one_for_one)
```

### Strategies

| Strategy | Behaviour |
|----------|-----------|
| `:one_for_one` | Restart only the crashed child |
| `:one_for_all` | Restart all children when one crashes |
| `:rest_for_one` | Restart the crashed child and any started after it |
| `:simple_one_for_one` | (legacy — use `DynamicSupervisor` instead) |

### Why supervision matters

- Processes are isolated — a crash in one doesn't corrupt others.
- Supervisors catch exit signals and restart children.
- This is the foundation of OTP fault tolerance ("let it crash").

### Child specification

```elixir
%{
  id: MyApp.Worker,
  start: {MyApp.Worker, :start_link, [arg1]},
  restart: :permanent,        # :permanent | :temporary | :transient
  shutdown: 5_000,            # max time for graceful shutdown
  type: :worker               # :worker | :supervisor
}
```

In practice, modules that `use GenServer`, `use Agent`, etc. define a `child_spec/1` function, so you can just list the module:

```elixir
children = [
  MyApp.Worker   # expands to {MyApp.Worker, []}
]
```

---

## 38. Application Lifecycle

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MyApp.Repo,
      MyApp.Cache
    ]

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      name: MyApp.Supervisor
    )
  end
end
```

The `start/2` callback must return `{:ok, pid}` or `{:ok, pid, state}`.

The `_type` argument is one of:
- `:permanent` — VM stops if the application terminates
- `:transient` — normal termination is ignored
- `:temporary` — any termination is ignored

In `mix.exs`:
```elixir
def application do
  [mod: {MyApp.Application, []}, extra_applications: [:logger]]
end
```

### Application callbacks

```elixir
@impl true
def start(_type, _args) do ... end

@impl true
def config_change(changed, _new, _removed) do
  MyApp.Config.reconfigure(changed)
  :ok
end

@impl true
def prep_stop(state) do
  # called before shutdown
  state
end

@impl true
def stop(state) do
  # cleanup
  :ok
end
```

---

## 39. DynamicSupervisor

Use when children are started dynamically at runtime (not known at compile time).

```elixir
defmodule MyApp.WorkerSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
```

Starting a child dynamically:

```elixir
DynamicSupervisor.start_child(
  MyApp.WorkerSupervisor,
  {MyApp.Worker, device_id}
)
```

Common use cases:
- Per-device processes (IoT, sensors)
- WebSocket connection handlers
- Per-request workers
- Ephemeral background jobs

---

## 40. Registry

A local process registry (replaces the need for `:global` or manual name registration for dynamic processes).

```elixir
# In supervision tree:
children = [
  {Registry, keys: :unique, name: MyApp.Registry}
]
```

### Operations

```elixir
# Register
Registry.register(MyApp.Registry, "device-1", %{meta: "data"})

# Lookup
Registry.lookup(MyApp.Registry, "device-1")
# => [{pid, %{meta: "data"}}]

# Match (value-based lookup)
Registry.match(MyApp.Registry, %{meta: "data"})

# Unregister
Registry.unregister(MyApp.Registry, "device-1")

# List keys
Registry.keys(MyApp.Registry, pid)
```

Options:
- `keys: :unique` — each key maps to one pid
- `keys: :duplicate` — same key can map to multiple pids

---

## 41. ETS (Erlang Term Storage)

Same ETS as Erlang, called via `:ets`. Still the primary in-memory key-value store on BEAM.

```elixir
# Create
table = :ets.new(:cache, [:set, :public, :named_table])

# Insert
:ets.insert(:cache, {:user, 123, "John"})

# Lookup
:ets.lookup(:cache, :user)
# => [{:user, 123, "John"}]

# Pattern match
:ets.match(:cache, {:"$1", :"$2", :"$3"})

# Delete
:ets.delete(:cache, :user)
```

### Table types

| Type | Description |
|------|-------------|
| `:set` | One key, unique |
| `:ordered_set` | Ordered by key |
| `:bag` | Multiple entries per key, no duplicate tuples |
| `:duplicate_bag` | Multiple entries per key, duplicates allowed |

### Ownership

- Tables created with `:public` can be read/written by any process.
- Tables created by a process are deleted when that process dies (unless ownership is transferred via `:ets.give_away/3`).

---

## 42. Typespecs

```elixir
@type user_id :: integer()

@spec get_user(user_id()) :: {:ok, User.t()} | {:error, :not_found}

@spec all_users() :: [User.t()]

@opaque internal_state :: %{counter: integer()}
```

### Built-in types

| Type | Description |
|------|-------------|
| `any()` | Any type |
| `atom()` | Atom |
| `integer()` | Integer |
| `float()` | Float |
| `number()` | Integer or float |
| `String.t()` | String (binary) |
| `boolean()` | `true \| false` |
| `pid()` | Process identifier |
| `term()` | Any term (same as `any()`) |
| `Keyword.t(val)` | Keyword list with values of type `val` |

### Union types

```elixir
@type result :: {:ok, any()} | {:error, String.t()}
```

### Parameterised types

```elixir
@type option(a) :: nil | a
```

### `t()` shortcut

Inside a module `MyApp.User`, the type `t()` refers to the struct type:

```elixir
@spec get(integer()) :: MyApp.User.t()
# or just t() inside the module
```

---

## 43. Behaviours

Elixir's equivalent of Erlang behaviours (like `gen_server`).

```elixir
defmodule Storage do
  @callback put(term(), term()) :: :ok
  @callback get(term()) :: term()
  @optional_callbacks [delete: 1]

  defmacro __using__(_opts) do
    quote do
      @behaviour Storage
    end
  end
end
```

### Implementation

```elixir
defmodule ETSStorage do
  @behaviour Storage

  @impl true
  def put(k, v), do: :ok

  @impl true
  def get(k), do: nil
end
```

### Defining behaviours with default implementations

```elixir
defmodule Parser do
  @callback parse(String.t()) :: {:ok, term()} | {:error, String.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Parser
    end
  end

  def parse!(string) do
    case parse(string) do
      {:ok, result} -> result
      {:error, reason} -> raise "Parse error: #{reason}"
    end
  end
end
```

---

## 44. Dialyzer

A static analysis tool that finds type mismatches and unreachable code using typespecs.

### Setup

In `mix.exs`:

```elixir
defp deps do
  [
    {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
  ]
end
```

### Usage

```bash
mix deps.get
mix dialyzer
```

### What it finds

- Impossible pattern matches
- Return type violations
- Unreachable code
- Dead code paths
- Unnecessary guards

### PLT cache

Dialyzer builds a Persistent Lookup Table (PLT) for all dependencies on first run. Subsequent runs are faster.

```bash
mix dialyzer --plt   # build/update PLT explicitly
```

---

## 45. Logger

```elixir
require Logger

Logger.debug("entered loop")
Logger.info("server started on port #{port}")
Logger.warning("disk space low")
Logger.error("connection refused: #{inspect(reason)}")
```

### Why `require Logger`

`Logger` uses macros — each log level is compiled away in production when the level is disabled:
```elixir
# In config:
config :logger, level: :warning
# Now debug/info calls are no-ops at compile time
```

### Logger backends

```elixir
config :logger, backends: [:console]

# Custom backend
config :logger, backends: [MyApp.LoggerFileBackend]
```

### Metadata

```elixir
Logger.info("request processed",
  request_id: req.id,
  duration: elapsed
)
```

---

## 46. OTP Behaviours Overview

| Behaviour | Purpose |
|-----------|---------|
| `Application` | Application entry point and lifecycle |
| `Supervisor` | Static supervision tree (children known at compile time) |
| `DynamicSupervisor` | Dynamic children (started at runtime) |
| `GenServer` | Stateful server process (generic server) |
| `Agent` | Simple wrapper around state (no message handling needed) |
| `Task` | Asynchronous computation (one-shot process) |
| `Registry` | Local process registry (name → pid lookup) |

### When to use what

| Need | Solution |
|------|----------|
| State you read/write | `Agent` |
| State + messages + logic | `GenServer` |
| Fire-and-forget async | `Task.start` / `Task.start_link` |
| Get a result from async | `Task.async` / `Task.await` |
| Fixed set of children | `Supervisor` |
| Dynamic children | `DynamicSupervisor` |
| Named process lookup | `Registry` |

---

## 47. Runtime vs Compile-Time Config

```elixir
# Compile-time: raises if key is missing
@port Application.compile_env(:my_app, :port)

# Runtime: returns nil if key is missing
port = Application.get_env(:my_app, :port)

# Runtime with default
port = Application.get_env(:my_app, :port, 8080)
```

### Config files (`config/*.exs`)

```elixir
# config/config.exs (shared)
import Config
config :my_app, :port, 8080

# config/dev.exs
import Config
config :my_app, :port, 4000

# config/prod.exs
import Config
config :my_app, :port, String.to_integer(System.get_env("PORT", "8080"))
```

In `mix.exs`:

```elixir
def project do
  [
    ...
    config_path: "config/config.exs"  # imports env-specific files
  ]
end
```

### Rule

- Use `compile_env` only in module attributes for values affecting compilation.
- Use `get_env` for runtime lookups.
- Never call `Mix.env()` in application code — use `config/*.exs` files.

---

## 48. Modern Project Layout

```
lib/
  my_app.ex
  application.ex

  accounts/
    user.ex
    accounts.ex       # context module (public API)

  devices/
    device.ex
    device_server.ex
    device_supervisor.ex

config/
  config.exs
  dev.exs
  prod.exs
  runtime.exs         # evaluated at release start

test/
  test_helper.exs
  my_app_test.exs

priv/
  static/             # assets, migrations, etc.

mix.exs
.formatter.exs
```

---

## 49. GenServer In Depth

### Client functions

```elixir
defmodule MyApp.Queue do
  use GenServer

  # Client
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put(opts, :name, __MODULE__))
  end

  def push(pid, item) do
    GenServer.cast(pid, {:push, item})
  end

  def pop(pid) do
    GenServer.call(pid, :pop, :timer.seconds(5))  # with timeout
  end

  # Server
  @impl true
  def init(:ok) do
    {:ok, []}
  end

  @impl true
  def handle_call(:pop, _from, [head | tail]) do
    {:reply, {:ok, head}, tail}
  end

  def handle_call(:pop, _from, []) do
    {:reply, :empty, []}
  end

  @impl true
  def handle_cast({:push, item}, state) do
    {:noreply, state ++ [item]}
  end
end
```

### Multi-call / multi-cast

```elixir
# Send to multiple servers
[pid1, pid2] |> Enum.each(&GenServer.cast(&1, msg))
```

### Monitoring

```elixir
# Monitor a process
ref = Process.monitor(pid)

# receive handle_info for :DOWN messages
@impl true
def handle_info({:DOWN, ref, :process, pid, reason}, state) do
  {:noreply, state}
end
```

### Replies

```elixir
# Standard reply
{:reply, value, state}

# No reply (the caller blocks until server replies separately)
{:noreply, state}

# Stop
{:stop, :normal, state}
{:stop, reason, reply, state}

# Continue with a timeout
{:reply, value, state, :timer.seconds(30)}

# Continue after processing the mailbox
{:reply, value, state, :hibernate}
```

---

## 50. Task (Async)

### Fire-and-forget

```elixir
Task.start(fn -> do_work() end)
Task.start_link(fn -> do_work() end)  # linked to caller
```

### Getting results

```elixir
task = Task.async(fn ->
  # expensive computation
  result
end)

other_result = do_something_else()

final = Task.await(task)   # default timeout: 5_000ms
```

### Multiple async tasks

```elixir
tasks =
  [:foo, :bar, :baz]
  |> Enum.map(fn key -> Task.async(fn -> fetch(key) end) end)

results = Enum.map(tasks, &Task.await/1)
```

Or use `Task.async_stream`:

```elixir
[:foo, :bar, :baz]
|> Task.async_stream(&fetch/1, max_concurrency: 3, timeout: 10_000)
|> Enum.to_list()
# => [{:ok, result1}, {:ok, result2}, ...]
```

### Supervised tasks

```elixir
children = [
  {Task, fn -> :timer.sleep(:infinity) end}
]
```

---

## 51. Agent

Simplest OTP behaviour — a process that holds state. No need to write `handle_call`/`handle_cast`.

```elixir
# Start
{:ok, pid} = Agent.start_link(fn -> %{} end)

# Update
Agent.update(pid, fn map -> Map.put(map, :key, "value") end)

# Get
value = Agent.get(pid, fn map -> Map.get(map, :key) end)

# Get and update atomically
Agent.get_and_update(pid, fn map ->
  {Map.get(map, :key), Map.put(map, :key, "new_value")}
end)
```

### Named Agent

```elixir
Agent.start_link(fn -> %{} end, name: :my_agent)
Agent.get(:my_agent, & &1)
```

### When to use Agent vs GenServer

| Use Agent when... | Use GenServer when... |
|------------------|----------------------|
| State is simple (map, list, number) | State needs validation |
| No custom message handling | You handle messages beyond state |
| No need for callbacks on init/terminate | You need init/terminate callbacks |
| Minimal boilerplate | You need to handle monitors/timeouts |

---

## 52. Metaprogramming (Macros)

### quote / unquote

```elixir
defmodule MyMacros do
  defmacro double(expr) do
    quote do
      unquote(expr) * 2
    end
  end
end
```

### What `quote` returns (AST)

```iex
iex> quote do: 1 + 2
{:+, [context: Elixir, import: Kernel], [1, 2]}
```

### unquote — inject values into quoted expressions

```elixir
defmodule Math do
  defmacro multiply(x, y) do
    quote do
      unquote(x) * unquote(y)
    end
  end
end
```

### Module attributes as accumulation

```elixir
defmodule MyModule do
  Module.register_attribute(__MODULE__, :items, accumulate: true)
  @items :a
  @items :b

  def items, do: @items    # [:b, :a] (reverse order of definition)
end
```

### defmodule inside a macro

```elixir
defmacro define_handler(name, do: body) do
  quote do
    def unquote(name)(env) do
      unquote(body)
    end
  end
end
```

### Hygiene

Elixir macros are hygienic — variables defined inside `quote` don't leak:

```elixir
defmodule Hyg do
  defmacro hygienic do
    quote do
      x = 1
    end
  end
end

x = 0
Hyg.hygienic()
x  # still 0
```

Use `var!` to bypass hygiene:

```elixir
quote do
  var!(x) = 1
end
```

### When NOT to use macros

> Prefer functions, `alias`, `import`, and `use` before writing macros.
> Macros make code harder to read, debug, and compose.

---

## 53. Writing Documentation

### Module docs

```elixir
defmodule MyApp do
  @moduledoc """
  Documentation for `MyApp`.

  ## Examples

      iex> MyApp.hello()
      :world

  """
end
```

### Function docs

```elixir
@doc """
Calculates the sum of two numbers.

## Examples

    iex> Math.sum(1, 2)
    3

"""
def sum(a, b), do: a + b
```

### Doctests

```elixir
defmodule MathTest do
  use ExUnit.Case
  doctest Math    # runs examples from @doc as tests
end
```

### Running documentation tests

```bash
mix test
```

### ExDoc

Generate HTML docs:

```bash
mix docs
```

Output in `doc/` directory. Published to [hexdocs.pm](https://hexdocs.pm).

---

## 54. Naming Conventions

| Rule | Example |
|------|---------|
| Modules: `PascalCase` | `MyApp.Accounts.User` |
| Functions/variables: `snake_case` | `calculate_total/1` |
| Predicate functions: trailing `?` | `valid?/1`, `nil?/1` |
| Raising variants: trailing `!` | `File.read!/1` (raises on error) |
| Private functions: `defp` | `defp do_format(data)` |
| Unused variables: prefix `_` | `_head` or just `_` |
| Constants: `@` module attributes | `@max_retries 3` |
| Struct fields: atom keys | `%User{name: "John", age: 27}` |
| Source files: `snake_case.ex` | `my_app/accounts/user.ex` |

---

## 55. Releases

### Building

```bash
mix release
```

Output in `_build/prod/rel/my_app/`.

### Running

```bash
_build/prod/rel/my_app/bin/my_app start       # daemon
_build/prod/rel/my_app/bin/my_app start_iex   # with IEx attached
_build/prod/rel/my_app/bin/my_app eval "IO.puts(1+1)"  # one-off
```

### Release config

```elixir
# mix.exs
def releases do
  [
    my_app: [
      include_executables_for: [:unix],
      steps: [:assemble, :tar],
      config_providers: [
        {Config.Provider.SystemEnv, []}
      ]
    ]
  ]
end
```

### Why releases

- Self-contained (includes ERTS + Elixir + deps)
- No Mix dependency at runtime
- Config files evaluated at release time (`config/runtime.exs`)
- Versioned, can be rolled back

---

## 56. Ecto Basics

### Schema

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema

  schema "users" do
    field :name, :string
    field :email, :string
    field :age, :integer, default: 0
    timestamps()     # adds inserted_at, updated_at
  end
end
```

### Changeset

```elixir
def changeset(user, attrs) do
  user
  |> Ecto.Changeset.cast(attrs, [:name, :email, :age])
  |> Ecto.Changeset.validate_required([:name, :email])
  |> Ecto.Changeset.validate_format(:email, ~r/@/)
  |> Ecto.Changeset.validate_length(:name, min: 2)
end
```

### Queries

```elixir
# Get by primary key
MyApp.Repo.get(User, 1)

# Insert
%User{}
|> User.changeset(%{name: "John", email: "john@example.com"})
|> MyApp.Repo.insert()

# Query
import Ecto.Query

MyApp.Repo.all(from u in User, where: u.age > 18, select: u.name)

# Pipe-friendly
User
|> where([u], u.age > 18)
|> order_by([u], desc: u.age)
|> MyApp.Repo.all()
```

### Important modules

| Module | Purpose |
|--------|---------|
| `Ecto.Schema` | Define data shapes |
| `Ecto.Changeset` | Validate and cast data |
| `Ecto.Query` | Composable database queries |
| `Repo` | Database interface (your module that `use Ecto.Repo`) |

---

## 57. Phoenix Ecosystem

### Core components

| Component | Purpose |
|-----------|---------|
| **Phoenix** | Web framework (MVC, channels, live reload) |
| **Phoenix LiveView** | Real-time UI, HTML-over-WebSocket (no JS SPA) |
| **Plug** | Request/response pipeline (like Rack/WAI) |
| **Ecto** | Database wrapper + query language |
| **Phoenix PubSub** | Distributed pub/sub for LiveView + channels |
| **Phoenix Channels** | WebSocket-based bidirectional communication |

### Typical request flow

```text
Browser
  -> Endpoint (cowboy/bandit)
  -> Router (phoenix router)
  -> Plug pipeline (parsers, session, CSRF)
  -> Controller / LiveView
  -> Context (business logic)
  -> Ecto (database)
  -> Response (HTML / JSON / LiveView diff)
```

### Phoenix generators

```bash
mix phx.new my_app          # new project
mix phx.gen.html Accounts User users name:string age:integer
mix phx.gen.json Api User users name:string
mix phx.gen.live Blog Post posts title:string body:text
```

### Why Phoenix

- **LiveView**: real-time UI without writing JavaScript
- **PubSub**: built-in distributed messaging
- **OTP-backed**: WebSocket connections are BEAM processes
- **Fault-tolerant**: supervisors restart channels/connections
- **Scalable**: 2M connections on a single machine

---

## 58. Telemetry

A library for emitting and consuming metrics/events. It is the standard instrumentation mechanism in the Elixir ecosystem.

### Emitting events

```elixir
:telemetry.execute(
  [:my_app, :request, :done],
  %{duration: elapsed_ms},
  %{path: req.path, method: req.method}
)
```

### Attaching handlers

```elixir
:telemetry.attach(
  "my-handler-id",
  [:my_app, :request, :done],
  fn event_name, measurements, metadata, _config ->
    IO.puts("Request to #{metadata.path} took #{measurements.duration}ms")
  end,
  nil
)
```

### Span events

```elixir
:telemetry.span([:my_app, :db_query], metadata, fn ->
  result = do_query()
  {result, %{rows: length(result)}}
end)
```

### Common integrations

- OpenTelemetry (`:opentelemetry` / `:opentelemetry_exporter`)
- Prometheus (`:prom_ex`)
- `Logger` metadata
- LiveDashboard metrics

### Libraries that use Telemetry

- Phoenix (request duration, liveview metrics)
- Ecto (query timing, connection pool)
- Broadway (message processing)
- Finch (HTTP client)

---

## 59. Config Providers

Config providers allow runtime configuration from external sources (env vars, files, Vault).

### System environment provider

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  config :my_app, MyApp.Repo,
    username: System.fetch_env!("DB_USERNAME"),
    password: System.fetch_env!("DB_PASSWORD"),
    database: System.fetch_env!("DB_NAME"),
    hostname: System.fetch_env!("DB_HOST")
end
```

### Custom config provider

```elixir
defmodule MyApp.ConfigProvider do
  @behaviour Config.Provider

  @impl true
  def init(term), do: term

  @impl true
  def load(config, opts) do
    json = MyApp.Vault.read("secret/my_app")

    new_config =
      Config.Reader.merge(
        config,
        my_app: [
          api_key: json["api_key"],
          port: json["port"]
        ]
      )

    {:ok, new_config}
  end
end
```

(Note: this needs to work without application dependencies loaded.)

---

## 60. Nerves (Embedded / IoT)

Nerves is the Elixir framework for embedded systems (Raspberry Pi, BeagleBone, etc.).

```elixir
# mix.exs
def deps do
  [
    {:nerves, "~> 1.10", runtime: false},
    {:shoehorn, "~> 0.9"},
    {:ring_logger, "~> 0.10"},
    {:toolshed, "~> 0.4"}
  ]
end
```

### Key concepts

- **Firmware**: Builds a minimal Linux image with the BEAM + your app
- **Shoehorn**: Controls the application boot sequence
- **RingLogger**: In-memory ring buffer logger for devices without disks
- **Toolshed**: IEx helpers for GPIO, I2C, UART, etc.
- **VintageNet**: Network configuration (WiFi, Ethernet)

### Typical Nerves flow

```bash
mix firmware        # build firmware image
mix firmware.burn   # write to SD card
mix upload          # upload over network
```

---

## 61. Nx + Livebook (Numerical Computing / Notebooks)

### Nx — Numerical Elixir

```elixir
# mix.exs
def deps do
  [{:nx, "~> 0.9"}]
end

tensor = Nx.tensor([[1, 2], [3, 4]])
Nx.add(tensor, Nx.tensor([[5, 6], [7, 8]]))

# BinaryElementwiseAdd
Nx.dot(tensor, Nx.transpose(tensor))   # matrix multiply
```

### Livebook — Interactive notebooks

- Run Elixir code in browser notebooks (like Jupyter)
- Built-in visualization (charts, tables, markdown)
- Works with Nx, Explorer (dataframes), VegaLite (charts)
- Used for data science, ML documentation, and teaching

### EXLA — XLA backend

```elixir
def deps do
  [
    {:nx, "~> 0.9"},
    {:exla, "~> 0.9"}
  ]
end

Nx.default_backend(EXLA.Backend)
# GPU/TPU accelerated tensor operations
```

---

## 62. Broadway (Data Pipelines)

A concurrent, multi-stage data processing library with built-in batching, rate-limiting, and acknowledgements.

```elixir
defmodule MyApp.Pipeline do
  use Broadway

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwayRabbitMQ.Producer, queue: "orders"},
        concurrency: 2
      ],
      processors: [
        default: [concurrency: 10]
      ],
      batchers: [
        default: [batch_size: 50, batch_timeout: 1_000]
      ]
    )
  end

  @impl true
  def handle_message(_processor, message, _context) do
    message
    |> Broadway.Message.update_data(&process_order/1)
  end

  @impl true
  def handle_batch(_batcher, messages, _batch_info, _context) do
    MyApp.Repo.insert_all(Order, Enum.map(messages, & &1.data))
    messages
  end
end
```

### Supported producers

- **BroadwayRabbitMQ** (RabbitMQ / AMQP)
- **BroadwayKafka** (Apache Kafka)
- **BroadwaySQS** (AWS SQS)
- **BroadwayDashboard** (custom dashboard)
- Custom producers via `Broadway.Producer` behaviour

---

## 63. OTP Cheat Sheet

| Action | Code |
|--------|------|
| Start a GenServer | `GenServer.start_link(__MODULE__, args, name: :name)` |
| Call (waits for reply) | `GenServer.call(pid, msg, timeout)` |
| Cast (no reply) | `GenServer.cast(pid, msg)` |
| Reply outside handle_call | `GenServer.reply(from, value)` |
| Send raw message | `send(pid, msg)` |
| Monitor process | `ref = Process.monitor(pid)` |
| Demonitor | `Process.demonitor(ref, [:flush])` |
| Link | `Process.link(pid)` |
| Spawn linked | `spawn_link(fn -> ... end)` |
| Register name | `Process.register(pid, :name)` |
| Lookup name | `Process.whereis(:name)` |
| Start supervisor | `Supervisor.start_link(children, strategy: :one_for_one)` |
| Add child dynamically | `DynamicSupervisor.start_child(sup, {Worker, arg})` |
| Task async/await | `task = Task.async(fn -> ... end); Task.await(task)` |
| Agent (simple state) | `Agent.get(pid, & &1)` |
| Logger | `Logger.info("message")` (need `require Logger`) |

---

## 64. Community & Learning Resources

### Official

- [Getting Started Guide](https://hexdocs.pm/elixir/introduction.html) — language fundamentals
- [Mix & OTP Guide](https://hexdocs.pm/elixir/introduction-to-mix.html) — project structure, supervision, releases
- [API Docs](https://elixir-lang.org/docs.html) — fully searchable

### Books

| Book | Author | Focus |
|------|--------|-------|
| Elixir in Action (3rd ed.) | Saša Jurić | OTP, distributed systems |
| Programming Elixir 1.6 | Dave Thomas | Language intro for experienced devs |
| Adopting Elixir | Marx, Valim, Tate | Production adoption |
| Metaprogramming Elixir | Chris McCord | Macros, AST, DSLs |
| Designing Elixir Systems with OTP | Gray & Tate | System design with layers |
| Concurrent Data Processing in Elixir | Svilen Gospodinov | GenStage, Flow, Broadway |

### Free resources

- [Elixir School](https://elixirschool.com) — peer-reviewed lessons in 10+ languages
- [Exercism Elixir Track](https://exercism.org/tracks/elixir) — mentored practice
- [Elixir Koans](https://github.com/elixirkoans/elixir-koans) — learn by fixing tests
- [Joy of Elixir](https://joyofelixir.com) — gentle introduction for beginners
- [Alchemist Camp](https://alchemist.camp) — free screencasts (dozens of hours)
- [ElixirCasts](https://elixircasts.io) — free screencasts
- [Erlang in Anger](https://www.erlang-in-anger.com) — production debugging (free ebook)

### Courses

- [Pragmatic Studio Elixir/OTP](https://pragmaticstudio.com/elixir) — video course
- [grox.io Elixir & OTP](https://grox.io) — multi-format (book + video + projects)

### Tools

| Tool | Purpose |
|------|---------|
| [Hex.pm](https://hex.pm) | Package manager |
| [Livebook](https://livebook.dev) | Interactive notebooks |
| [Phoenix](https://phoenixframework.org) | Web framework |
| [Nerves](https://nerves-project.org) | Embedded/IoT |
| [Nx](https://github.com/elixir-nx/nx) | Numerical computing |
| [Broadway](https://elixir-broadway.org) | Data pipelines |
| [ExDoc](https://github.com/elixir-lang/ex_doc) | Documentation generator |
| [Dialyzer](https://erlang.org/doc/man/dialyzer.html) | Static analysis |

---

## 65. Complete Section Index

| # | Section | File |
|---|---------|------|
| 1–36 | Core Language (types, pattern matching, control flow, modules, GenServer, etc.) | `erlang_vs_elixir.md` |
| 37 | OTP Supervision Trees | This file |
| 38 | Application Lifecycle | This file |
| 39 | DynamicSupervisor | This file |
| 40 | Registry | This file |
| 41 | ETS | This file |
| 42 | Typespecs | This file |
| 43 | Behaviours | This file |
| 44 | Dialyzer | This file |
| 45 | Logger | This file |
| 46 | OTP Behaviours Overview | This file |
| 47 | Runtime vs Compile-Time Config | This file |
| 48 | Modern Project Layout | This file |
| 49 | GenServer In Depth | This file |
| 50 | Task (Async) | This file |
| 51 | Agent | This file |
| 52 | Metaprogramming (Macros) | This file |
| 53 | Writing Documentation | This file |
| 54 | Naming Conventions | This file |
| 55 | Releases | This file |
| 56 | Ecto Basics | This file |
| 57 | Phoenix Ecosystem | This file |
| 58 | Telemetry | This file |
| 59 | Config Providers | This file |
| 60 | Nerves (Embedded/IoT) | This file |
| 61 | Nx + Livebook (Numerical) | This file |
| 62 | Broadway (Data Pipelines) | This file |
| 63 | OTP Cheat Sheet | This file |
| 64 | Community & Learning Resources | This file |
