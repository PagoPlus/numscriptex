defmodule Numscriptex.RunTest do
  use ExUnit.Case

  alias Numscriptex.Run

  describe "new/0" do
    test "creates a new struct" do
      assert Run.new() == %Run{
               balances: %{},
               metadata: %{},
               variables: %{}
             }
    end
  end

  describe "put/3" do
    test "put balances field with valid params" do
      balances = %{
        "bar" => %{"USD/2" => 0},
        "baz" => %{"USD/2" => 0, "EUR/2" => 0},
        "foo" => %{"USD/2" => 100}
      }

      target = %Run{
        variables: %{},
        balances: balances,
        metadata: %{}
      }

      assert {:ok, result} = Run.put(%Run{}, :balances, balances)
      assert result == target
    end

    test "when balances' map keys are atoms, convert to string" do
      balances = %{
        bar: %{:"USD/2" => 0},
        baz: %{:"USD/2" => 0, :"EUR/2" => 0},
        foo: %{:"USD/2" => 100}
      }

      target = %Run{
        variables: %{},
        balances: %{
          "bar" => %{"USD/2" => 0},
          "baz" => %{"USD/2" => 0, "EUR/2" => 0},
          "foo" => %{"USD/2" => 100}
        },
        metadata: %{}
      }

      assert {:ok, result} = Run.put(%Run{}, :balances, balances)
      assert result == target
    end

    test "fails to put balances field with invalid params" do
      balances = [
        %{
          "bar" => %{"USD/2" => 0},
          "baz" => %{"USD/2" => 0, "EUR/2" => 0},
          "foo" => %{"USD/2" => 100}
        }
      ]

      assert {:error, :invalid_value, error} = Run.put(%Run{}, :balances, balances)
      assert error.details == "Values argument must be a map."
    end

    test "put metadata field with valid params" do
      metadata = %{
        "merchants:1234" => %{"commission" => "15%"},
        "orders:2345" => %{"merchant" => "merchants:1234"}
      }

      target = %Run{
        variables: %{},
        balances: %{},
        metadata: metadata
      }

      assert {:ok, result} = Run.put(%Run{}, :metadata, metadata)
      assert result == target
    end

    test "fails to put metadata field with invalid params" do
      metadata = [
        %{
          "merchants:1234" => %{"commission" => "15%"},
          "orders:2345" => %{"merchant" => "merchants:1234"}
        }
      ]

      assert {:error, :invalid_value, error} = Run.put(%Run{}, :metadata, metadata)
      assert error.details == "Values argument must be a map."
    end

    test "put variables field with valid params" do
      variables = %{
        "fee" => "USD/2 100",
        "tax" => "20%",
        "user" => "users:1234"
      }

      target = %Run{
        variables: variables,
        balances: %{},
        metadata: %{}
      }

      assert {:ok, result} = Run.put(%Run{}, :variables, variables)
      assert result == target
    end

    test "fails to put variables field with invalid params" do
      variables = [
        %{
          "fee" => "USD/2 100",
          "tax" => "20%",
          "user" => "users:1234"
        }
      ]

      assert {:error, :invalid_value, error} = Run.put(%Run{}, :variables, variables)
      assert error.details == "Values argument must be a map."
    end

    test "fails to put an invalid field" do
      assert {:error, :invalid_field, error} = Run.put(%Run{}, :invalid, %{})
      assert error.details == "The field 'invalid' does not exists."
    end
  end

  describe "put!/3" do
    test "put valid field with valid params" do
      balances = %{
        "bar" => %{"USD/2" => 0},
        "baz" => %{"USD/2" => 0, "EUR/2" => 0},
        "foo" => %{"USD/2" => 100}
      }

      target = %Run{
        variables: %{},
        balances: balances,
        metadata: %{}
      }

      assert result = Run.put!(%Run{}, :balances, balances)
      assert result == target
    end

    test "raise an error with invalid field" do
      error_message = "The field 'invalid' does not exists."

      assert_raise ArgumentError, error_message, fn -> Run.put!(%Run{}, :invalid, %{}) end
    end

    test "raise an error with invalid value" do
      error_message = "Values argument must be a map."

      assert_raise ArgumentError, error_message, fn -> Run.put!(%Run{}, :metadata, "") end
    end
  end
end
