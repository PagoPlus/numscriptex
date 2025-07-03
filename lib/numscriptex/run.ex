defmodule Numscriptex.Run do
  @moduledoc """
  A Numscript needs some other data aside from the script itself to run correctly,
  and `Numscriptex.Run` solves this problem. If you want to know what exactly these
  additional fields are, you can learn more on [Numscript Playground](https://playground.numscript.org/?template=simple-send) and the [Numscript Docs](https://docs.formance.com/numscript/).
  """

  @derive JSON.Encoder
  defstruct variables: %{},
            balances: %{},
            metadata: %{},
            featureFlags: %{}

  alias Numscriptex.Utilities

  @valid_fields ~w(
    variables
    balances
    metadata
    featureFlags
  )a

  @valid_feature_flags ~w(
    experimental-overdraft-function
    experimental-get-asset-function
    experimental-get-amount-function
    experimental-oneof
    experimental-account-interpolation
    experimental-mid-script-function-call
    experimental-asset-colors
  )

  @typedoc """
  Type that represents `Numscriptex.Run` struct.

  ## Fields
  * `:balances` a map with account's assets balances
  * `:metadata` [metadata variables](https://docs.formance.com/modules/numscript/reference/metadata)
  * `:variables` [variables](https://docs.formance.com/modules/numscript/reference/variables)
  * `:featureFlags` feature flags used to enable experimental features
  """
  @type t() :: %__MODULE__{
          variables: map(),
          balances: map(),
          metadata: map(),
          featureFlags: map()
        }

  @doc """
  Creates a new `Numscriptex.Run{}` struct.

  ```elixir
  iex>  Numscriptex.Run.new()
  %Numscriptex.Run{
    variables: %{},
    balances: %{},
    metadata: %{},
    featureFlags: %{}
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
      metadata: %{},
      featureflags: %{}
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
    do: {:error, :invalid_value, %{details: "Argument `value` must be a map."}}

  def put(%__MODULE__{} = run_struct, :featureFlags, value) do
    invalid_flags =
      value
      |> Map.keys()
      |> Enum.filter(fn flag -> flag not in @valid_feature_flags end)

    if invalid_flags == [] do
      {:ok, Map.replace(run_struct, :featureFlags, value)}
    else
      {:error, :invalid_value, %{details: "The feature flag(s). See `Numscriptex.Run.list_available_feature_flags/0` for a list of valid feature flags."}}
    end
  end

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
  ** (ArgumentError) Argument `value` must be a map.
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

  @doc """
  Normalizes the feature flags in the `Numscriptex.Run` struct.

  ```elixir
  iex> struct =
  ...>   Numscriptex.Run.put!(Numscriptex.Run.new(), :featureFlags, %{"experimental-overdraft-function" => true})
  ...>
  ...> Numscriptex.Run.normalize_feature_flags(struct)
  %Numscriptex.Run{
    balances: %{},
    metadata: %{},
    variables: %{},
    featureFlags: %{"experimental-overdraft-function" => %{}}
  }
  ```
  """
  @spec normalize_feature_flags(__MODULE__.t()) :: __MODULE__.t()
  def normalize_feature_flags(%__MODULE__{} = run_input) do
    feature_flags =
      run_input
      |> Map.get(:featureFlags, %{})
      |> Enum.map(fn {key, _value} -> {key, %{}} end)
      |> Enum.into(%{})

    %{run_input | featureFlags: feature_flags}
  end

  @doc """
  Lists all available feature flags.
  ```elixir
  iex> Numscriptex.Run.list_available_feature_flags()
  [
    "experimental-overdraft-function",
    "experimental-get-asset-function",
    "experimental-get-amount-function",
    "experimental-oneof",
    "experimental-account-interpolation",
    "experimental-mid-script-function-call",
    "experimental-asset-colors"
  ]
  ```
  """
  @spec list_available_feature_flags() :: list(String.t())
  def list_available_feature_flags, do: @valid_feature_flags
end
