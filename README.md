# NumscripEx
NumscriptEx allows its users to check and run numscripts via Elixir. 

## Installation
You will just need to add `:numscriptex` as a dependency on your `mix.exs`, and run the `mix deps.get` command:

```
def deps do
  [
    {:numscriptex, "~> 0.1.0"}
  ]
end
```

## Usage
This library basically have two core functions: `Numscriptex.check/1` and `Numscriptex.run/2`. Both functions return a two element tuple, where the first element is either `:ok` or `:error`, and the second element will always be a map with the `:reason` (and sometimes `:details`) keys.

Before we talk about these two functions, I need to explain the `Numscriptex.Run`module first.

### Numscriptex.Run
This module is an abstraction of the json input that the numscript needs to run correctly. If yout don't know what this "input" is, you can check the [Numscript playground](https://playground.numscript.org/?template=simple-send).

The abstraction is made by creating a struct:
```
iex>  %Numscriptex.Run{
iex>    balances: %{},
iex>    metadata: %{},
iex>    variables: %{}
iex>  }
```

And to create a new one, you can use the `put/3` or `put!/3` functions. Ex: 
```
iex>  Numscriptex.Run.new()
iex>    |> Numscriptex.Run.put!(:balances, balances)
iex>	|> Numscriptex.Run.put!(:metadata, metadata)
iex>	|> Numscriptex.Run.put!(:variables, variables)
```

### Check
To use `check/1` you just have to pass your numscript as it's argument. Ex:
```
iex>  "your_path/your_file.num"
iex>  |> File.read!()
iex>  |> Numscriptex.check()
```
You don´t need to necessarily read from a file, as long as it is a binary it's fine.

The code above will return:
```
	{:ok, %{script: <your_script>}}
```

If have any, it could also return some warnings, infos or hints inside the map.
```
	{:ok, %{
			script: <your_script>,
			warnings: <warnings_list>,
			hints: <hints_list>,
			infos: <infos_list>
		}
	}
```

### Run
To use `run/2` your first argument must be your script (the same you used in `check/1`), and the second must be the `%Numscriptex.Run{}` struct. Ex:

```
  iex>  Numscriptex.run(script, struct)
  {:ok, result}
```

Where result will be something like this: 
```
    %{
      "postings" => postings # a list with maps
      "balances" => balances # also a list with maps
      "accountMeta" => %{} 
      "txMeta" => %{} 
    }
```

## License
TODO
