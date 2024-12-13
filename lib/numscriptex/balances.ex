defmodule Numscriptex.Balances do
  @spec put(map(), list()) :: list(map())
  def put(account_assets, postings) do
    account_assets
    |> build_balances(postings)
    |> Enum.uniq()
    |> handle_initial_balance(account_assets)
    |> handle_final_balance(postings)
  end

  defp build_balances(account_assets, postings) do
    balances_by_assets = build_balances_by_assets(account_assets)
    balances_by_postings = build_balances_by_postings(postings)

    balances_by_assets ++ balances_by_postings
  end

  defp build_balances_by_assets(account_assets) do
    Enum.flat_map(account_assets, fn {account, assets} ->
      Enum.map(assets, fn {asset, _amount} ->
        %{
          "account" => account,
          "asset" => asset,
          "initial_balance" => 0,
          "final_balance" => 0
        }
      end)
    end)
  end

  defp build_balances_by_postings(postings) do
    Enum.map(postings, fn posting ->
        %{
          "account" => posting["destination"],
          "asset" => posting["asset"],
          "initial_balance" => 0,
          "final_balance" => 0
        }
    end)
  end

  defp handle_initial_balance(balances, account_assets) do
    Enum.map(balances, fn balance -> 
      account = balance["account"]
      asset = balance["asset"]

      initial_balance = account_assets[account][asset] || 0

      %{balance | "initial_balance" => initial_balance}
    end)
  end

  defp handle_final_balance(balances, postings) do
    Enum.map(balances, fn balance ->
      initial_balance = balance["initial_balance"]

      Enum.reduce(postings, {%{}, initial_balance}, fn posting, {_map, acc} ->
        {
          balance,
          calculate_final_balance(balance, posting, acc)
        }
      end)
    end)
    |> Enum.map(fn {balance, final_balance} ->
      %{balance | "final_balance" => final_balance}
    end)
  end

  defp calculate_final_balance(balance, posting, initial_balance) do
    same_asset? = posting["asset"] == balance["asset"]
    source? = posting["source"] === balance["account"]
    destination? = posting["destination"] === balance["account"]

    cond do
      source? and same_asset? ->
        initial_balance - posting["amount"]

      destination? and same_asset? ->
        initial_balance + posting["amount"]

      true ->
        initial_balance
    end
  end
end
