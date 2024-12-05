defmodule Numscriptex.Run do
  defstruct [
    variables: [],
    balances: [],
    metadata: [],
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
    do: {:error, :invalid_field, %{message: "Field #{field} does not exists."}}

  def put(_run_struct, field, value) when field != :numscript and not is_map(value),
  do: {:error, :invalid_value, %{message: "Values except :numscript must be a map."}}

  def put(_run_struct, :numscript, value) when not is_binary(value),
  do: {:error, :invalid_value, %{message: "The :numscript value must be a binary."}}

  def put(%__MODULE__{} = run_struct, field, value) do
    {:ok, Map.replace(run_struct, field, value)}
  end

  @spec put!(t(), atom(), map()) :: t() | no_return()
  def put!(run_struct, field, value) do
    case put(run_struct, field, value) do
      {:ok, result} ->
        result
      {:error, _reason, message} -> 
        raise ArgumentError.message(message)
    end
  end
end
