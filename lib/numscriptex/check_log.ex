defmodule Numscriptex.CheckLog do
  @moduledoc """
  `Numscriptex.CheckLog` is resposible for a better user experience with the 
  logs you get after checking your script with `Numscriptex.check/1`.
  """
  defstruct character: nil,
            level: nil,
            line: nil,
            message: nil

  @type t() :: %__MODULE__{
    character:  integer(),
    level: atom(),
    line: integer(),
    message: binary()
  } 

  @doc """
  Get a map with log data about a checked numscript.

  ```elixir
  iex> map = %{
  ...>   character: 10,
  ...>   level:  :warning,
  ...>   line: 1,
  ...>   message: "warning message"
  ...> }
  ...>
  ...> Numscriptex.CheckLog.from_map(map)
  %Numscriptex.CheckLog{
    character: 10,
    level:  :warning,
    line: 1,
    message: "warning message"
  }
  ```
  """
  @spec from_map(map()) :: __MODULE__.t()
  def from_map(map) do
    struct(__MODULE__, normalize(map))
  end

  defp normalize(map) do
    Map.new(map, fn 
      {:error, value} ->  
        {:message, value}

      {:warning, value} ->  
        {:message, value}

      {:info, value} ->  
        {:message, value}

      {:hint, value} ->  
        {:message, value}

      pair -> 
        pair
    end)
  end
end
