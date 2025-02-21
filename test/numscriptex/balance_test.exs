defmodule Numscriptex.BalanceTest do
  use ExUnit.Case

  alias Numscriptex.Balance

  doctest Balance

  setup_all do
    postings =
      [
        %{
          "amount" => 50,
          "asset" => "USD/2",
          "destination" => "bar",
          "source" => "foo"
        },
        %{
          "amount" => 49,
          "asset" => "USD/2",
          "destination" => "baz",
          "source" => "foo"
        }
      ]

    {:ok, %{postings: postings}}
  end

  describe "put/2" do
    test "build balances based of postings", %{postings: postings} do
      initial_balances = %{
        "bar" => %{"USD/2" => 0},
        "baz" => %{"USD/2" => 0},
        "foo" => %{"USD/2" => 100}
      }

      target = [
        %Numscriptex.Balance{
          account: "bar",
          asset: "USD/2",
          final_balance: 50,
          initial_balance: 0
        },
        %Numscriptex.Balance{
          account: "baz",
          asset: "USD/2",
          final_balance: 49,
          initial_balance: 0
        },
        %Numscriptex.Balance{
          account: "foo",
          asset: "USD/2",
          final_balance: 1,
          initial_balance: 100
        }
      ]

      assert balances = Balance.put(initial_balances, postings)
      assert balances == target
    end

    test "built balances does not affect unused assets", %{postings: postings} do
      initial_balances = %{
        "bar" => %{"USD/2" => 0, "BRL/2" => 10},
        "baz" => %{"USD/2" => 0, "EUR/2" => 50},
        "foo" => %{"USD/2" => 100}
      }

      assert any_asset_on_postings?("USD/2", postings)
      refute any_asset_on_postings?("BRL/2", postings)
      refute any_asset_on_postings?("EUR/2", postings)

      assert balances = Balance.put(initial_balances, postings)
      assert asset_untouched?("EUR/2", balances)
      assert asset_untouched?("BRL/2", balances)
      refute asset_untouched?("USD/2", balances)
    end
  end

  defp any_asset_on_postings?(asset, postings) do
    Enum.any?(postings, fn posting ->
      posting["asset"] == asset
    end)
  end

  defp asset_untouched?(asset, balances) do
    target = Enum.find(balances, false, fn balance -> balance.asset == asset end)

    if target, do: target.final_balance == target.initial_balance
  end
end
