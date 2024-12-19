defmodule Common do
  @moduledoc """
  `Common` module contain reusable code that are common in more than one module
  of this library.
  """

  @doc """
  Convert map keys to the desired type. Can go from string to atom and vice versa.

  ```elixir
  iex> map = %{"foo" => 100}
  ...> Common.normalize_keys(map, :atom)
  %{foo: 100}

  iex> map = %{foo: 100}
  ...> Common.normalize_keys(map, :string)
  %{"foo" => 100}
  ```
  """
  def normalize_keys(map, :string) when is_map(map) do
    Map.new(map, &keys_to_string/1)
  end

  def normalize_keys(map, :atom) when is_map(map) do
    Map.new(map, &keys_to_atom/1)
  end

  defp keys_to_string({key, value}) when is_map(value),
    do: {to_string(key), normalize_keys(value, :string)}

  defp keys_to_string({key, value}),
    do: {to_string(key), value}

  defp keys_to_atom({key, value}) when is_map(value),
    do: {String.to_atom(key), normalize_keys(value, :atom)}

  defp keys_to_atom({key, value}),
    do: {String.to_atom(key), value}
end
