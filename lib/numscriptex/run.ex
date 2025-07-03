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
            feature_flags: []

  alias Numscriptex.Utilities

  @valid_fields ~w(
    variables
    balances
    metadata
    feature_flags
  )a

  @valid_feature_flags ~w(
    experimental_overdraft_function
    experimental_get_asset_function
    experimental_get_amount_function
    experimental_oneof
    experimental_account_interpolation
    experimental_mid_script_function_call
    experimental_asset_colors
  )a

  @typedoc """
  Type that represents `Numscriptex.Run` struct.

  ## Fields
  * `:balances` a map with account's assets balances
  * `:metadata` [metadata variables](https://docs.formance.com/modules/numscript/reference/metadata)
  * `:variables` [variables](https://docs.formance.com/modules/numscript/reference/variables)
  * `:feature_flags` a list of feature flags used to enable experimental features
  """
  @type t() :: %__MODULE__{
          variables: map(),
          balances: map(),
          metadata: map(),
          feature_flags: list()
        }

  @doc """
  Creates a new `Numscriptex.Run{}` struct.

  ```elixir
  iex>  Numscriptex.Run.new()
  %Numscriptex.Run{
    variables: %{},
    balances: %{},
    metadata: %{},
    feature_flags: []
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
      feature_flags: []
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
  def put(run_struct, field, value)

  def put(_run_struct, field, _value) when field not in @valid_fields,
    do: {:error, :invalid_field, %{details: "The field '#{field}' does not exists."}}

  def put(_run_struct, :feature_flags, value) when not is_list(value),
    do:
      {:error, :invalid_value,
       %{details: "Argument `value` for field `feature_flags` must be a list."}}

  def put(_run_struct, field, value) when field != :feature_flags and not is_map(value),
    do:
      {:error, :invalid_value, %{details: "Argument `value` for field `#{field}` must be a map."}}

  def put(%__MODULE__{} = run_struct, :feature_flags, flags) do
    invalid_flags = Enum.filter(flags, &(&1 not in @valid_feature_flags))

    if invalid_flags == [] do
      {:ok, Map.replace(run_struct, :feature_flags, flags)}
    else
      err_msg =
        "Invalid feature flag(s). See `Numscriptex.Run.list_available_feature_flags/0` for a list of valid feature flags."

      {:error, :invalid_value, %{details: err_msg}}
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
  ** (ArgumentError) Argument `value` for field `balances` must be a map.
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
  Normalizes the `Numscriptex.Run` struct to a map.

  ```elixir
  iex> struct =
  ...>   Numscriptex.Run.put!(Numscriptex.Run.new(), :feature_flags, [:experimental_overdraft_function])
  ...>
  ...> Numscriptex.Run.normalize_to_map(struct)
  %{
    balances: %{},
    metadata: %{},
    variables: %{},
    featureFlags: %{"experimental-overdraft-function" => %{}}
  }
  ```
  """
  @spec normalize_to_map(__MODULE__.t()) :: map()
  def normalize_to_map(%__MODULE__{} = run_input) do
    feature_flags = normalize_feature_flags(run_input)

    run_input
    |> Map.from_struct()
    |> Map.delete(:feature_flags)
    |> Map.put(:featureFlags, feature_flags)
  end

  defp normalize_feature_flags(run_input) do
    stringified_flags =
      run_input
      |> Map.get(:feature_flags, [])
      |> Enum.map(fn flag ->
        flag
        |> to_string()
        |> String.replace("_", "-")
      end)

    stringified_flags
    |> Enum.map(fn flag -> {flag, %{}} end)
    |> Enum.into(%{})
  end

  @doc """
  Lists all available feature flags.
  ```elixir
  iex> Numscriptex.Run.list_available_feature_flags()
  [
    :experimental_overdraft_function,
    :experimental_get_asset_function,
    :experimental_get_amount_function,
    :experimental_oneof,
    :experimental_account_interpolation,
    :experimental_mid_script_function_call,
    :experimental_asset_colors
  ]
  ```
  """
  @spec list_available_feature_flags() :: list(atom())
  def list_available_feature_flags, do: @valid_feature_flags
end
