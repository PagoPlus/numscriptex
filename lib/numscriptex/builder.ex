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

      with {:ok, port_numscript} <-
             maybe_build_portioned_numscript(port_splits, remaining_dest, asset),
           {:ok, fixed_numscript} <- maybe_build_fixed_values_numscript(fixed_splits) do
        {:ok, %{script: port_numscript <> fixed_numscript}}
      end
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

  defp maybe_build_portioned_numscript([], _remaining_dest, _asset), do: {:ok, ""}

  defp maybe_build_portioned_numscript(metadata, remaining_dest, asset) do
    with {:ok, initial} <- start_numscript(asset) do
      metadata
      |> Enum.reduce_while(initial, fn data, acc -> handle_build(data, acc) end)
      |> close_numscript(remaining_dest)
    end
  end

  defp maybe_build_fixed_values_numscript([]), do: {:ok, ""}

  defp maybe_build_fixed_values_numscript(metadata) do
    metadata
    |> Enum.reduce_while("", fn data, acc -> handle_build(data, acc) end)
    |> case do
      {:error, _reason} = error ->
        error

      script ->
        {:ok, script}
    end
  end

  defp build_numscript(%{type: :percent, splits: splits} = metadata) when is_list(splits) do
    initial = start_portioned_dest(metadata[:amount])

    splits
    |> Enum.reduce_while(initial, fn
      %{type: :percent} = split, acc ->
        handle_build(split, acc)

      _split, acc ->
        {:cont, acc}
    end)
    |> close_portioned_dest(metadata[:remaining_to])
  end

  defp build_numscript(%{amount: amount, account: dest, type: type, asset: asset})
       when type == :fixed and
              is_integer(amount) and
              amount > 0 and
              is_binary(dest) and
              is_binary(asset) do
    case {String.trim(asset), String.trim(dest)} do
      {_, ""} ->
        {:error, "Invalid destination."}

      {"", _} ->
        {:error, "Invalid asset."}

      {asset, dest} ->
        """
        send [#{asset} #{amount}] (
          source = @user
          destination = @#{dest}
        )
        """
    end
  end

  defp build_numscript(%{amount: amount, account: dest, type: type})
       when type == :percent and
              is_integer(amount) and
              amount > 0 and
              amount <= 100 and
              is_binary(dest) do
    case String.trim(dest) do
      "" ->
        {:error, "Invalid destination."}

      dest ->
        """
            #{amount}% to @#{dest}
        """
    end
  end

  defp build_numscript(_metadata), do: {:error, "Invalid metadata."}

  defp handle_build(split, acc) do
    case build_numscript(split) do
      {:error, _reason} = error ->
        {:halt, error}

      script ->
        {:cont, acc <> script}
    end
  end

  defp start_numscript(asset) when is_binary(asset) do
    case String.trim(asset) do
      "" ->
        {:error, "Invalid asset."}

      asset ->
        {:ok,
         """
         send [#{asset} *] (
           source = @user
           destination = {
         """}
    end
  end

  defp start_numscript(_asset), do: {:error, "Invalid asset."}

  defp start_portioned_dest(amount) when is_integer(amount) and amount > 0 and amount <= 100 do
    """
        #{amount}% to {
    """
  end

  defp start_portioned_dest(_amount), do: {:error, "Invalid amount."}

  defp close_numscript({:error, _reason} = error, _remaining_dest), do: error

  defp close_numscript(script, nil) do
    script =
      script <>
        """
            remaining kept
          }
        )
        """

    {:ok, script}
  end

  defp close_numscript(script, remaining_dest) when is_binary(remaining_dest) do
    case String.trim(remaining_dest) do
      "" ->
        {:error, "Invalid remaining destination."}

      remaining_dest ->
        script =
          script <>
            """
                remaining to @#{remaining_dest}
              }
            )
            """

        {:ok, script}
    end
  end

  defp close_numscript(_script, _remaining_dest), do: {:error, "Invalid remaining destination."}

  defp close_portioned_dest({:error, _reason} = error, _remaining_dest), do: error

  defp close_portioned_dest(script, nil) do
    script <>
      """
            remaining kept
          }
      """
  end

  defp close_portioned_dest(script, remaining_dest) when is_binary(remaining_dest) do
    case String.trim(remaining_dest) do
      "" ->
        {:error, "Invalid remaining destination."}

      remaining_dest ->
        script <>
          """
                remaining to @#{remaining_dest}
              }
          """
    end
  end

  defp close_portioned_dest(_script, _remaining_dest),
    do: {:error, "Invalid remaining destination."}
end
