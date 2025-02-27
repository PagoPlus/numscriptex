defmodule Numscriptex.Balance do
  @moduledoc """
  `Numscriptex.Balances` is responsible for building the account's final balance
  after running your [Numscript](https://docs.formance.com/numscript/), so you
  can see the results of all transactions.
  """

  alias Numscriptex.Utilities

  @derive JSON.Encoder
  defstruct account: nil,
            asset: nil,
            final_balance: nil,
            decimal_final_balance: nil,
            initial_balance: nil,
            decimal_initial_balance: nil

  @typedoc """
  Type that represents `Numscriptex.Balance` struct.

  ## Fields
  * `:account` the account name
  * `:asset` the asset were the transaction was made
  * `:final_balance` balance after the transactions (integer)
  * `:decimal_final_balance` balance after the transactions, but as float
  * `:initial_balance` balance before the transactions (integer)
  * `:decimal_initial_balance` balance after the transactions, but as float
  """
  @type t() :: %__MODULE__{
          account: bitstring(),
          asset: bitstring(),
          final_balance: integer(),
          decimal_final_balance: float(),
          initial_balance: integer(),
          decimal_initial_balance: float()
        }

  @doc """
  Receives the account assets (balance field from `%Numscriptex.Run{}`), and the
  postings that are generated after running the numscript transaction.

  The result will be a map contaning the initial and final balances of each
  account assets. Ex:

  ```elixir
  iex> account_assets = %{
  ...>     "foo" => %{
  ...>     "USD/2" => 500,
  ...>     "EUR/2" => 300
  ...>   }
  ...> }
  ...>
  ...> postings = [
  ...>   %{
  ...>     "amount" => 100,
  ...>     "asset" => "USD/2",
  ...>     "destination" => "bar",
  ...>     "source" => "foo"
  ...>   }
  ...> ]
  ...>
  ...> Numscriptex.Balance.put(account_assets, postings)
  [
    %Numscriptex.Balance{
      account: "foo",
      asset: "EUR/2",
      final_balance: 300,
      decimal_final_balance: 3.0,
      initial_balance: 300,
      decimal_initial_balance: 3.0
    },
    %Numscriptex.Balance{
      account: "foo",
      asset: "USD/2",
      final_balance: 400,
      decimal_final_balance: 4.0,
      initial_balance: 500,
      decimal_initial_balance: 5.0
    },
    %Numscriptex.Balance{
      account: "bar",
      asset: "USD/2",
      final_balance: 100,
      decimal_final_balance: 1.0,
      initial_balance: 0,
      decimal_initial_balance: 0.0
    }
  ]
  ```
  """
  @spec put(map(), list()) :: list(map())
  def put(account_assets, postings) do
    account_assets
    |> build_balances(postings)
    |> Enum.uniq()
    |> handle_initial_balance(account_assets)
    |> handle_final_balance(postings)
    |> maybe_drop_balance()
    |> put_decimal_values()
    |> Enum.map(&struct(__MODULE__, &1))
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
          account: account,
          asset: asset,
          final_balance: 0,
          decimal_final_balance: 0,
          initial_balance: 0,
          decimal_initial_balance: 0
        }
      end)
    end)
  end

  defp build_balances_by_postings(postings) do
    Enum.flat_map(postings, fn posting ->
      [
        %{
          account: posting["source"],
          asset: posting["asset"],
          final_balance: 0,
          decimal_final_balance: 0,
          initial_balance: 0,
          decimal_initial_balance: 0
        },
        %{
          account: posting["destination"],
          asset: posting["asset"],
          final_balance: 0,
          decimal_final_balance: 0,
          initial_balance: 0,
          decimal_initial_balance: 0
        }
      ]
    end)
  end

  defp handle_initial_balance(balances, account_assets) do
    Enum.map(balances, fn balance ->
      account = balance.account
      asset = balance.asset

      initial_balance = account_assets[account][asset] || 0

      %{balance | initial_balance: initial_balance}
    end)
  end

  defp handle_final_balance(balances, postings) do
    Enum.map(balances, fn balance ->
      initial_balance = balance.initial_balance

      Enum.reduce(postings, {%{}, initial_balance}, fn posting, {_map, acc} ->
        final_balance = calculate_final_balance(balance, posting, acc)

        {balance, final_balance}
      end)
    end)
    |> Enum.map(fn {balance, final_balance} ->
      %{balance | final_balance: final_balance}
    end)
  end

  defp calculate_final_balance(balance, posting, initial_balance) do
    same_asset? = posting["asset"] == balance.asset
    source? = posting["source"] == balance.account
    destination? = posting["destination"] == balance.account

    cond do
      source? and destination? and same_asset? ->
        initial_balance

      source? and same_asset? ->
        initial_balance - posting["amount"]

      destination? and same_asset? ->
        initial_balance + posting["amount"]

      true ->
        initial_balance
    end
  end

  defp maybe_drop_balance(balances) do
    Enum.reject(balances, fn balance ->
      balance.initial_balance == 0 and balance.final_balance == 0
    end)
  end

  defp put_decimal_values(balances) do
    Enum.map(balances, fn
      %{initial_balance: initial_balance, final_balance: final_balance} = balance ->
        decimal_places = Utilities.decimal_places_from_asset(balance.asset)
        decimal_initial_balance = Utilities.integer_to_decimal(initial_balance, decimal_places)
        decimal_final_balance = Utilities.integer_to_decimal(final_balance, decimal_places)

        %{
          balance
          | decimal_initial_balance: decimal_initial_balance,
            decimal_final_balance: decimal_final_balance
        }
    end)
  end
end
