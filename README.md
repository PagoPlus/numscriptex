# NumscriptEx
[![Hex Version](https://img.shields.io/hexpm/v/numscriptex.svg)](https://hex.pm/packages/numscriptex)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/numscriptex/)

NumscriptEx is a library that allows its users to run Numscripts in Elixir. If this is your first time hearing about
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
    {:numscriptex, "~> 0.2.5"}
  ]
end
```
### Configuration
NumscriptEx needs some external assets ([Numscript-WASM](https://github.com/PagoPlus/numscript-wasm)),
and you can override the default version.

Available configurations:
- `:version` the binary release version to use (see [numscript-wasm releases](https://github.com/PagoPlus/numscript-wasm/releases/)).
- `:retries` number of times to retry the download in case of a network failure.
- `:binary_path` where the WASM binary file will be downloaded

Ex:
```elixir
config :numscriptex,
       binary_path: :numscriptex |> :code.priv_dir() |> Path.join("numscript.wasm")
       version: "0.1.0",
       retries: 3
```
These above are the default values.

## Usage
You can build Numscripts dynamically with `Numscriptex.Builder.build/1` and run your script with `Numscriptex.run/2`.

You can read more about the `Numscriptex.Builder` module and how to use it on its [guide](https://hexdocs.pm/numscriptex/builder-introduction.html)

And before introducing the other two functions, you will need to know what is the `Numscriptex.Run` struct.

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
...>    variables: %{},
...>    feature_flags: []
...>  }
```
Where:
- `:balances` a map with the account's assets balances.
- `:metadata` [metada variables](https://docs.formance.com/modules/numscript/reference/metadata);
- `:variables` [variables](https://docs.formance.com/modules/numscript/reference/variables).
- `:feature_flags` feature flags that enables numscript experimental features.

And to create a new struct, you can use the `Numscriptex.Run.put/3` or `Numscriptex.Run.put!/3` functions. Ex:
```elixir
iex>  variables = %{"order" => "orders:2345"}
...>  balances = %{"orders:2345" => %{"USD/2" => 1000}}
...>  feature_flags = [:experimental_oneof]
...>  metadata = %{
...>    "merchants:1234" => %{"commission" => "15%"},
...>    "orders:2345" => %{"merchant" => "merchants:1234"}
...>  }
...>
...>  Numscriptex.Run.new()
...>  |> Numscriptex.Run.put!(:balances, balances)
...>  |> Numscriptex.Run.put!(:metadata, metadata)
...>  |> Numscriptex.Run.put!(:variables, variables)
...>  |> Numscriptex.Run.put!(:feature_flags, feature_flags)
```

Will return:

```elixir
iex> %Numscriptex.Run{
...>   variables: %{"orders:2345" => %{"USD/2" => 1000}},
...>   balances: %{"order" => "orders:2345"},
...>   feature_flags: [:experimental_oneof]
...>   metadata: %{
...>     "merchants:1234" => %{"commission" => "15%"},
...>     "orders:2345" => %{"merchant" => "merchants:1234"}
...>   }
...> }
```

Kindly reminder: you will always need a valid `Numscriptex.Run` struct to successfully execute your scripts.

### Run
To use `Numscriptex.run/2` you must pass your script as the first argument, and the `%Numscriptex.Run{}` struct as the second. Ex:

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
...>             decimal_amount: 1.0,
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
...>             initial_balance: 300,
...>             decimal_final_balance: 3.0,
...>             decimal_initial_balance: 3.0,
...>           },
...>           %Numscriptex.Balance{
...>             account: "foo",
...>             asset: "USD/2",
...>             final_balance: 400,
...>             initial_balance: 500,
...>             decimal_final_balance: 4.0,
...>             decimal_initial_balance: 5.0,
...>           },
...>           %Numscriptex.Balance{
...>             account: "bar",
...>             asset: "USD/2",
...>             final_balance: 100,
...>             initial_balance: 0,
...>             decimal_final_balance: 1.0,
...>             decimal_initial_balance: 0.0,
...>           }
...>         ],
...>   accountMeta: %{}
...>   txMeta: %{}
...> }
```

## License
Copyright (c) 2025 MedFlow

This library is MIT licensed. See the [LICENSE](https://github.com/PagoPlus/numscriptex/blob/main/LICENSE) for details.
