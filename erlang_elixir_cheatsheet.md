# Erlang ↔ Elixir Cheat Sheet

---

## Syntax

| Erlang | Elixir |
|--------|--------|
| `-module(foo).` | `defmodule Foo do` |
| `-export([f/1]).` | `def f(x) do ... end` |
| (private = omit from export) | `defp f(x) do ... end` |
| `-behaviour(gen_server).` | `use GenServer` |
| `-record(s, {a, b}).` | `defstruct [:a, :b]` |
| `-define(X, 42).` | `@x 42` |
| `-include("foo.hrl").` | (no include — use modules) |
| `-type x() :: integer().` | `@type x :: integer` |
| `-spec f(integer()) -> ok.` | `@spec f(integer()) :: :ok` |
| `-import(lists, [map/2]).` | `import List, only: [map: 2]` |
| (none) | `alias Foo.Bar` |
| (none) | `use GenServer` |
| (none) | `@impl true` |

---

## Data Types

| Concept | Erlang | Elixir |
|---------|--------|--------|
| Integer | `42` | `42` |
| Float | `3.14` | `3.14` |
| Atom | `ok` | `:ok` |
| Boolean | `true`, `false` | `true`, `false` |
| Nil | `undefined` | `nil` |
| String | `"abc"` (charlist) | `"abc"` (UTF-8 binary) |
| Charlist | `[97,98,99]` | `~c"abc"` or `'abc'` |
| Binary | `<<"abc">>` | `"abc"` or `<<97,98,99>>` |
| Tuple | `{a, b}` | `{:a, :b}` |
| List | `[a, b]` | `[:a, :b]` |
| Map | `#{k => v}` | `%{k: v}` |
| Struct | `#r{a=1}` | `%R{a: 1}` |

---

## Variables & Binding

| Erlang | Elixir |
|--------|--------|
| `X = 1` | `x = 1` |
| `X = 2` (crash — can't rebind) | `x = 2` (rebinds) |
| Match existing: `X` already bound | `^x = 2` (pin operator) |
| `_Unused` | `_unused` or `_` |

---

## Literals & Numbers

| Erlang | Elixir |
|--------|--------|
| `16#FF` | `0xFF` |
| `2#1010` | `0b1010` |
| `8#777` | `0o777` |
| `$A` (65) | `?A` (65) |
| `1.0e-10` | `1.0e-10` |
| (none) | `1_000_000` (underscore separator) |

---

## Operators

| Operation | Erlang | Elixir |
|-----------|--------|--------|
| Add | `A + B` | `a + b` |
| Subtract | `A - B` | `a - b` |
| Multiply | `A * B` | `a * b` |
| Float divide | `A / B` | `a / b` (always returns float) |
| Integer divide | `A div B` | `div(a, b)` |
| Remainder | `A rem B` | `rem(a, b)` |
| List prepend | `[H \| T]` | `[h \| t]` |
| List concat | `A ++ B` | `a ++ b` |
| List subtract | `A -- B` | `a -- b` |
| Binary concat | `<<A/binary, B/binary>>` | `a <> b` |
| String concat | (same as list) | `a <> b` |

### Comparison

| Erlang | Elixir |
|--------|--------|
| `A == B` | `a == b` |
| `A =:= B` (strict) | `a === b` |
| `A /= B` | `a != b` |
| `A =/= B` | `a !== b` |
| `A < B` | `a < b` |
| `A > B` | `a > b` |

### Bitwise

| Erlang | Elixir |
|--------|--------|
| `X band Y` | `x &&& y` |
| `X bor Y` | <code>x \|\|\| y</code> |
| `X bxor Y` | `x ^^^ y` |
| `bnot X` | `~~~x` |
| `X bsl N` | `x <<< n` |
| `X bsr N` | `x >>> n` |

> Bitwise ops need `import Bitwise` at top of module.

### Boolean / Logical

| Erlang | Elixir |
|--------|--------|
| `not X` | `not x` |
| `X and Y` (strict) | `x and y` |
| `X orelse Y` | <code>x \|\| y</code> |
| (none) | `x && y` (relaxed) |
| (none) | `!x` (relaxed not) |

> Strict: expects booleans. Relaxed: `false`/`nil` are falsy, everything else truthy.

---

## Control Flow

| Erlang | Elixir |
|--------|--------|
| `case X of ... end` | `case x do ... end` |
| `if ...; true -> ... end` | `cond do ... true -> ... end` (3+ branches) |
| `if X -> ... end` | `if x, do: ... else: ... end` |
| (none) | `unless x, do: ...` |
| (none) | `with ... <- ..., do: ... else: ... end` |
| `after` | `after` (same) |
| `try ... of ... catch _:_ ->` | `try do ... rescue _ -> ... end` |
| `throw(X)` | `throw(x)` |
| `exit(R)` | `exit(reason)` |

### `with` — chain pattern matches (no Erlang equivalent)

```elixir
with {:ok, user} <- get_user(id),
     {:ok, order} <- create_order(user) do
  {:ok, order}
else
  {:error, reason} -> {:error, reason}
end
```

Avoids deeply nested `case` expressions. Most common Elixir pattern for multi-step operations.

---

## Atoms, Strings, Binaries

| Erlang | Elixir |
|--------|--------|
| `ok` | `:ok` |
| `"hello"` (charlist) | `"hello"` (binary) |
| `<<"hello">>` | `"hello"` |
| `io:format("~p",[X])` | `IO.inspect(x)` |
| `io:format("val ~p",[X])` | `"val \#{x}"` (interpolation) |
| `lists:reverse(L)` | `Enum.reverse(l)` |

### Sigils

| Sigil | Meaning |
|-------|---------|
| `~r/foo/i` | Regex |
| `~c"hello"` | Charlist (like Erlang `"hello"`) |
| `~s"hello"` | String (with escapes) |
| `~S"hello"` | Raw string (no escapes) |
| `~w(foo bar)a` | Word list as atoms |
| `~D[2024-01-01]` | Date |
| `~T[10:00:00]` | Time |
| `~N[2024-01-01 10:00:00]` | NaiveDateTime |
| `~U[2024-01-01 10:00:00Z]` | DateTime UTC |

---

## Pattern Matching

| Erlang | Elixir |
|--------|--------|
| `{ok, X} = ...` | `{:ok, x} = ...` |
| `[H\|T] = List` | `[h \| t] = list` |
| `#r{k = V}` (record) | `%R{k: v} = struct` |
| `#{k := V}` (map) | `%{k: v} = map` |
| (none — rebinds) | `^x` (pin to match existing) |

---

## Functions

| Erlang | Elixir |
|--------|--------|
| `fun(X) -> X*2 end` | `fn x -> x * 2 end` |
| `fun f/1` | `&f/1` |
| `fun m:f/1` | `&M.f/1` |
| (none) | `&(&1 + 1)` (capture shorthand) |
| Call fun: `F(1)` | Call fun: `f.(1)` (note `.`) |
| `lists:map(Fun, L)` | `Enum.map(list, fun)` |

---

## Calling Erlang from Elixir

```elixir
:erlang.system_flag(:schedulers_online, 2)
:timer.sleep(100)
:math.pow(2, 10)
:ets.new(:table, [:set, :public])
:ledc.timer_config(config)
I2C.open(scl: 22, sda: 21)
GPIO.set_pin_mode(4, :output)
```

> Rule: `erlang_module:function(args)` → `:erlang_module.function(args)`

---

## Maps

| Erlang | Elixir |
|--------|--------|
| `#{}` | `%{}` |
| `#{k => v}` | `%{k: v}` (atom keys) |
| `maps:get(K, M)` | `map.key` (atom keys, compile-time) / `map[:key]` (any key, runtime) / `Map.get(map, :key, default)` |
| `M#{k := new}` | `%{map \| key: new}` |
| `maps:keys(M)` | `Map.keys(map)` |

---

## Records vs Structs

| Erlang | Elixir |
|--------|--------|
| `-record(s, {a, b}).` | `defstruct [:a, :b]` |
| `R#s.a` | `r.a` |
| `R#s{a = 1}` | `%{r \| a: 1}` |
| `#s{a = 1}` | `%S{a: 1}` |
| No compile check | Compile-time key check, `@enforce_keys` |

---

## Modules & Aliases

| Erlang | Elixir |
|--------|--------|
| `module:function(A)` | `Module.function(a)` |
| (none) | `alias Foo.Bar` → use `Bar` |
| (none) | `alias Foo.{Bar, Baz}` |
| (none) | `require Integer` (for macros) |
| (none) | `import List, only: [map: 2]` |

---

## OTP — GenServer

| Erlang | Elixir |
|--------|--------|
| `gen_server:start_link(?M, [], [])` | `GenServer.start_link(__MODULE__, [])` |
| `gen_server:call(P, Msg)` | `GenServer.call(pid, msg)` |
| `gen_server:cast(P, Msg)` | `GenServer.cast(pid, msg)` |
| `{reply, R, S}` | `{:reply, reply, state}` |
| `{noreply, S}` | `{:noreply, state}` |
| `{stop, R, S}` | `{:stop, reason, state}` |
| (none) | `@impl true` |

### Naming

```elixir
# Registered name (local to node)
GenServer.start_link(__MODULE__, [], name: MyServer)
GenServer.call(MyServer, :status)

# Via Registry (distributed-friendly)
GenServer.start_link(__MODULE__, [], name: {:via, Registry, {MyApp.Registry, "device-1"}})
GenServer.call({:via, Registry, {MyApp.Registry, "device-1"}}, :status)
```

---

## OTP — Supervisor

| Erlang | Elixir |
|--------|--------|
| `supervisor:start_link(...)` | `Supervisor.start_link(children, strategy: :one_for_one)` |
| `one_for_one` | `:one_for_one` |
| `one_for_all` | `:one_for_all` |
| `rest_for_one` | `:rest_for_one` |
| `simple_one_for_one` | (legacy — use `DynamicSupervisor`) |

### Restart Strategies

| Restart | Meaning |
|---------|---------|
| `:permanent` | Always restart |
| `:temporary` | Never restart |
| `:transient` | Restart only if abnormally terminated |

---

## OTP — DynamicSupervisor

For runtime-dynamic children (websocket connections, device processes, etc.).

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

# Start a child at runtime
DynamicSupervisor.start_child(MyApp.WorkerSupervisor, {MyApp.Worker, device_id})
```

---

## OTP — Application

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MyApp.Repo,
      MyApp.WorkerSupervisor,
      {Registry, keys: :unique, name: MyApp.Registry}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

In `mix.exs`:
```elixir
def application do
  [mod: {MyApp.Application, []}, extra_applications: [:logger]]
end
```

---

## Child Specs

Every supervision child needs a child specification. `use GenServer` automatically provides `child_spec/1`. Modules can also be wrapped with `Supervisor.child_spec/2`.

```elixir
# These are equivalent:
children = [
  MyApp.Worker,                          # calls MyApp.Worker.child_spec([])
  {MyApp.Worker, port: 4000},            # passes [port: 4000] to child_spec/1
  Supervisor.child_spec(MyApp.Worker, id: :unique_name)
]

# Manual override (in module):
def child_spec(arg) do
  %{id: __MODULE__, start: {__MODULE__, :start_link, [arg]}, type: :worker}
end
```

| `Supervisor.start_link` style | Elixir equivalent |
|-------------------------------|-------------------|
| `supervisor:start_link(...)` | `Supervisor.start_link(children, strategy: :one_for_one)` |
| `worker:start_link(...)` | `{MyApp.Worker, arg}` tuple in children list |

---

## Registry

Local process registry (replaces `:global` for dynamic name lookup).

```elixir
# In supervision tree:
{Registry, keys: :unique, name: MyApp.Registry}

# Register
Registry.register(MyApp.Registry, "device-1", %{})

# Lookup
Registry.lookup(MyApp.Registry, "device-1")   # [{pid, meta}]

# Keys list for a pid
Registry.keys(MyApp.Registry, pid)
```

---

## Task

| Erlang | Elixir |
|--------|--------|
| `proc_lib:spawn(F)` | `Task.start(fn -> ... end)` |
| (none) | `Task.start_link(fn -> ... end)` |
| (none) | `Task.async(fn -> ... end) \|> Task.await()` |
| (none) | `Task.async_stream(list, &fun/1, max_concurrency: 3)` |

### Task.Supervisor

For supervised async tasks (common in production).

```elixir
# In supervision tree:
children = [{Task.Supervisor, name: MyApp.TaskSup}]

# Usage:
Task.Supervisor.async_nolink(MyApp.TaskSup, fn -> heavy_work() end)
Task.Supervisor.start_child(MyApp.TaskSup, fn -> fire_and_forget() end)
```

---

## Agent

Simplest state holder — no need to write `handle_call`/`handle_cast`.

```elixir
{:ok, pid} = Agent.start_link(fn -> %{} end)
Agent.get(pid, & &1)
Agent.update(pid, &Map.put(&1, :key, :val))
Agent.get_and_update(pid, fn map -> {old, Map.put(map, :k, :v)} end)
```

---

## ETS

| Erlang | Elixir |
|--------|--------|
| `ets:new(n, [:set,:public])` | `:ets.new(:name, [:set, :public])` — returns table id |
| (none) | `:ets.new(:cache, [:set, :public, :named_table])` — named table |
| `ets:insert(T, {k, v})` | `:ets.insert(table, {:key, val})` |
| `ets:lookup(T, k)` | `:ets.lookup(table, :key)` (or `:ets.lookup(:cache, key)` if named) |

---

## Logger

| Erlang | Elixir |
|--------|--------|
| `logger:debug("msg")` | `Logger.debug("msg")` |
| `logger:info("msg")` | `Logger.info("msg")` |
| `logger:warning("msg")` | `Logger.warn("msg")` (older) / `Logger.warning("msg")` (newer preferred) |
| `logger:error("msg")` | `Logger.error("msg")` |

> In Elixir, `require Logger` is needed before use.

---

## Persistent Term (OTP 21+)

Fast global read-mostly storage. Reads are extremely cheap. Updates are possible but expensive (triggers global GC).

```elixir
:persistent_term.put(:my_config, %{port: 4000, host: "localhost"})
:persistent_term.get(:my_config)                 # => %{port: 4000, ...}
:persistent_term.get(:my_config, :default_value)
```

Use for: configuration, lookup tables, immutable caches. Faster than ETS for static data.

---

## Processes

| Erlang | Elixir |
|--------|--------|
| `spawn(M, F, A)` | `spawn(fn -> ... end)` |
| `Pid ! Msg` | `send(pid, msg)` (idiomatic) |
| `self()` | `self()` |
| `receive ... end` | `receive do ... end` |
| `after T ->` | `after timeout ->` |
| `erlang:register(N, P)` | `:erlang.register(name, pid)` |
| `Process.whereis(N)` | `Process.whereis(name)` |
| `spawn_link(M, F, A)` | `spawn_link(fn -> ... end)` |

---

## Binary / Bitstrings

| Erlang | Elixir |
|--------|--------|
| `<<X:16/integer-signed>>` | `<<x::integer-signed-16>>` |
| `<<X/utf8>>` | `<<x::utf8>>` |
| `<<X:4, Y:4>>` | `<<x::4, y::4>>` |

---

## Comprehensions

| Erlang | Elixir |
|--------|--------|
| `[X*2 \|\| X <- L, X>2]` | `for x <- list, x > 2, do: x * 2` |
| (none) | `for x <- list, into: %{}, do: {x, x*2}` |
| (none) | `for <<r::8, g::8, b::8 <- pixels>>, do: {r,g,b}` |

---

## Enum

| Erlang | Elixir |
|--------|--------|
| `lists:map(F, L)` | `Enum.map(list, fun)` |
| `lists:filter(F, L)` | `Enum.filter(list, fun)` |
| `lists:foldl(F, A, L)` | `Enum.reduce(list, acc, fun)` |
| `lists:foreach(F, L)` | `Enum.each(list, fun)` |
| `lists:all(F, L)` | `Enum.all?(list, fun)` |
| `lists:any(F, L)` | `Enum.any?(list, fun)` |
| `lists:takewhile(F, L)` | `Enum.take_while(list, fun)` |
| `lists:dropwhile(F, L)` | `Enum.drop_while(list, fun)` |
| `lists:sort(L)` | `Enum.sort(list)` |
| `lists:uniq(L)` | `Enum.uniq(list)` |
| `lists:zip(L1, L2)` | `Enum.zip([l1, l2])` |
| `lists:partition(F, L)` | `Enum.split_with(list, fun)` |
| `lists:flatten(L)` | `List.flatten(list)` |
| `lists:reverse(L)` | `Enum.reverse(list)` |

---

## Stream (Lazy — Elixir only)

```elixir
1..100_000 |> Stream.map(&(&1 * 3)) |> Stream.filter(&(rem(&1, 2) == 1)) |> Enum.sum()
```

No intermediate lists — lazy until `Enum` consumes it.

---

## Pipe Operator (Elixir only)

```elixir
# Without: nested inside-out
Enum.sum(Enum.filter(Enum.map(list, fn x -> x*2 end), &(rem(&1, 2) == 1)))

# With pipe: reads top-to-bottom
list |> Enum.map(&(&1 * 2)) |> Enum.filter(&(rem(&1, 2) == 1)) |> Enum.sum()
```

---

## Return Conventions

```elixir
{:ok, value}     # success
{:error, reason} # failure
```

Used throughout OTP, Ecto, Phoenix, and all Elixir libraries.

---

## Error Handling

| Erlang | Elixir |
|--------|--------|
| `raise` | `raise "msg"` |
| `try ... catch _:_ ->` | `try do ... rescue _ -> ... end` |
| `try ... of ... catch` | `try do ... else ... rescue ... end` |
| `throw(X)` | `throw(x)` |
| `exit(R)` | `exit(reason)` |
| `after` | `after` (same) |

---

## Typespecs

```elixir
@type user_id :: integer()

@type state :: %{
  users: map(),
  count: non_neg_integer()
}

@opaque t :: %__MODULE__{
  id: binary(),
  meta: map()
}

@spec get_user(user_id()) :: {:ok, User.t()} | {:error, :not_found}
```

---

## Behaviours

```elixir
defmodule Storage do
  @callback put(term(), term()) :: :ok
  @callback get(term()) :: term()
  @callback connect(String.t()) :: {:ok, pid()}
end

defmodule ETSStorage do
  @behaviour Storage

  @impl true
  def put(k, v), do: :ok

  @impl true
  def get(k), do: nil

  @impl true
  def connect(uri), do: {:ok, :ets.new(:cache, [:set, :public])}
end
```

---

## Protocols (Polymorphism)

```elixir
defprotocol Size do
  def size(data)
end

defimpl Size, for: Integer do
  def size(0), do: 1
  def size(n), do: floor(:math.log2(n)) + 1
end

defimpl Size, for: BitString do
  def size(s), do: byte_size(s)
end

Size.size(255)  # => 8
```

| Behaviour | Protocol |
|-----------|----------|
| Callbacks defined in a module | Functions dispatched per data type |
| Implemented via `@behaviour` + `@impl` | Implemented via `defimpl Type, for: Datatype` |
| Polymorphism per module | Polymorphism per data type |

---

## Macros (compile-time code generation)

```elixir
defmacro double(expr), do: quote(do: unquote(expr) * 2)
```

- `quote` — captures AST
- `unquote` — injects values into AST
- Used sparingly for DSLs. Prefer functions/`alias`/`import` first.

---

## Project Structure

| Erlang (rebar3) | Elixir (Mix) |
|-----------------|--------------|
| `rebar.config` | `mix.exs` |
| `src/` | `lib/` |
| `include/*.hrl` | (none — use modules) |
| `test/` | `test/` |
| `_build/` | `_build/` |
| `rebar3 compile` | `mix compile` |
| `rebar3 eunit` | `mix test` |
| `rebar3 shell` | `iex -S mix` |
| (none) | `mix deps.get` |
| (none) | `mix format` |
| (none) | `mix credo` (linter, add as dep) |
| (none) | `mix dialyzer` (via `dialyxir` hex) |

---

## Config

| Erlang | Elixir |
|--------|--------|
| `sys.config` | `config/config.exs` |
| (none) | `Application.get_env(:app, :key, default)` | runtime |
| (none) | `Application.compile_env(:app, :key)` | compile-time — avoid unless value truly affects compilation |
| (none) | `config :app, key: val` in config files |
| (none) | `config_env()` in config files (not `Mix.env()` — never use in code) |
| (none) | `config/runtime.exs` for runtime config (evaluated after release) |

---

## Releases

```bash
mix release
_build/prod/rel/my_app/bin/my_app start
_build/prod/rel/my_app/bin/my_app start_iex
_build/prod/rel/my_app/bin/my_app eval "IO.puts(1+1)"
```

Releases bundle ERTS + Elixir + deps — no Mix dependency at runtime.

---

## Telemetry

Event-based instrumentation (standard in Elixir ecosystem).

```elixir
:telemetry.execute(
  [:my_app, :request, :done],
  %{duration: elapsed_ms},
  %{path: req.path, method: req.method}
)
```

Used by Phoenix, Ecto, Broadway, etc. Integrates with Prometheus, OpenTelemetry.

---

## Ecto (Database)

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema

  schema "users" do
    field :name, :string
    field :email, :string
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> Ecto.Changeset.cast(attrs, [:name, :email])
    |> Ecto.Changeset.validate_required([:name, :email])
  end
end

# Changeset → insert (returns {:ok, struct} | {:error, changeset})
case User.changeset(%User{}, %{name: "John", email: "john@example.com"})
     |> MyApp.Repo.insert() do
  {:ok, user} -> user
  {:error, changeset} -> changeset.errors
end

# Queries
MyApp.Repo.get(User, 1)
MyApp.Repo.all(from u in User, where: u.age > 18)
```

---

## Production OTP Components

| Component | Purpose |
|-----------|---------|
| Application | App entry point and lifecycle |
| Supervisor | Restart static children via child specs |
| DynamicSupervisor | Start/restart runtime children |
| Child Spec | Describes how to start/restart a child process |
| Registry | Name → pid lookup for dynamic processes |
| Task.Supervisor | Supervised async tasks (`async_nolink`, `start_child`) |
| GenServer | Stateful message-handling process |
| Task | One-shot async computation |
| Agent | Simple state wrapper |
| ETS | In-memory key-value storage |
| Persistent Term | Fast immutable global values (OTP 21+) |

---

## Debugging

| Erlang | Elixir |
|--------|--------|
| `io:format("~p", [X])` | `IO.inspect(x)` |
| (none) | `dbg(x)` (v1.14+ — prints code + location) |
| (none) | `IEx.break!(Mod.fun/arity)` |
| (none) | `iex --dbg pry` |
| `observer:start().` | `:observer.start()` |

---

## IEx vs erl

| Action | `erl` | `iex` |
|--------|-------|-------|
| Start | `erl` | `iex` |
| Compile | `c(Mod)` | `c "file.ex"` |
| Call | `M:f(A).` | `M.f(a)` |
| Help | `help().` | `h()` |
| Info | `M:module_info().` | `i(M)` |
| Recompile | (manual) | `recompile()` |
| History | `Ctrl+P`/`Ctrl+N` | `Up`/`Down` |

---

## Quick One-Liners

| Erlang | Elixir |
|--------|--------|
| `timer:sleep(100).` | `Process.sleep(100)` |
| `erlang:system_time(second).` | `:erlang.system_time(:second)` |
| `length([1,2,3]).` | `length([1,2,3])` |
| `hd([1,2,3]).` | `hd([1,2,3])` |
| `tl([1,2,3]).` | `tl([1,2,3])` |
| `element(2, {a,b}).` | `elem({:a, :b}, 1)` (0-indexed!) |
| `tuple_size({a,b}).` | `tuple_size({:a, :b})` |
| `map_size(#{a=>1}).` | `map_size(%{a: 1})` |
| `byte_size(<<"ab">>).` | `byte_size("ab")` |
| `round(3.5).` | `round(3.5)` |
| `trunc(3.5).` | `trunc(3.5)` |
| `abs(-3).` | `abs(-3)` |

---

## Key Differences (Gotchas)

| # | Rule |
|---|------|
| 1 | `=` rebinds in Elixir. Use `^x` to match existing value. |
| 2 | Most atoms need `:` prefix. Exceptions: `true`, `false`, `nil`. |
| 3 | `"abc"` is a binary, not a list. `~c"abc"` for charlist. |
| 4 | No `,`/`;`/`.` terminators. Blocks end with `end`. |
| 5 | `if` is 2-branch only. Use `cond` for 3+ branches. |
| 6 | `Enum.map` replaces `lists:map`, etc. |
| 7 | `defp` = private. No export list. |
| 8 | `use GenServer` sets up defaults. Use `@impl true`. |
| 9 | `1_000_000` is valid — use for readability. |
| 10 | `@attr` is compile-time. `Application.get_env` = runtime. `Application.compile_env` = compile-time — avoid unless truly needed. |
| 11 | `map.key` works only for atom keys known at compile-time, raises on missing. `map[:key]` works with any key type at runtime, returns `nil` if missing. `Map.get(map, key, default)` for safe access. |
| 12 | No `.hrl` files — use module attributes or a constants module. |
| 13 | Mix handles compilation order — deps in `mix.exs`. |
| 14 | `with` chains pattern matches — avoids nested `case`. |
| 15 | Elixir is expressions-only. No statements. Everything returns a value. |

---

## Distributed BEAM

| Erlang | Elixir |
|--------|--------|
| `node().` | `Node.self()` |
| `nodes().` | `Node.list()` |
| `net_adm:ping(Node).` | `:net_adm.ping(node)` |
| `spawn(Node, M, F, A)` | `Node.spawn(node, fn -> ... end)` (rare in modern code — prefer Task.Supervisor or RPC) |
| `rpc:call(Node, M, F, A)` | `:rpc.call(node, Mod, :fun, [args])` |

```elixir
# Cookie in .erlang.cookie or sys.config
:net_adm.ping(:"worker@192.168.1.10")
:rpc.call(:"worker@192.168.1.10", File, :cwd!, [])
```

---

## OTP Naming Patterns

```elixir
# 1. Local registered name (simplest)
GenServer.start_link(__MODULE__, [], name: MyServer)
GenServer.call(MyServer, :status)

# 2. Via Registry (dynamic processes)
GenServer.start_link(__MODULE__, [], name: {:via, Registry, {MyApp.Registry, "device-1"}})
GenServer.call({:via, Registry, {MyApp.Registry, "device-1"}}, :status)

# 3. Via :global (distributed)
GenServer.start_link(__MODULE__, [], name: {:global, :my_server})
GenServer.call({:global, :my_server}, :status)
```

| Pattern | Scope | Use case |
|---------|-------|----------|
| `name: MyServer` | Local node | Singleton services |
| `{:via, Registry, {Reg, key}}` | Local node | Dynamic named processes |
| `{:global, name}` | Cluster | Distributed singletons |

---

## Ecosystem Quick Reference

| Tool | Purpose |
|------|---------|
| Phoenix | Web framework (MVC, LiveView, Channels) |
| Ecto | Database wrapper + query language |
| LiveView | Real-time UI over WebSocket |
| Nerves | Embedded / IoT firmware |
| Nx | Numerical computing (tensors, ML) |
| Broadway | Data pipelines (batching, back-pressure) |
| Livebook | Interactive notebooks |
| Hex | Package manager |
| ExDoc | Documentation generator |
| Dialyzer | Static analysis (via `dialyxir` hex package) |
