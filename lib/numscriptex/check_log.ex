defmodule Numscriptex.CheckLog do
  @moduledoc """
  After you check your numscript you might get a variety of logs even if it is valid,
  `Numscriptex.CheckLog` is responsible for standardize these logs.
  """

  @derive JSON.Encoder

  defstruct character: nil,
            level: nil,
            line: nil,
            message: nil

  @typedoc """
  Type that represents `Numscriptex.CheckLog` struct.

  ## Fields
  * `:character` the character position where the log occurred
  * `:level` the log level
  * `:line` the line where the log occur
  * `:message` the log message
  """
  @type t() :: %__MODULE__{
          character: pos_integer(),
          level: log_levels(),
          line: pos_integer(),
          message: binary()
        }

  @type log_levels() :: :error | :warning | :hint | :info

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
