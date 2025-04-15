defmodule Numscriptex.Builder do
  @moduledoc """
  `Numscriptex.Builder` makes it possible to build Numscripts dynamically within your application.
  """

  @type percent_split() :: %{
          required(:type) => :fixed | :percent,
          required(:amount) => pos_integer(),
          optional(:account) => bitstring(),
          optional(:splits) => list(percent_split()),
          optional(:remaining_to) => bitstring()
        }

  @type fixed_split() :: %{
          required(:type) => :fixed | :percent,
          required(:amount) => pos_integer(),
          required(:account) => bitstring(),
          required(:asset) => bitstring()
        }

  @type metadata() :: %{
          required(:splits) => list(fixed_split()) | list(percent_split()),
          optional(:remaining_to) => bitstring(),
          optional(:percent_asset) => bitstring()
        }

  @doc """
  Receives a map with the metadata necessary to build your numscript.

  ```elixir
  iex> metadata = %{
  ...>   splits: [
  ...>     %{
  ...>       type: :fixed,
  ...>       amount: 500,
  ...>       asset: "BRL/2",
  ...>       account: "some:destination"
  ...>     }
  ...>   ]
  ...> }
  ...>
  ...> Numscriptex.Builder.build(metadata)
  {:ok, %{script: "send [BRL/2 500] (\n  source = @user\n  destination = @some:destination\n)\n"}}
  ```

  If you want to learn more about this feature you can check its guide [here](https://hexdocs.pm/numscriptex/builder-introduction.html)
  """
  @spec build(metadata()) :: {:ok, %{script: bitstring()}} | {:error, bitstring()}
  def build(%{splits: _splits} = metadata) do
    with {:ok, {port_splits, fixed_splits}} <- check_metadata(metadata) do
      remaining_dest = metadata[:remaining_to]
      asset = metadata[:percent_asset]
      port_numscript = maybe_build_portioned_numscript(port_splits, remaining_dest, asset)
      fixed_numscript = maybe_build_fixed_values_numscript(fixed_splits)

      {:ok, %{script: port_numscript <> fixed_numscript}}
    end
  end

  def build(_metadata), do: {:error, "Missing key on metadata."}

  defp check_metadata(%{splits: splits} = metadata) do
    percent_scripts = Enum.filter(splits, &(&1.type == :percent))
    has_percent? = percent_scripts != []
    has_percent_asset? = :percent_asset in Map.keys(metadata)

    fixed_scripts = filter_fixed_splits(splits)
    has_fixed? = fixed_scripts != []

    has_fixed_assets? =
      Enum.all?(fixed_scripts, fn
        %{asset: _asset} -> true
        _ -> false
      end)

    cond do
      has_percent? and has_percent_asset? and has_fixed_assets? ->
        {:ok, {percent_scripts, fixed_scripts}}

      has_fixed? and has_fixed_assets? ->
        {:ok, {percent_scripts, fixed_scripts}}

      true ->
        {:error, "Missing key on metadata."}
    end
  end

  defp filter_fixed_splits(splits, acc \\ [])

  defp filter_fixed_splits([%{type: :fixed} = split | tail], acc),
    do: filter_fixed_splits(tail, [split | acc])

  defp filter_fixed_splits([%{type: :percent, splits: splits} | _tail], acc),
    do: filter_fixed_splits(splits, acc)

  defp filter_fixed_splits([_split | tail], acc), do: filter_fixed_splits(tail, acc)
  defp filter_fixed_splits([], acc), do: acc

  defp maybe_build_portioned_numscript([], _remaining_dest, _asset), do: ""

  defp maybe_build_portioned_numscript(metadata, remaining_dest, asset) do
    initial = start_numscript(asset)

    metadata
    |> Enum.reduce(initial, fn data, acc -> acc <> build_numscript(data) end)
    |> close_numscript(remaining_dest)
  end

  defp maybe_build_fixed_values_numscript([]), do: ""

  defp maybe_build_fixed_values_numscript(metadata) do
    Enum.reduce(metadata, "", fn data, acc ->
      acc <> build_numscript(data)
    end)
  end

  defp build_numscript(%{type: :percent, splits: [_ | _] = splits} = metadata) do
    initial = start_portioned_dest(metadata.amount)

    splits
    |> Enum.reduce(initial, fn
      %{type: :percent} = split, acc ->
        acc <> build_numscript(split)

      _split, acc ->
        acc
    end)
    |> close_portioned_dest(metadata[:remaining_to])
  end

  defp build_numscript(%{amount: amount, account: dest, type: type, asset: asset})
       when type == :fixed do
    """
    send [#{asset} #{amount}] (
      source = @user
      destination = @#{dest}
    )
    """
  end

  defp build_numscript(%{amount: amount, account: dest, type: type}) when type == :percent do
    """
        #{amount}% to @#{dest}
    """
  end

  defp start_numscript(asset) do
    """
    send [#{asset} *] (
      source = @user
      destination = {
    """
  end

  defp start_portioned_dest(amount) do
    """
        #{amount}% to {
    """
  end

  defp close_numscript(script, nil) do
    script <>
      """
          remaining kept
        }
      )
      """
  end

  defp close_numscript(script, remaining_dest) do
    script <>
      """
          remaining to @#{remaining_dest}
        }
      )
      """
  end

  defp close_portioned_dest(script, nil) do
    script <>
      """
            remaining kept
          }
      """
  end

  defp close_portioned_dest(script, remaining_dest) do
    script <>
      """
            remaining to @#{remaining_dest}
          }
      """
  end
end
