defmodule Numscriptex.Run do
  defstruct [
    variables: %{},
    balances: %{},
    metadata: %{},
  ]

  @valid_fields ~w(
    variables
    balances
    metadata
  )a

  @type t() :: %__MODULE__{
    variables: map(),
    balances: map(),
    metadata: map(),
  }

  @spec put(t(), atom(), map()) :: {:ok, t()} | {:error, atom(), map()}
  def put(_run_struct, field, _value) when field not in @valid_fields,
    do: {:error, :invalid_field, %{details: "The field '#{field}' does not exists."}}

  def put(_run_struct, _field, value) when not is_map(value),
  do: {:error, :invalid_value, %{details: "Values argument must be a map."}}

  def put(%__MODULE__{} = run_struct, :balances, value) do
    {:ok, Map.replace(run_struct, :balances, normalize_balances(value))}
  end

  def put(%__MODULE__{} = run_struct, field, value) do
    {:ok, Map.replace(run_struct, field, value)}
  end

  defp normalize_balances(balances) when is_map(balances) do
    Map.new(balances, &keys_to_string/1)
  end

  defp keys_to_string({key, value}) when is_map(value), 
  do: {to_string(key), normalize_balances(value)}

  defp keys_to_string({key, value}), 
  do: {to_string(key), value}

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
