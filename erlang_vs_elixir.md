# Erlang → Elixir Complete Reference

> Everything an Erlang programmer needs to learn Elixir.
> Real project examples from `/tools/atomvm_projects/projects/` (official AtomVM sample apps)
> plus comprehensive reference from [hexdocs.pm/elixir](https://hexdocs.pm/elixir).

---

## 1. Module Definition

| Erlang | Elixir |
|--------|--------|
| `-module(calculator).` | `defmodule Calculator do` |
| `-module(snake_blockbreaker).` | `defmodule SnakeBlockbreaker.WiFi do` (nested) |
| `-export([start/0]).` | `def start do ... end` |
| Private function | `defp start do ... end` |
| `-behaviour(gen_server).` | `use GenServer` |
| Callback annotation | `@impl true` (optional, recommended) |
| Module doc | `@moduledoc """..."""` |
| | `alias Foo.Bar` (no Erlang equivalent) |

**Erlang:**
```erlang
-module(calculator).
-behaviour(gen_server).
-export([start/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
```

**Elixir:**
```elixir
defmodule Calculator do
  use GenServer
  @impl true
  def start do ... end
  @impl true
  def init(_) do ... end
  ...
end
```

---

## 2. Data Types

| Type | Erlang | Elixir |
|------|--------|--------|
| Integer | `42` | `42` |
| Float | `3.14` | `3.14` |
| Atom | `ok`, `error` | `:ok`, `:error` |
| Boolean | `true`, `false` | `true`, `false` |
| Nil | `undefined` | `nil` |
| String | `"hello"` (charlist) | `"hello"` (UTF-8 binary) |
| Charlist | `[104,101,108,108,111]` | `~c"hello"` or `'hello'` |
| Binary | `<<"hello">>` | `"hello"` or `<<104,101,108,108,111>>` |
| Tuple | `{a, b}` | `{:a, :b}` |
| List | `[a, b, c]` | `[:a, :b, :c]` |
| Map | `#{key => val}` | `%{key: val}` |
| Struct | `-record(...)` | `defstruct ...` |
| PID | `#Pid<...>` | `#PID<...>` |
| Reference | `#Ref<...>` | `#Reference<...>` |
| Function | `fun(...) -> ... end` | `fn ... -> ... end` |
| Port | `#Port<...>` | `#Port<...>` |

### Key: Strings are Binaries

**Erlang:**
```erlang
"hello" = [104,101,108,108,111]     % charlist
<<"hello">> = <<104,101,108,108,111>> % binary
```

**Elixir:**
```elixir
"hello" = <<104,101,108,108,111>>   % binary (default!)
~c"hello" = [104,101,108,108,111]   % charlist (sigil)
'hello'  = [104,101,108,108,111]    % charlist (rare)
```

This means `byte_size("hellö")` = 6 but `String.length("hellö")` = 5.

### Structural Comparison

```elixir
1 == 1.0     # true (value equality)
1 === 1.0    # false (strict, checks type)
```

### Guard Helper Functions

Elixir has the same guards as Erlang: `is_integer/1`, `is_float/1`, `is_binary/1`, `is_atom/1`, `is_pid/1`, `is_tuple/1`, `is_list/1`, `is_map/1`, `abs/1`, `round/1`, `hd/1`, `tl/1`, `length/1`, `elem/2`.

---

## 3. Variables

| Erlang | Elixir |
|--------|--------|
| `SomeVariable` (uppercase) | `some_variable` (snake_case) |
| `X = 1, X = 2` → crash | `x = 1; x = 2` → rebinds |
| Match existing: `X = 1` | `^x = 1` (pin operator) |
| `_Unused` | `_unused` (or just `_`) |

**Pin operator** forces pattern match instead of rebind:
```elixir
x = 1
^x = 2  # MatchError
^x = 1  # works
```

**From the project** (`snake_blockbreaker/disterl.ex`):
```elixir
defp ensure_registered(name, pid) do
  case Process.whereis(name) do
    nil -> :ok
    ^pid -> :ok          # must match the pid from args
    other_pid -> {:error, {:already_registered, name, other_pid}}
  end
end
```

### Expressions, Not Statements

Everything in Elixir is an expression and returns a value. Variables defined inside `if`, `case`, `try` blocks don't leak to outer scope:

```elixir
x = 1
if true do
  x = x + 1    # this x is local to the block
end
x               # still 1

# To capture:
x = if true do
  x + 1
else
  x
end
```

---

## 4. Constants / Module Attributes

| Erlang | Elixir |
|--------|--------|
| `-define(GPIO_SCL, 22).` | `@gpio_scl 22` |
| `-define(LCD_ADDR, 16#27).` | `@lcd_addr 0x27` |
| `?GPIO_SCL` (usage) | `@gpio_scl` (usage) |
| `-define(FLOAT, 81.91).` | `@float 81.91` |
| `-define(MACRO(X), X+1).` | `defmacro macro(x), do: x+1` |

**From the project** — Erlang:
```erlang
-define(GPIO_SCL, 22).
-define(LCD_ADDR, 16#27).
-define(MODE_CAL, 0).
```

**From the project** — Elixir:
```elixir
@gpio_scl 22
@lcd_addr 0x27
@mode_cal 0
```

### Module Attributes Go Deeper

In Elixir, module attributes are not just constants. They serve three purposes:

1. **Annotations**: `@moduledoc`, `@doc`, `@spec`, `@behaviour`
2. **Compile-time storage**: store computed values at compile time
3. **Constants**: compile-time values injected into functions

```elixir
defmodule MyServer do
  @service URI.parse("https://example.com")   # computed at compile time
  def status(email) do
    SomeHttpClient.get(@service)               # value is inlined
  end
end
```

### Reserved Attributes

- `@moduledoc` — module documentation
- `@doc` — function documentation
- `@spec` — typespec
- `@behaviour` — OTP behaviour
- `@impl` — marks callback implementations
- `@compile` — compiler options
- `@enforce_keys` — required struct keys

---

## 5. Records vs Structs

| Erlang | Elixir |
|--------|--------|
| `-record(mpu, {accy, accz}).` | `defstruct [:accy, :accz]` |
| `Data#mpu.accy` | `data.accy` |
| `Data#mpu{accy = NewVal}` | `%{data \| accy: new_val}` |
| `#mpu{accy = 1}` | `%__MODULE__{accy: 1}` |
| No compile-time checking | Compile-time key validation |

**Erlang:**
```erlang
-record(state, {i2c, mode, data, exp, ans, pointer, history, size, x, y}).
...
NewState = State#state{data = Data, exp = NewExp, x = NewX, y = NewY}.
```

**Elixir:**
```elixir
defstruct [:i2c, :mode, :data, :exp, :ans, :pointer, :history, :size, :x, :y]
...
new_state = %{state | data: data, exp: new_exp, x: new_x, y: new_y}
```

### Structs with Default Values

```elixir
defmodule User do
  defstruct name: "John", age: 27
end

%User{}                 # => %User{age: 27, name: "John"}
%User{name: "Jane"}     # => %User{age: 27, name: "Jane"}
%User{oops: :field}     # KeyError — compile-time check!
```

### Optional Fields (default nil)

```elixir
defstruct [:email, name: "John", age: 27]
# :email defaults to nil
```

### Required Keys

```elixir
defmodule Car do
  @enforce_keys [:make]
  defstruct [:model, :make]
end

%Car{}  # ArgumentError: :make must be given
```

### Structs are Bare Maps

```elixir
is_map(%User{})     # true — structs are maps underneath
john.__struct__     # User — special key
```

But structs **don't** inherit map protocols (no `Access`, no `Enumerable`):
```elixir
%User{}[:name]       # UndefinedFunctionError
Enum.each(%User{}, ...)  # Protocol.UndefinedError
```

---

## 6. Function Definitions

### Standard body

**Erlang:**
```erlang
start() ->
    erlang:system_flag(schedulers_online, 2),
    keypad_init(),
    {ok, Pid} = gen_server:start_link(?MODULE, [], []),
    read_keypad(Pid).
```

**Elixir:**
```elixir
def start do
  :erlang.system_flag(:schedulers_online, 2)
  keypad_init()
  {:ok, pid} = GenServer.start_link(__MODULE__, [])
  read_keypad(pid)
end
```

### One-liner

```erlang
delay() -> timer:sleep(100).
```

```elixir
defp delay, do: Process.sleep(100)
```

### Multiple Clauses (Pattern Matching)

**Erlang:**
```erlang
lcd_send_string(_I2C, []) -> ok;
lcd_send_string(I2C, [Head|Str]) ->
    lcd_send_data(I2C, Head),
    lcd_send_string(I2C, Str).
```

**Elixir:**
```elixir
defp lcd_send_string(_i2c, []), do: :ok
defp lcd_send_string(i2c, [head | str]) do
  lcd_send_data(i2c, head)
  lcd_send_string(i2c, str)
end
```

### Default Arguments

```elixir
def join(a, b, sep \\ " ") do
  a <> sep <> b
end

Concat.join("Hello", "world")       # "Hello world"
Concat.join("Hello", "world", "_")  # "Hello_world"
```

When using defaults with multiple clauses, use a function head:
```elixir
def join(a, b, sep \\ " ")    # head (no body)
def join(a, b, _sep) when b == "", do: a
def join(a, b, sep), do: a <> sep <> b
```

### Guards

Erlang: `when is_integer(X), is_atom(Y)` (comma = and)
Elixir: `when is_integer(x) and is_atom(y)` (must use `and`)

```elixir
def zero?(0), do: true
def zero?(x) when is_integer(x), do: false

def guard_example(x, y) when is_integer(x) and is_atom(y) do
  # ...
end
```

### Private Functions

Erlang: omit from `-export`
Elixir: use `defp`

---

## 7. Control Flow

### case

```erlang
case X of
    {ok, Val} -> Val;
    {error, _} -> 0
end.
```

```elixir
case x do
  {:ok, val} -> val
  {:error, _} -> 0
end
```

Clauses support guards, and the pin operator:
```elixir
case {1, 2, 3} do
  {1, x, 3} when x > 0 -> "matched with x=#{x}"
  _ -> "fallback"
end
```

### if

Erlang `if` with two branches:
```erlang
if Value == high -> ok;
   true -> keypad_wait_release(GPIO)
end.
```

Elixir `if/else`:
```elixir
if value == :high do
  :ok
else
  keypad_wait_release(gpio)
end
```

Erlang `if` with three+ branches → Elixir `cond`:
```elixir
{new_x, new_y} =
  cond do
    (x == 0) and (y == 0) -> {x, y}
    (y - 1) < 0 -> {0, 19}
    true -> {x, y - 1}
  end
```

### unless (Elixir only)

```elixir
unless value == :high do
  keypad_wait_release(gpio)
end
```

### if/2 is a Macro

```elixir
if true do
  "works"
end

# is equivalent to:
if(true, do: "works")
if(true, do: "a", else: "b")  # keyword list syntax
```

### with (Elixir only — chains pattern matches)

```elixir
with :ok <- ensure_epmd_started(),
     :ok <- ensure_net_kernel_started(node_name),
     :ok <- :net_kernel.set_cookie(@cookie),
     :ok <- ensure_registered(:disterl, self()) do
  {:ok, node_name}
else
  {:error, reason} -> {:error, reason}
end
```

This replaces deeply nested `case` expressions.

---

## 8. Bitwise and Boolean Operators

| Operation | Erlang | Elixir |
|-----------|--------|--------|
| Bitwise AND | `Cmd band 16#F0` | `command &&& 0xF0` |
| Bitwise OR | `DataU bor 16#0C` | `data_u \|\|\| 0x0C` |
| Shift left | `Cmd bsl 4` | `command <<< 4` |
| Shift right | `Cmd bsr 4` | `command >>> 4` |
| Bitwise XOR | `Cmd bxor 16#FF` | `command ^^^ 0xFF` |
| Bitwise NOT | `bnot Cmd` | `~~~command` |
| Boolean NOT | `not Cond` | `not cond` |
| Boolean AND | `A and B` | `a and b` |
| Boolean OR | `A orelse B` | `a \|\| b` |
| Value equal | `A == B` | `a == b` |
| Strict equal | `A =:= B` | `a === b` |
| Strict not equal | `A =/= B` | `a !== b` |

> **Important**: Bitwise ops in Elixir require `use Bitwise` at the top of the module.

### Strict vs Relaxed Booleans

```elixir
true and 1       # BadBooleanError (strict — expects booleans)
1 && true        # true (relaxed — 1 is truthy)
false || 11      # 11
!nil             # true
```

Only `false` and `nil` are falsy in Elixir. `0`, `""`, `[]` are all truthy.

---

## 9. Pattern Matching — In Detail

### The Match Operator `=`

```iex
x = 1
1 = x          # matches — both sides are 1
2 = x          # MatchError
```

### Destructuring

```elixir
{a, b, c} = {:hello, "world", 42}
# a = :hello, b = "world", c = 42

{:ok, result} = {:ok, 13}
# result = 13

{:ok, result} = {:error, :oops}
# MatchError — pattern doesn't match

[head | tail] = [1, 2, 3]
# head = 1, tail = [2, 3]

[head | _] = [1, 2, 3]  # ignore tail with _
```

### Matching on Maps

```elixir
%{name: name} = %{name: "John", age: 23}
# name = "John"

%{} = %{a: 1, b: 2}     # empty map matches all maps
%{c: c} = %{a: 1}       # MatchError (key :c missing)
```

### Matching on Structs

```elixir
%User{name: name} = %User{name: "John", age: 27}
# name = "John"

%User{} = %{}     # MatchError (not a User struct)
```

### Same Variable Multiple Times

```elixir
{x, x} = {1, 1}   # works
{x, x} = {1, 2}   # MatchError (x can't be both 1 and 2)
```

---

## 10. Calling Erlang from Elixir

| Erlang | Elixir |
|-------------|-------------------|
| `timer:sleep(100)` | `Process.sleep(100)` or `:timer.sleep(100)` |
| `io:format("~p~n", [X])` | `IO.inspect(X)` or `IO.puts("...")` |
| `erlang:system_flag(...)` | `:erlang.system_flag(...)` |
| `math:pow(10, 15)` | `:math.pow(10, 15)` |
| `lists:reverse(List)` | `Enum.reverse(list)` |
| `lists:foreach(Fun, List)` | `Enum.each(list, fun)` |
| `i2c:open([...])` | `I2C.open(...)` |
| `gpio:set_pin_mode(Pin, output)` | `GPIO.set_pin_mode(pin, :output)` |
| `ledc:timer_config(Cfg)` | `:ledc.timer_config(cfg)` |
| `self()` | `self()` |
| `erlang:register(Name, Pid)` | `:erlang.register(name, pid)` |

Rule: Any Erlang module `foo` is called as `:foo.function(args)` in Elixir.

---

## 11. Strings, Charlists, Sigils

| Erlang | Elixir |
|--------|--------|
| `"hello"` (charlist) | `"hello"` (UTF-8 binary) |
| `$A` (integer 65) | `?A` (integer 65) |
| `<<"hello">>` | `"hello"` |
| No interpolation | `"Hello #{name}"` |
| `io:format("~p~n", [X])` | `IO.inspect(x)` or `IO.puts("...")` |
| Concatenation: `<<"a"/utf8, "b">>` | `"a" <> "b"` |

### Sigils

```elixir
~r/foo|bar/i          # regex (i = case insensitive)
~r{^https?://}        # different delimiter
~c"hello"             # charlist (like Erlang "hello")
~s"hello \"world\""   # string with escapes
~S"no \#{interp}"     # raw string (no escapes)
~w(foo bar bat)       # word list → ["foo", "bar", "bat"]
~w(foo bar bat)a      # word list as atoms → [:foo, :bar, :bat]
```

### Calendar Sigils

```elixir
~D[2019-10-31]               # Date
~T[23:00:07.0]               # Time
~N[2019-10-31 23:00:07]      # NaiveDateTime (no timezone)
~U[2019-10-31 19:59:03Z]     # DateTime (UTC)
```

### iodata / chardata

IO functions accept lists of strings/binaries for performance (no copying):
```elixir
name = "Mary"
IO.puts(["Hello ", name, "!"])   # no string copy
```

---

## 12. Lists

| Erlang | Elixir |
|--------|--------|
| `[Head \| Tail]` | `[head \| tail]` |
| `hd(List)` | `hd(list)` |
| `tl(List)` | `tl(list)` |
| `[1,2] ++ [3]` | `[1,2] ++ [3]` |
| `[1,2,3] -- [2]` | `[1,2,3] -- [2]` |
| `length(L)` | `length(l)` |

---

## 13. Maps

| Erlang | Elixir |
|--------|--------|
| `#{}` | `%{}` |
| `#{key => val}` | `%{key: val}` (atom keys) or `%{:key => val}` |
| `maps:get(key, Map, default)` | `Map.get(map, :key, default)` |
| `map.key` (if it exists) | Not supported in Erlang |
| `Map#{key := NewVal}` | `%{map \| key: new_val}` |
| `maps:keys(Map)` | `Map.keys(map)` |
| `maps:values(Map)` | `Map.values(map)` |

**Erlang:**
```erlang
get() ->
    #{
        port => 8080,
        sta => [
            {ssid, esp:nvs_get_binary(atomvm, sta_ssid, <<"wifi">>)}
        ]
    }.
```

**Elixir:**
```elixir
def get do
  %{
    port: 8080,
    sta: [
      ssid: :esp.nvs_get_binary(:atomvm, :sta_ssid, "wifi")
    ]
  }
end
```

### Pattern Matching on Maps

```elixir
%{name: name} = %{name: "John", age: 23}    # matches subset
%{age: age, name: name} = %{name: "John"}    # MatchError
```

### Update Syntax (existing keys only)

```elixir
%{map | key: new_value}    # raises KeyError if key doesn't exist
```

### Nested Data Access

```elixir
users = [
  john: %{name: "John", age: 27, languages: ["Erlang", "Elixir"]}
]

users[:john].age                          # 27
put_in(users[:john].age, 31)             # update nested
update_in(users[:john].languages, &List.delete(&1, "Erlang"))
```

---

## 14. Keyword Lists

A keyword list is a list of 2-tuples where the first element is an atom:
```elixir
[{:parts, 3}, {:trim, true}] == [parts: 3, trim: true]  # true
```

Properties:
- Keys must be atoms
- Keys are ordered
- Keys can repeat

Used as optional arguments to functions:
```elixir
String.split("1 2 3", " ", parts: 3, trim: true)
# When last arg, brackets can be omitted
```

Don't pattern match on keyword lists (order matters, keys may be missing). Use the `Keyword` module:
```elixir
Keyword.get(list, :key, default)
Keyword.put(list, :key, value)
```

---

## 15. Enumerable / Enum

Elixir has a rich `Enum` module. Erlang only has `lists`.

**From the project** — Erlang `lists:foreach`:
```erlang
lists:foreach(fun(GPIO) -> gpio:set_pin_mode(GPIO, output) end, List),
```
**Elixir:**
```elixir
Enum.each(list, fn gpio -> GPIO.set_pin_mode(gpio, :output) end)
```

### Common Enum functions

| Erlang | Elixir |
|--------|--------|
| `lists:map(Fun, List)` | `Enum.map(list, fun)` |
| `lists:filter(Fun, List)` | `Enum.filter(list, fun)` |
| `lists:foldl(Fun, Acc, List)` | `Enum.reduce(list, acc, fun)` |
| `lists:foreach(Fun, List)` | `Enum.each(list, fun)` |
| `lists:all(Fun, List)` | `Enum.all?(list, fun)` |
| `lists:any(Fun, List)` | `Enum.any?(list, fun)` |
| `lists:takewhile(Fun, List)` | `Enum.take_while(list, fun)` |
| `lists:dropwhile(Fun, List)` | `Enum.drop_while(list, fun)` |
| `lists:sort(List)` | `Enum.sort(list)` |
| `lists:uniq(List)` | `Enum.uniq(list)` |
| `lists:zip(L1, L2)` | `Enum.zip([l1, l2])` |
| `lists:partition(Fun, List)` | `Enum.split_with(list, fun)` |
| `lists:flatten(List)` | `List.flatten(list)` |

### Ranges are Enumerable

```elixir
Enum.map(1..5, fn x -> x * 2 end)    # [2, 4, 6, 8, 10]
Enum.reduce(1..3, 0, &+/2)           # 6
```

---

## 16. Comprehensions

```erlang
% Erlang
[X * 2 || X <- List, X > 3].
```

```elixir
# Elixir
for x <- list, x > 3, do: x * 2
```

### Multiple Generators

```elixir
for i <- [:a, :b], j <- [1, 2], do: {i, j}
# [a: 1, a: 2, b: 1, b: 2]
```

### Pattern Matching in Generators

```elixir
values = [good: 1, good: 2, bad: 3, good: 4]
for {:good, n} <- values, do: n * n
# [1, 4, 16]
```

### Bitstring Generators

```elixir
pixels = <<213, 45, 132, 64, 76, 32>>
for <<r::8, g::8, b::8 <- pixels>>, do: {r, g, b}
# [{213, 45, 132}, {64, 76, 32}]
```

### :into Option

```elixir
for <<c <- " hello world ">>, c != ?\s, into: "", do: <<c>>
# "helloworld"

for {key, val} <- %{"a" => 1, "b" => 2}, into: %{}, do: {key, val * val}
# %{"a" => 1, "b" => 4}
```

---

## 17. Streams (Lazy Enumeration — Elixir only)

Streams build a series of computations that are only executed when passed to `Enum`:

```elixir
1..100_000
|> Stream.map(&(&1 * 3))
|> Stream.filter(&odd?/1)
|> Enum.sum()
```

Unlike `Enum` (which creates intermediate lists on each operation), `Stream` is lazy — no intermediate lists are created.

Useful for large or infinite collections:
```elixir
Stream.cycle([1, 2, 3]) |> Enum.take(10)
# [1, 2, 3, 1, 2, 3, 1, 2, 3, 1]
```

---

## 18. The Pipe Operator `|>` (Elixir only)

Passes the result of the left expression as the **first argument** to the function on the right:

```elixir
# Without pipe:
Enum.sum(Enum.filter(Enum.map(1..10, &(&1 * 3)), odd?))

# With pipe:
1..10
|> Enum.map(&(&1 * 3))
|> Enum.filter(&odd?/1)
|> Enum.sum()
```

**From the project** (`snake_blockbreaker/wifi.ex`):
```elixir
:network.start_link(
  sta:
    [
      dhcp_hostname: @dhcp_hostname,
      ssid: wifi_ssid
    ]
    |> maybe_put(:psk, wifi_passphrase),
  ...
)
```

---

## 19. Anonymous Functions / Captures

### fn syntax

```erlang
% Erlang
fun(X) -> X * 2 end
```

```elixir
# Elixir
fn x -> x * 2 end
```

### Calling with `.`

```elixir
add = fn a, b -> a + b end
add.(1, 2)    # note the dot!
```

### Capture Syntax `&`

```elixir
&String.length/1               # capture named function
&is_atom/1                     # capture Erlang function
&+/2                           # capture operator
&(&1 + 1)                      # fn x -> x + 1 end
&"Good #{&1}"                  # fn x -> "Good #{x}" end
```

**From the project:**
```elixir
Enum.each(list, fn gpio -> GPIO.set_pin_mode(gpio, :output) end)

# Closures capture scope:
defp process_init(i2c) do
  spawn(fn -> handle_pid(i2c, 0, 0, 0, self()) end)
end
```

### Multiple Clauses and Guards

```elixir
f = fn
  x, y when x > 0 -> x + y
  x, y -> x * y
end
```

---

## 20. Processes and Message Passing

| Erlang | Elixir |
|--------|--------|
| `spawn(Mod, Fun, Args)` | `spawn(fn -> ... end)` or `spawn(Mod, :fun, [args])` |
| `Pid ! Msg` | `send(pid, msg)` (idiomatic) |
| `self()` | `self()` |
| `receive ... end` | `receive do ... end` |
| `after Timeout ->` | `after timeout ->` |
| `erlang:register(Name, Pid)` | `:erlang.register(name, pid)` |
| `Process.whereis(Name)` | `Process.whereis(name)` |
| `spawn_link(Mod, Fun, Args)` | `spawn_link(fn -> ... end)` |

### spawn

**Erlang:**
```erlang
spawn(?MODULE, handle_PID, [I2C, 0, 0, 0, self()]).
```

**Elixir:**
```elixir
spawn(fn -> handle_pid(i2c, 0, 0, 0, self()) end)
```

### receive

**Erlang:**
```erlang
loop() ->
    receive
        {power, Power, Angle} -> ...
        {stop, Angle} -> ...
    end,
    loop().
```

**Elixir:**
```elixir
defp loop do
  receive do
    {:power, power, angle} -> ...
    {:stop, angle} -> ...
  end
  loop()
end
```

### send

**Erlang:** `Parent ! {power, Power, CurrentAngle}`
**Elixir:** `send(parent, {:power, power, current_angle})`

### Links

```elixir
spawn_link(fn -> raise "oops" end)     # link crashes parent
Process.link(pid)                      # manual link
```

### Tasks (built on spawn — better errors & introspection)

```elixir
Task.start(fn -> ... end)                       # {:ok, pid}
Task.start_link(fn -> ... end)                  # {:ok, pid}
Task.async(fn -> ... end) |> Task.await()       # for results
```

### Process State (manual)

```elixir
defmodule KV do
  def start_link do
    Task.start_link(fn -> loop(%{}) end)
  end

  defp loop(map) do
    receive do
      {:get, key, caller} ->
        send(caller, Map.get(map, key))
        loop(map)
      {:put, key, value} ->
        loop(Map.put(map, key, value))
    end
  end
end
```

---

## 21. OTP — GenServer

| Erlang | Elixir |
|--------|--------|
| `gen_server:start_link(?MODULE, [], [])` | `GenServer.start_link(__MODULE__, [])` |
| `gen_server:call(Pid, Msg)` | `GenServer.call(pid, msg)` |
| `gen_server:cast(Pid, Msg)` | `GenServer.cast(pid, msg)` |
| `{reply, Reply, State}` | `{:reply, reply, state}` |
| `{noreply, State}` | `{:noreply, state}` |
| `{stop, Reason, State}` | `{:stop, reason, state}` |

**Erlang:**
```erlang
init(_) -> {ok, #state{...}}.
handle_call(display, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
handle_info(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_OldVsn, State, _Extra) -> {ok, State}.
```

**Elixir:**
```elixir
@impl true
def init(_) do {:ok, %__MODULE__{...}} end

@impl true
def handle_call(:display, _from, state) do {:reply, :ok, state} end

@impl true
def handle_cast(_msg, state) do {:noreply, state} end

@impl true
def handle_info(_msg, state) do {:noreply, state} end

@impl true
def terminate(_reason, _state) do :ok end

@impl true
def code_change(_old_vsn, state, _extra) do {:ok, state} end
```

### Named Registration

```elixir
def start_link(opts \\ []) do
  GenServer.start_link(__MODULE__, :ok, Keyword.put(opts, :name, __MODULE__))
end
```

### Agent (simpler than GenServer for pure state)

```elixir
{:ok, pid} = Agent.start_link(fn -> %{} end)
Agent.update(pid, fn map -> Map.put(map, :hello, :world) end)
Agent.get(pid, fn map -> Map.get(map, :hello) end)
```

---

## 22. alias, require, import, use

```elixir
alias Foo.Bar               # now usable as Bar
alias Foo.Bar, as: Baz      # custom alias name

require Integer             # needed for macros
Integer.is_odd(3)           # works because we required it

import List, only: [duplicate: 2]   # can call duplicate(...) directly

use ExUnit.Case             # runs the module's __using__ macro
```

### Multi-alias

```elixir
alias MyApp.{Foo, Bar, Baz}    # aliases all three at once
```

### Lexical Scope

All four are scoped to the enclosing block:
```elixir
defmodule Math do
  def plus(a, b) do
    alias Math.List
    # alias only works inside this function
  end
end
```

### use = require + __using__

```elixir
defmodule Example do
  use Feature, option: :value
end
# is equivalent to:
defmodule Example do
  require Feature
  Feature.__using__(option: :value)
end
```

---

## 23. Protocols

Protocols achieve polymorphism by dispatching based on data type.

```elixir
defprotocol Size do
  def size(data)
end

defimpl Size, for: BitString do
  def size(string), do: byte_size(string)
end

defimpl Size, for: Map do
  def size(map), do: map_size(map)
end

defimpl Size, for: Tuple do
  def size(tuple), do: tuple_size(tuple)
end
```

### Protocols and Structs

Structs need their own implementation (don't inherit from maps):
```elixir
defimpl Size, for: User do
  def size(_user), do: 2
end
```

### Deriving

```elixir
defimpl Size, for: Any do
  def size(_), do: 0
end

defmodule OtherUser do
  @derive [Size]
  defstruct [:name, :age]
end
```

### Built-in Protocols

- `Enumerable` — powers `Enum` module
- `Collectable` — powers `for ... into:`
- `String.Chars` — powers `to_string/1` and `"#{...}"` interpolation
- `Inspect` — powers `inspect/1` and `IO.inspect/2`
- `Access` — powers `map[key]` and `Keyword` access

---

## 24. Error Handling

| Erlang | Elixir |
|--------|--------|
| `raise` | `raise "msg"` or `raise RuntimeError, message: "..."` |
| `try ... of ... catch _:_ -> ... end` | `try do ... rescue _ -> ... end` |
| `throw(Term)` then `catch` | `throw(term)` then `catch` |
| `exit(Reason)` | `exit(reason)` |
| `error(Reason)` | `raise` |
| `after` block | `after` block (same) |

**From the project** — Erlang try/catch:
```erlang
Ans = try calculate_posfix(PosFix, []) of
          Temp -> Temp
      catch
          _:_ -> error
      end,
```

**Elixir:**
```elixir
ans =
  try do
    calculate_posfix(pos_fix, [])
  rescue
    _ -> :error
  end
```

### Reraise (for logging/monitoring)

```elixir
try do
  ... some code ...
rescue
  e ->
    Logger.error(Exception.format(:error, e, __STACKTRACE__))
    reraise e, __STACKTRACE__
end
```

### after

```elixir
{:ok, file} = File.open("sample", [:utf8, :write])
try do
  IO.write(file, "olá")
  raise "oops"
after
  File.close(file)          # runs regardless
end
```

### throw/catch (rare)

```elixir
try do
  Enum.each(-50..50, fn x ->
    if rem(x, 13) == 0, do: throw(x)
  end)
catch
  x -> "Got #{x}"
end
```

### let-it-crash philosophy

In Elixir, we let processes fail and rely on supervisors to restart them. `try/rescue` is used less often than in other languages. Prefer pattern matching (`case`, `with`) on `{:ok, _}` / `{:error, _}` tuples.

---

## 25. Error Handling — `!` Functions

Many Elixir modules have `foo/1` returning `{:ok, result} | {:error, reason}` and `foo!/1` returning the unwrapped result or raising:

```elixir
File.read("file")     # {:ok, "content"} | {:error, :enoent}
File.read!("file")    # "content" or raises File.Error

# NOT:
{:ok, body} = File.read("unknown")     # will crash with MatchError
```

---

## 26. Recursion

Elixir has no loop constructs. Use recursion or high-level `Enum` functions:

```elixir
defmodule Recursion do
  def print_multiple_times(msg, n) when n > 0 do
    IO.puts(msg)
    print_multiple_times(msg, n - 1)
  end

  def print_multiple_times(_msg, 0), do: :ok
end
```

Tail-call optimization works the same as in Erlang.

---

## 27. Comprehensions — for

Standard list comprehension:
```elixir
for x <- [1, 2, 3, 4], do: x * x
```

With filters:
```elixir
for n <- 0..5, rem(n, 3) == 0, do: n * n
```

Multiple generators:
```elixir
for dir <- dirs, file <- File.ls!(dir), File.regular?(Path.join(dir, file)) do
  File.stat!(Path.join(dir, file)).size
end
```

---

## 28. Binaries and Bitstrings

Same syntax as Erlang:
```elixir
<<acc_y::16-integer-signed, temp::16, gyro_x::16-integer-signed>>
```

**From the project** — Erlang:
```erlang
<<AccY:16/integer-signed, AccZ:16/integer-signed, Temp:16, GyroX:16/integer-signed>>
```
**Elixir:**
```elixir
<<accy::integer-signed-16, accz::integer-signed-16, temp::16, gyrox::integer-signed-16>>
```

Note: Elixir uses `::` (not `/`) and the order is `type-size-unit` not `size/type-unit`.

---

## 29. IO and File System

```elixir
IO.puts("hello")               # print to stdout
IO.puts(:stderr, "error")      # print to stderr
IO.gets("yes or no? ")         # read a line

File.read("path")              # {:ok, content} | {:error, reason}
File.read!("path")             # content | raise
File.write("path", content)    # :ok | {:error, reason}
File.open("path", [:write])    # {:ok, pid}
File.close(pid)

Path.join("foo", "bar")        # "foo/bar"
Path.expand("~/hello")         # "/home/user/hello"
```

---

## 30. Mix Project Structure

| Aspect | Erlang | Elixir |
|--------|--------|--------|
| Build tool | `rebar3` / `erlc` | `mix` |
| Config file | `rebar.config` | `mix.exs` |
| Source dir | `src/` | `lib/` |
| Test dir | `test/` | `test/` |
| Headers | `include/*.hrl` | none (use modules) |
| Build output | `_build/` | `_build/` |
| Formatter | none | `.formatter.exs` |

**Generated `mix.exs`:**
```elixir
defmodule Calculator.MixProject do
  use Mix.Project

  def project do
    [
      app: :calculator,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      atomvm: [
        start: Calculator,
        flash_offset: 0x250000
      ]
    ]
  end

  def application do
    [extra_applications: [], mod: {Calculator, []}]
  end

  defp deps do
    [{:exatomvm, git: "https://github.com/atomvm/exatomvm.git", branch: "main"}]
  end
end
```

### Environments

- `:dev` — default for `mix compile`
- `:test` — default for `mix test`
- `:prod` — `MIX_ENV=prod mix compile`

Access: `Mix.env()` (but only in `mix.exs` config, never in application code)

### Key Mix commands

| Command | Description |
|---------|-------------|
| `mix new project` | Create new project |
| `mix compile` | Compile |
| `mix test` | Run tests |
| `mix test file:line` | Run single test |
| `mix format` | Format code |
| `mix format --check-formatted` | CI check |
| `mix deps.get` | Fetch dependencies |
| `mix help` | List all tasks |
| `iex -S mix` | Start IEx with project loaded |

---

## 31. ExUnit Testing

| Erlang (EUnit) | Elixir (ExUnit) |
|--------|--------|
| `-module(my_test).` | `defmodule MyTest do` |
| `-include_lib("eunit/include/eunit.hrl").` | `use ExUnit.Case` |
| `my_test() -> ?assertEqual(1, 1).` | `test "my test" do assert 1 == 1 end` |
| `?assertEqual(A, B)` | `assert a == b` |
| `?assertNotEqual(A, B)` | `refute a == b` |

```elixir
defmodule KVTest do
  use ExUnit.Case
  doctest KV

  test "greets the world" do
    assert KV.hello() == :world
  end
end
```

**`test/test_helper.exs`:**
```elixir
ExUnit.start()
```

---

## 32. Configuration

Elixir has a config system:

```elixir
# config/config.exs
import Config

config :calculator, :lcd,
  address: 0x27,
  scl_pin: 22,
  sda_pin: 21
```

Access at runtime:
```elixir
Application.get_env(:calculator, :lcd)[:address]
```

---

## 33. Macros (Elixir only — no Erlang equivalent)

```elixir
defmodule MyMacros do
  defmacro double(expr) do
    quote do
      unquote(expr) * 2
    end
  end
end

import MyMacros
double(5)   # → 10 at compile time
```

Macros enable DSLs, but use them sparingly. Most of the time `alias`, `import`, `use` are sufficient.

---

## 34. Debugging

### IO.inspect — returns the item (safe in pipelines)

```elixir
1..10
|> IO.inspect(label: "before")
|> Enum.map(&(&1 * 2))
|> IO.inspect(label: "after")
|> Enum.sum()
```

### dbg — enhanced debugging (v1.14+)

```elixir
# In your code:
dbg(Map.put(feature, :in_version, "1.14.0"))

# At each pipeline step:
"myfile.txt"
|> String.split("/")
|> List.last()
|> dbg()

# With IEx:
$ iex --dbg pry        # stops at dbg calls, interactive
```

### Breakpoints

```elixir
# In IEx:
IEx.break!(URI.parse/1)
# Then run code — execution stops at the breakpoint
$ iex -S mix test --breakpoints --failed
```

### Observer

```elixir
$ iex
iex> :observer.start()
```

---

## 35. IEx vs Erlang Shell

| Action | `erl` | `iex` |
|--------|-------|-------|
| Start | `erl` | `iex` |
| Compile | `c(Module)` | `c "path/to/file.ex"` |
| Run module | `Module:function(Arg).` | `Module.function(arg)` |
| History | `Ctrl+P`/`Ctrl+N` | `Up`/`Down` |
| Help | `help().` | `h()` |
| Info | `Module:module_info().` | `i(Module)` |
| Recompile | (manual) | `recompile()` |
| Flush mailbox | `flush().` | `flush()` |

---

## 36. Summary of Naming Conventions

| Item | Erlang | Elixir |
|------|--------|--------|
| Module | `calculator` | `Calculator` |
| File | `calculator.erl` | `calculator.ex` |
| Nested module | N/A | `SnakeBlockbreaker.WiFi` → file `snake_blockbreaker/wifi.ex` |
| Variables | `CamelCase` | `snake_case` |
| Atoms | `ok` | `:ok` |
| Private function | omit from export | `defp` |
| Truthy | `true` only | `true` and anything except `false`/`nil` |
| String literal | `"hello"` (charlist) | `"hello"` (binary) |

---

## ⭐ 15 Key Gotchas for Erlang Programmers

1. **`=` rebinds** — It's not just match. Use `^x` to force a match on existing variable.

2. **Atoms need `:` prefix** — Always `:ok`, never `ok` alone. `true`, `false`, `nil` are exceptions (no colon needed).

3. **Strings are binaries** — `"hello"` = `<<104,101,108,108,111>>`, not `[104,101,108,108,111]`. Charlists use `~c"hello"` or `'hello'`.

4. **No `,` `;` `.` terminators** — Blocks end with `end`. No commas between consecutive expressions in a block.

5. **`if` is 2-branch only** — `if/else/end`. For 3+ branches, use `cond do ... end`.

6. **`try ... catch` → `try ... rescue`** for exceptions. Prefer `with`/`case` for control flow. `rescue` is for exceptional cases, not pattern matching.

7. **`Enum` replaces `lists:*`** — `lists:map` → `Enum.map`, `lists:foldl` → `Enum.reduce`, etc.

8. **`defp` = private** — No export list. Omit from `-export` not needed.

9. **`use GenServer` sets up callbacks** — You only need to override what you need. Use `@impl true` — it catches mismatches at compile time.

10. **`_` in numbers** — `1_000_000` is valid. Use for readability.

11. **Module attributes are compile-time** — `@attr` is computed at compile time, not runtime. Use `Application.get_env/3` for runtime config.

12. **`__MODULE__`** = current module atom (`Calculator` in Elixir).

13. **Map access** — `map.key` works on maps/structs with atom keys. `map[:key]` uses the `Access` protocol (works on maps and keyword lists).

14. **No `.hrl` header files** — Shared constants go in a module. Use `alias` instead of include.

15. **Mix handles compilation** — No manual `-export` ordering. No recursive make. Dependencies declared in `mix.exs`.
