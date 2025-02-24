# NumscriptEx
NumscriptEx is a library that allows its users to check and run Numscripts in Elixir. If this is your first time hearing about
Numscripts, here is a quick explanation:

[Numscript](https://docs.formance.com/numscript/) is a DSL made by [Formance](https://www.formance.com/)
that simplifies complex financial transactions with scripts that are easy to read,
so you don't need a big, complex and error-prone codebase to deal with your finances.

You can see and execute some examples at the [Numscript Playground](https://playground.numscript.org/?template=simple-send).

## Installation
You will just need to add `:numscriptex` as a dependency on your `mix.exs`, and run the `mix deps.get` command:

```elixir
def deps do
  [
    {:numscriptex, "~> 0.2.2"}
  ]
end
```
### Configuration
NumscriptEx needs some external assets ([Numscript-WASM](https://github.com/PagoPlus/numscript-wasm)),
and you can override the default version.

Available configurations:
- `:version` the binary release version to use (see [numscript-wasm releases](https://github.com/PagoPlus/numscript-wasm/releases/)).
- `:retries` number of times to retry the download in case of a network failure.

Ex:
```elixir
config :numscriptex,
       version: "0.0.2",
       retries: 3
```
These above are the default values.

## Usage
This library basically has two core functions: `Numscriptex.check/1` and `Numscriptex.run/2`.

Want to check if your script is valid and ready to go? Use the `check/1` function.
Already checked the script and want to execute it? Use the `run/2` function.

But before introducing these two functions, you will need to know what is the `Numscriptex.Run` struct.

### Numscriptex.Run
A numscript needs some other data aside the script itself to run correctly, and
`Numscriptex.Run` solves this problem.

If you want to know what exactly these additional data are, you can see the
[Numscript Playground](https://playground.numscript.org/?template=simple-send) for examples.

The abstraction is made by creating a struct:
```elixir
iex>  %Numscriptex.Run{
...>    balances: %{},
...>    metadata: %{},
...>    variables: %{}
...>  }
```
Where:
- `:balances` a map with the account's assets balances.
- `:metadata` [metada variables](https://docs.formance.com/numscript/reference/metadata);
- `:variables` [variables](https://docs.formance.com/numscript/reference/variables) used inside the script.

And to create a new struct, you can use the `Numscriptex.Run.put/3` or `Numscriptex.Run.put!/3` functions. Ex:
```elixir
iex>  variables = %{"order" => "orders:2345"}
...>  balances = %{"orders:2345" => %{"USD/2" => 1000}}
...>  metadata = %{
...>    "merchants:1234" => %{"commission" => "15%"},
...>    "orders:2345" => %{"merchant" => "merchants:1234"}
...>  }
...>
...>  Numscriptex.Run.new()
...>  |> Numscriptex.Run.put!(:balances, balances)
...>  |> Numscriptex.Run.put!(:metadata, metadata)
...>  |> Numscriptex.Run.put!(:variables, variables)
```

Will return:

```elixir
iex> %Numscriptex.Run{
...>   variables: %{"orders:2345" => %{"USD/2" => 1000}},
...>   balances: %{"order" => "orders:2345"},
...>   metadata: %{
...>     "merchants:1234" => %{"commission" => "15%"},
...>     "orders:2345" => %{"merchant" => "merchants:1234"}
...>   }
...> }
```

Kindly reminder: you will always need a valid `Numscriptex.Run` struct to successfully execute your scripts.

### Check
To use `Numscriptex.check/1` you just have to pass your numscript as it's argument. Ex:

```elixir
iex>  "tmp/script.num"
...>  |> File.read!()
...>  |> Numscriptex.check()
{:ok, %{script: script}
```

You don´t need to necessarily read from a file, as long as it is a string it's fine.

Sometimes, even if your script is valid, it could also return some warnings, infos or hints inside the map.
Ex:
```elixir
iex> {:ok, %{
...>     script: "your numscript here",
...>     warnings: [
...>             %CheckLog{
...>               character: 10,
...>               level: :warning,
...>               line: 1,
...>               message: "warning message"
...>             }
...>           ],
...>     hints: [
...>             %CheckLog{
...>               character: 2,
...>               level: :hint,
...>               line: 7,
...>               message: "hint message"
...>             }
...>           ],
...>     infos: [
...>             %CheckLog{
...>               character: 9,
...>               level: :info,
...>               line: 14,
...>               message: "info message"
...>             }
...>           ]
...>   }
...> }
```
The `:script` is the only field that will always return if your script is valid, the other three are optional.
### Run
To use `Numscriptex.run/2` your first argument must be your script (the same you used in `Numscriptex.check/1`), and the second must be the `%Numscriptex.Run{}` struct. Ex:

```elixir
iex>  Numscriptex.run(script, struct)
{:ok, result}
```

Where result will be something like this:
```elixir
iex> %{
...>   postings: [
  ...>           %Numscriptex.Posting{
...>             amount: 100,
...>             asset: "USD/2",
...>             destination: "bar",
...>             source: "foo"
...>           }
...>         ],
...>   balances: [
...>           %Numscriptex.Balance{
...>             account: "foo",
...>             asset: "EUR/2",
...>             final_balance: 300,
...>             initial_balance: 300
...>           },
...>           %Numscriptex.Balance{
...>             account: "foo",
...>             asset: "USD/2",
...>             final_balance: 400,
...>             initial_balance: 500
...>           },
...>           %Numscriptex.Balance{
...>             account: "bar",
...>             asset: "USD/2",
...>             final_balance: 100,
...>             initial_balance: 0
...>           }
...>         ],
...>   accountMeta: %{}
...>   txMeta: %{}
...> }
```

## License
Copyright (c) 2025 MedFlow

This library is MIT licensed. See the [LICENSE](https://github.com/PagoPlus/numscriptex/blob/main/LINCESE) for details.
