defmodule Numscriptex.Balances do
  @spec put(map(), list()) :: list(map())
  def put(initial_balance, postings) do
    initial_balance
    |> Enum.map(fn {account, assets} ->
      Enum.map(assets, fn {asset, amount} ->
        %{
          "account" => account,
          "asset" => asset,
          "initial_balance" => amount,
          "final_balance" => amount
        }
      end)
    end)
    |> List.flatten()
    |> Enum.map(fn balance_data ->
      Enum.reduce(postings, {%{}, 0}, fn posting, {_map, acc} ->
        {
          balance_data,
          handle_final_balance(balance_data, posting, acc)
        }
      end)
    end)
    |> Enum.map(fn {balance, final_balance} ->
      %{balance | "final_balance" => final_balance}
    end)
  end

  defp handle_final_balance(balance_data, posting, acc) do
    same_asset? = balance_data["asset"] == posting["asset"]
    source? = posting["source"] === balance_data["account"]
    destination? = posting["destination"] === balance_data["account"]

    balance = balance_data["final_balance"]

    cond do
      source? and same_asset? ->
        balance - posting["amount"] - acc

      destination? and same_asset? ->
        balance + posting["amount"]

      true ->
        acc
    end
  end
end
