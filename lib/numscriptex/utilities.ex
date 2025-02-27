defmodule Numscriptex.Utilities do
  @moduledoc """
  `Numscriptex.Utilities` module contain reusable code that are common in more than one module
  of this library.
  """

  @doc """
  Convert map keys to the desired type. Can go from string to atom and vice versa.

  ```elixir
  iex> map = %{"foo" => 100}
  ...> Utilities.normalize_keys(map, :atom)
  %{foo: 100}

  iex> map = %{foo: 100}
  ...> Utilities.normalize_keys(map, :string)
  %{"foo" => 100}
  ```
  """
  @spec normalize_keys(map(), :string | :atom) :: map()
  def normalize_keys(map, :string) when is_map(map) do
    Map.new(map, &keys_to_string/1)
  end

  def normalize_keys(map, :atom) when is_map(map) do
    Map.new(map, &keys_to_atom/1)
  end

  defp keys_to_string({key, value}) when is_map(value),
    do: {to_string(key), normalize_keys(value, :string)}

  defp keys_to_string({key, value}) when is_list(value),
    do: {to_string(key), Enum.map(value, &normalize_keys(&1, :string))}

  defp keys_to_string({key, value}),
    do: {to_string(key), value}

  defp keys_to_atom({key, value}) when is_map(value),
    do: {String.to_existing_atom(key), normalize_keys(value, :atom)}

  defp keys_to_atom({key, value}) when is_list(value),
    do: {String.to_existing_atom(key), Enum.map(value, &normalize_keys(&1, :atom))}

  defp keys_to_atom({key, value}),
    do: {String.to_existing_atom(key), value}

  @doc """
  Converts an integer value to float

  ```elixir
  iex> Utilities.integer_to_decimal(1000, 2)
  10.0

  iex> Utilities.integer_to_decimal(1000, 3)
  1.0

  iex> Utilities.integer_to_decimal(1000, 4)
  0.1

  iex> Utilities.integer_to_decimal(1000, 5)
  0.01
  ```
  """
  @spec integer_to_decimal(pos_integer(), pos_integer() | nil) :: float()
  def integer_to_decimal(amount, decimal_places \\ 2)

  def integer_to_decimal(amount, nil), do: integer_to_decimal(amount)

  def integer_to_decimal(amount, decimal_places) do
    divisor =
      10
      |> Integer.pow(decimal_places)
      |> trunc()

    amount / divisor
  end

  @doc """
  Gets the decimal places from an asset if has any (e.g. decimal places for "USD/2" would be 2).
  You can choose a default value (the second argument), but if you don't choose any the default will be 2.

  ```elixir
  iex> Utilities.decimal_places_from_asset("USD/2")
  2

  iex> Utilities.decimal_places_from_asset("USD/4")
  4

  iex> Utilities.decimal_places_from_asset("USD")
  2

  iex> Utilities.decimal_places_from_asset("USD", 3)
  3
  ```
  """
  @spec decimal_places_from_asset(bitstring(), pos_integer()) :: pos_integer()
  def decimal_places_from_asset(asset, default \\ 2) do
    if String.length(asset) >= 5 do
      asset
      |> String.last()
      |> String.to_integer()
    else
      default
    end
  end
end
