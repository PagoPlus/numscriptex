defmodule Numscriptex.Run do
  @moduledoc """
  A [numscript](https://docs.formance.com/numscript/) needs some other data aside from
  the script itself to run correctly, and `Numscriptex.Run` solves this problem.

  If you want to know what exactly these additional fields are, you can learn more on 
  [numscript playground](https://playground.numscript.org/?template=simple-send)
  and the [numscript docs](https://docs.formance.com/numscript/).
  """

  defstruct variables: %{},
            balances: %{},
            metadata: %{}

  @valid_fields ~w(
    variables
    balances
    metadata
  )a

  @typedoc """
  Type that represents `Numscriptex.Run` struct.

  `:balances`: the account's assets balances.
  `:metadata`: metadata variables.
  `:variables`: variables used inside the script.
  """
  @type t() :: %__MODULE__{
          variables: map(),
          balances: map(),
          metadata: map()
        }

  @doc """
  Creates a new `Numscriptex.Run{}` struct.

  ```elixir
  iex>  Numscriptex.Run.new()
  %Numscriptex.Run{
    variables: %{},
    balances: %{},
    metadata: %{}
  }
  ```
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Puts the chosen value under the field key on the `Numscriptex.Run` struct as 
  long both are valid.

  ```elixir
  iex> struct = Numscriptex.Run.new()
  ...> balances =  %{"foo" => %{"USD/2" => 500, "EUR/2" => 300}}
  ...>
  ...> Numscriptex.Run.put(struct, :balances, balances)
  {:ok, 
    %Numscriptex.Run{
      balances: %{"foo" => %{"USD/2" => 500, "EUR/2" => 300}},
      variables: %{},
      metadata: %{}
    }
  }
  ```
  If the value or the field key are invalid, `put/3` will return a 3 element
  error tuple. Ex:

  ```elixir
  iex> struct = Numscriptex.Run.new()
  ...>
  ...> Numscriptex.Run.put(struct, :invalid_field, %{})
  {:error, :invalid_field, %{details: "The field 'invalid_field' does not exists."}}
  ```
  """
  @spec put(t(), atom(), map()) :: {:ok, t()} | {:error, atom(), map()}
  def put(run_struct, field, value \\ %{})

  def put(_run_struct, field, _value) when field not in @valid_fields,
    do: {:error, :invalid_field, %{details: "The field '#{field}' does not exists."}}

  def put(_run_struct, _field, value) when not is_map(value),
    do: {:error, :invalid_value, %{details: "Values argument must be a map."}}

  def put(%__MODULE__{} = run_struct, :balances, value) do
    {:ok, Map.replace(run_struct, :balances, Utilities.normalize_keys(value, :string))}
  end

  def put(%__MODULE__{} = run_struct, field, value) do
    {:ok, Map.replace(run_struct, field, value)}
  end

  @doc """
  Same as `put/3`, but raises an exception if any argument is invalid.

  ```elixir
  iex> struct = Numscriptex.Run.new()
  ...> balances =  [%{"foo" => %{"USD/2" => 500, "EUR/2" => 300}}]
  ...>
  ...> Numscriptex.Run.put!(struct, :balances, balances)
  ** (ArgumentError) Values argument must be a map.
  ```
  """
  @spec put!(t(), atom(), map()) :: t() | no_return()
  def put!(run_struct, field, value) do
    case put(run_struct, field, value) do
      {:ok, result} ->
        result

      {:error, _reason, %{details: message}} ->
        raise ArgumentError, message: message
    end
  end
end
