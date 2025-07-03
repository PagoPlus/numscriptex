defmodule NumscriptexTest do
  use ExUnit.Case, async: false

  alias Numscriptex.AssetsManager
  alias Numscriptex.CheckLog

  doctest Numscriptex

  describe "check/1" do
    setup do
      script = """
      vars {
        account $order
        account $merchant = meta($order, "merchant")
        portion $commission = meta($merchant, "commission")
      }

      send [USD/2 *] (
        source = $order
        destination = {
          $commission to @platform:fees
          remaining to $merchant
        }
      )
      """

      warning_script = """
      vars {
        account $unused
        account $order
        account $merchant = meta($order, "merchant")
        portion $commission = meta($merchant, "commission")
      }

      send [USD/2 *] (
        source = $order
        destination = {
          $commission to @platform:fees
          remaining to $merchant
        }
      )
      """

      {:ok, %{script: script, warning_script: warning_script}}
    end

    test "with valid script", %{script: script} do
      case Numscriptex.version() do
        %{numscript_wasm: "v0.2.0", numscriptex: _} ->
          assert {:ok, result} = Numscriptex.check(script)
          assert result.script == script

        _ ->
          assert {:error, %{reason: :unsupported_version}} = Numscriptex.check(script)
      end
    end

    test "with valid script, but unused var", %{warning_script: warning_script} do
      case Numscriptex.version() do
        %{numscript_wasm: "v0.2.0"} ->
          assert {:ok, result} = Numscriptex.check(warning_script)
          assert result.script == warning_script

          assert result.details == %{
                   warnings: [
                     %CheckLog{
                       character: 10,
                       level: :warning,
                       line: 1,
                       message: "The variable '$unused' is never used"
                     }
                   ]
                 }

          has_errors? = Map.has_key?(result.details, :errors)

          refute has_errors?
        _ ->
          assert {:error, %{reason: :unsupported_version}} = Numscriptex.check(warning_script)
      end

    end

    test "with invalid script", %{script: script} do
      error_script = String.replace(script, "a", "e")

      case Numscriptex.version() do
        %{numscript_wasm: "v0.2.0"} ->
          assert {:error, %{reason: reason}} = Numscriptex.check(error_script)
          assert [error | _errors] = reason.errors

          assert error == %CheckLog{
                  character: 0,
                  level: :error,
                  line: 0,
                  message: "The function 'vers' does not exist"
                }

        _ ->
          assert {:error, %{reason: :unsupported_version}} = Numscriptex.check(error_script)
      end
    end
  end

  describe "run/2" do
    test "simple send" do
      script = """
      send [USD/2 100] (
        source = @foo
        destination = @bar
      )
      """

      balances = %{"foo" => %{"USD/2" => 500, "EUR/2" => 300}}
      metadata = %{}
      variables = %{}

      struct = build_run_struct(balances, metadata, variables)

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 amount: 100,
                 decimal_amount: 1.0,
                 asset: "USD/2",
                 destination: "bar",
                 source: "foo"
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "foo",
                 asset: "EUR/2",
                 final_balance: 300,
                 initial_balance: 300,
                 decimal_final_balance: 3.0,
                 decimal_initial_balance: 3.0
               },
               %Numscriptex.Balance{
                 account: "foo",
                 asset: "USD/2",
                 final_balance: 400,
                 initial_balance: 500,
                 decimal_final_balance: 4.0,
                 decimal_initial_balance: 5.0
               },
               %Numscriptex.Balance{
                 account: "bar",
                 asset: "USD/2",
                 final_balance: 100,
                 initial_balance: 0,
                 decimal_final_balance: 1.0,
                 decimal_initial_balance: 0.0
               }
             ]
    end

    test "multiple send" do
      script = """
      send [USD/2 100] (
        source = @foo
        destination = @bar
      )

      send [USD/2 100] (
        source = @bar
        destination = @baz
      )
      """

      balances = %{"foo" => %{"USD/2" => 500}}
      metadata = %{}
      variables = %{}

      struct = build_run_struct(balances, metadata, variables)

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 amount: 100,
                 decimal_amount: 1.0,
                 asset: "USD/2",
                 destination: "bar",
                 source: "foo"
               },
               %Numscriptex.Posting{
                 amount: 100,
                 decimal_amount: 1.0,
                 asset: "USD/2",
                 destination: "baz",
                 source: "bar"
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "foo",
                 asset: "USD/2",
                 final_balance: 400,
                 initial_balance: 500,
                 decimal_final_balance: 4.0,
                 decimal_initial_balance: 5.0
               },
               %Numscriptex.Balance{
                 account: "baz",
                 asset: "USD/2",
                 final_balance: 100,
                 initial_balance: 0,
                 decimal_final_balance: 1.0,
                 decimal_initial_balance: 0.0
               }
             ]
    end

    test "cascading sources" do
      script = """
      send [USD/2 10000] (
        source = {
          @users:1234:main
          @users:1234:vouchers:2024-01-31
          @users:1234:vouchers:2024-02-17
          @users:1234:vouchers:2024-03-22
        }
        destination = @orders:4567:payment
      )
      """

      metadata = %{}
      variables = %{}

      balances = %{
        "users:1234:main" => %{"USD/2" => 5000},
        "users:1234:vouchers:2024-01-31" => %{"USD/2" => 1000},
        "users:1234:vouchers:2024-02-17" => %{"USD/2" => 3000},
        "users:1234:vouchers:2024-03-22" => %{"USD/2" => 10_000}
      }

      struct = build_run_struct(balances, metadata, variables)

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 amount: 5000,
                 decimal_amount: 50.0,
                 asset: "USD/2",
                 destination: "orders:4567:payment",
                 source: "users:1234:main"
               },
               %Numscriptex.Posting{
                 amount: 1000,
                 decimal_amount: 10.0,
                 asset: "USD/2",
                 destination: "orders:4567:payment",
                 source: "users:1234:vouchers:2024-01-31"
               },
               %Numscriptex.Posting{
                 amount: 3000,
                 decimal_amount: 30.0,
                 asset: "USD/2",
                 destination: "orders:4567:payment",
                 source: "users:1234:vouchers:2024-02-17"
               },
               %Numscriptex.Posting{
                 amount: 1000,
                 decimal_amount: 10.0,
                 asset: "USD/2",
                 destination: "orders:4567:payment",
                 source: "users:1234:vouchers:2024-03-22"
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "users:1234:main",
                 asset: "USD/2",
                 final_balance: 0,
                 initial_balance: 5000,
                 decimal_final_balance: 0.0,
                 decimal_initial_balance: 50.0
               },
               %Numscriptex.Balance{
                 account: "users:1234:vouchers:2024-01-31",
                 asset: "USD/2",
                 final_balance: 0,
                 initial_balance: 1000,
                 decimal_final_balance: 0.0,
                 decimal_initial_balance: 10.0
               },
               %Numscriptex.Balance{
                 account: "users:1234:vouchers:2024-02-17",
                 asset: "USD/2",
                 final_balance: 0,
                 initial_balance: 3000,
                 decimal_final_balance: 0.0,
                 decimal_initial_balance: 30.0
               },
               %Numscriptex.Balance{
                 account: "users:1234:vouchers:2024-03-22",
                 asset: "USD/2",
                 final_balance: 9000,
                 initial_balance: 10_000,
                 decimal_final_balance: 90.0,
                 decimal_initial_balance: 100.0
               },
               %Numscriptex.Balance{
                 account: "orders:4567:payment",
                 asset: "USD/2",
                 final_balance: 10_000,
                 initial_balance: 0,
                 decimal_final_balance: 100.0,
                 decimal_initial_balance: 0.0
               }
             ]
    end

    test "complex sources" do
      script = """
      send [USD/2 29900] (
        source = {
          10% from {
            max [USD/2 2000] from @coupons:FALL24
            @users:1234
          }
          remaining from @users:1234
        }
        destination = @payments:4567
      )
      send [USD/2 9000] (
        source = {
          10% from {
            max [USD/2 2000] from @coupons:FALL24
            @users:1234
          }
          remaining from @users:1234
        }
        destination = @payments:5678
      )
      """

      metadata = %{}
      variables = %{}

      balances = %{
        "coupons:FALL24" => %{"USD/2" => 99_900},
        "users:1234" => %{"USD/2" => 100_000}
      }

      struct = build_run_struct(balances, metadata, variables)

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 amount: 2000,
                 decimal_amount: 20.0,
                 asset: "USD/2",
                 destination: "payments:4567",
                 source: "coupons:FALL24"
               },
               %Numscriptex.Posting{
                 amount: 27_900,
                 decimal_amount: 279.0,
                 asset: "USD/2",
                 destination: "payments:4567",
                 source: "users:1234"
               },
               %Numscriptex.Posting{
                 amount: 900,
                 decimal_amount: 9.0,
                 asset: "USD/2",
                 destination: "payments:5678",
                 source: "coupons:FALL24"
               },
               %Numscriptex.Posting{
                 amount: 8100,
                 decimal_amount: 81.0,
                 asset: "USD/2",
                 destination: "payments:5678",
                 source: "users:1234"
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "coupons:FALL24",
                 asset: "USD/2",
                 final_balance: 97_000,
                 initial_balance: 99_900,
                 decimal_final_balance: 970.0,
                 decimal_initial_balance: 999.0
               },
               %Numscriptex.Balance{
                 account: "users:1234",
                 asset: "USD/2",
                 final_balance: 64_000,
                 initial_balance: 100_000,
                 decimal_final_balance: 640.0,
                 decimal_initial_balance: 1000.0
               },
               %Numscriptex.Balance{
                 account: "payments:4567",
                 asset: "USD/2",
                 final_balance: 29_900,
                 initial_balance: 0,
                 decimal_final_balance: 299.0,
                 decimal_initial_balance: 0.0
               },
               %Numscriptex.Balance{
                 account: "payments:5678",
                 asset: "USD/2",
                 final_balance: 9000,
                 initial_balance: 0,
                 decimal_final_balance: 90.0,
                 decimal_initial_balance: 0.0
               }
             ]
    end

    test "split destinations" do
      script = """
      send [USD/2 100] (
        source = @orders:1234
        destination = {
          10% to @platform:fees
          remaining to @merchants:6789
        }
      )
      """

      metadata = %{}
      variables = %{}
      balances = %{"orders:1234" => %{"USD/2" => 1000}}

      struct = build_run_struct(balances, metadata, variables)

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 amount: 10,
                 decimal_amount: 0.1,
                 asset: "USD/2",
                 destination: "platform:fees",
                 source: "orders:1234"
               },
               %Numscriptex.Posting{
                 amount: 90,
                 decimal_amount: 0.9,
                 asset: "USD/2",
                 destination: "merchants:6789",
                 source: "orders:1234"
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "orders:1234",
                 asset: "USD/2",
                 final_balance: 900,
                 initial_balance: 1000,
                 decimal_final_balance: 9.0,
                 decimal_initial_balance: 10.0
               },
               %Numscriptex.Balance{
                 account: "platform:fees",
                 asset: "USD/2",
                 final_balance: 10,
                 initial_balance: 0,
                 decimal_final_balance: 0.1,
                 decimal_initial_balance: 0.0
               },
               %Numscriptex.Balance{
                 account: "merchants:6789",
                 asset: "USD/2",
                 final_balance: 90,
                 initial_balance: 0,
                 decimal_final_balance: 0.9,
                 decimal_initial_balance: 0.0
               }
             ]
    end

    test "complex destinations" do
      script = """
      send [USD/2 10000] (
        source = @orders:1234
        destination = {
          15% to {
            20% to @platform:commission:sales_tax
            remaining to @platform:commission:revenue
          }
          10% to {
            max [USD/2 500] to @users:1234:cashback
            remaining to @merchants:6789
          }
          remaining to @merchants:6789
        }
      )
      """

      metadata = %{}
      variables = %{}
      balances = %{"orders:1234" => %{"USD/2" => 10_000}}

      struct = build_run_struct(balances, metadata, variables)

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 amount: 300,
                 decimal_amount: 3.0,
                 asset: "USD/2",
                 destination: "platform:commission:sales_tax",
                 source: "orders:1234"
               },
               %Numscriptex.Posting{
                 amount: 1200,
                 decimal_amount: 12.0,
                 asset: "USD/2",
                 destination: "platform:commission:revenue",
                 source: "orders:1234"
               },
               %Numscriptex.Posting{
                 amount: 500,
                 decimal_amount: 5.0,
                 asset: "USD/2",
                 destination: "users:1234:cashback",
                 source: "orders:1234"
               },
               %Numscriptex.Posting{
                 amount: 500,
                 decimal_amount: 5.0,
                 asset: "USD/2",
                 destination: "merchants:6789",
                 source: "orders:1234"
               },
               %Numscriptex.Posting{
                 amount: 7500,
                 decimal_amount: 75.0,
                 asset: "USD/2",
                 destination: "merchants:6789",
                 source: "orders:1234"
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "orders:1234",
                 asset: "USD/2",
                 final_balance: 0,
                 initial_balance: 10_000,
                 decimal_final_balance: 0.0,
                 decimal_initial_balance: 100.0
               },
               %Numscriptex.Balance{
                 account: "platform:commission:sales_tax",
                 asset: "USD/2",
                 final_balance: 300,
                 initial_balance: 0,
                 decimal_final_balance: 3.0,
                 decimal_initial_balance: 0.0
               },
               %Numscriptex.Balance{
                 account: "platform:commission:revenue",
                 asset: "USD/2",
                 final_balance: 1200,
                 initial_balance: 0,
                 decimal_final_balance: 12.0,
                 decimal_initial_balance: 0.0
               },
               %Numscriptex.Balance{
                 account: "users:1234:cashback",
                 asset: "USD/2",
                 final_balance: 500,
                 initial_balance: 0,
                 decimal_final_balance: 5.0,
                 decimal_initial_balance: 0.0
               },
               %Numscriptex.Balance{
                 account: "merchants:6789",
                 asset: "USD/2",
                 final_balance: 8000,
                 initial_balance: 0,
                 decimal_final_balance: 80.0,
                 decimal_initial_balance: 0.0
               }
             ]
    end

    test "send entire balance" do
      script = """
      send [USD/2 *] (
        source = @users:1234
        destination = @payment
      )
      """

      metadata = %{}
      variables = %{}
      balances = %{"users:1234" => %{"USD/2" => 500}}

      struct = build_run_struct(balances, metadata, variables)

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 amount: 500,
                 decimal_amount: 5.0,
                 asset: "USD/2",
                 destination: "payment",
                 source: "users:1234"
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "users:1234",
                 asset: "USD/2",
                 final_balance: 0,
                 initial_balance: 500,
                 decimal_final_balance: 0.0,
                 decimal_initial_balance: 5.0
               },
               %Numscriptex.Balance{
                 account: "payment",
                 asset: "USD/2",
                 final_balance: 500,
                 initial_balance: 0,
                 decimal_final_balance: 5.0,
                 decimal_initial_balance: 0.0
               }
             ]
    end

    test "overdrafts" do
      script = """
      send [USD/2 100] (
        source = @users:1234 allowing unbounded overdraft
        destination = @payments:4567
      )

      send [USD/2 6000] (
        source = {
          @users:2345:credit allowing overdraft up to [USD/2 1000]
          @users:2345:main
        }
        destination = @payments:4567
      )
      """

      metadata = %{}
      variables = %{}
      balances = %{"users:2345:main" => %{"USD/2" => 5000}}

      struct = build_run_struct(balances, metadata, variables)

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 amount: 100,
                 decimal_amount: 1.0,
                 asset: "USD/2",
                 destination: "payments:4567",
                 source: "users:1234"
               },
               %Numscriptex.Posting{
                 amount: 1000,
                 decimal_amount: 10.0,
                 asset: "USD/2",
                 destination: "payments:4567",
                 source: "users:2345:credit"
               },
               %Numscriptex.Posting{
                 amount: 5000,
                 decimal_amount: 50.0,
                 asset: "USD/2",
                 destination: "payments:4567",
                 source: "users:2345:main"
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "users:2345:main",
                 asset: "USD/2",
                 final_balance: 0,
                 initial_balance: 5000,
                 decimal_final_balance: 0.0,
                 decimal_initial_balance: 50.0
               },
               %Numscriptex.Balance{
                 account: "users:1234",
                 asset: "USD/2",
                 final_balance: -100,
                 initial_balance: 0,
                 decimal_final_balance: -1.0,
                 decimal_initial_balance: 0.0
               },
               %Numscriptex.Balance{
                 account: "payments:4567",
                 asset: "USD/2",
                 final_balance: 6100,
                 initial_balance: 0,
                 decimal_final_balance: 61.0,
                 decimal_initial_balance: 0.0
               },
               %Numscriptex.Balance{
                 account: "users:2345:credit",
                 asset: "USD/2",
                 final_balance: -1000,
                 initial_balance: 0,
                 decimal_final_balance: -10.0,
                 decimal_initial_balance: 0.0
               }
             ]
    end

    test "partial tranfers" do
      script = """
      send [USD/2 *] (
        source = @users:1234
        destination = {
          1% to @platform:fees
          remaining kept
        }
      )
      """

      metadata = %{}
      variables = %{}
      balances = %{"users:1234" => %{"USD/2" => 500}}

      struct = build_run_struct(balances, metadata, variables)

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 amount: 5,
                 decimal_amount: 0.05,
                 asset: "USD/2",
                 destination: "platform:fees",
                 source: "users:1234"
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "users:1234",
                 asset: "USD/2",
                 final_balance: 495,
                 initial_balance: 500,
                 decimal_final_balance: 4.95,
                 decimal_initial_balance: 5.0
               },
               %Numscriptex.Balance{
                 account: "platform:fees",
                 asset: "USD/2",
                 final_balance: 5,
                 initial_balance: 0,
                 decimal_final_balance: 0.05,
                 decimal_initial_balance: 0.0
               }
             ]
    end

    test "rounding tranfers" do
      script = """
      send [USD/2 99] (
        source = @foo
        destination = {
          50% to @bar
          remaining to @baz
        }
      )

      send [USD/2 99] (
        source = @a
        destination = {
          20% to @b
          20% to @c
          remaining to @d
        }
      )
      """

      metadata = %{}
      variables = %{}
      balances = %{"foo" => %{"USD/2" => 1000}, "a" => %{"USD/2" => 1000}}

      struct = build_run_struct(balances, metadata, variables)

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 amount: 50,
                 decimal_amount: 0.5,
                 asset: "USD/2",
                 destination: "bar",
                 source: "foo"
               },
               %Numscriptex.Posting{
                 amount: 49,
                 decimal_amount: 0.49,
                 asset: "USD/2",
                 destination: "baz",
                 source: "foo"
               },
               %Numscriptex.Posting{
                 amount: 20,
                 decimal_amount: 0.2,
                 asset: "USD/2",
                 destination: "b",
                 source: "a"
               },
               %Numscriptex.Posting{
                 amount: 20,
                 decimal_amount: 0.2,
                 asset: "USD/2",
                 destination: "c",
                 source: "a"
               },
               %Numscriptex.Posting{
                 amount: 59,
                 decimal_amount: 0.59,
                 asset: "USD/2",
                 destination: "d",
                 source: "a"
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "a",
                 asset: "USD/2",
                 final_balance: 901,
                 initial_balance: 1000,
                 decimal_final_balance: 9.01,
                 decimal_initial_balance: 10.0
               },
               %Numscriptex.Balance{
                 account: "foo",
                 asset: "USD/2",
                 final_balance: 901,
                 initial_balance: 1000,
                 decimal_final_balance: 9.01,
                 decimal_initial_balance: 10.0
               },
               %Numscriptex.Balance{
                 account: "bar",
                 asset: "USD/2",
                 final_balance: 50,
                 initial_balance: 0,
                 decimal_final_balance: 0.5,
                 decimal_initial_balance: 0.0
               },
               %Numscriptex.Balance{
                 account: "baz",
                 asset: "USD/2",
                 final_balance: 49,
                 initial_balance: 0,
                 decimal_final_balance: 0.49,
                 decimal_initial_balance: 0.0
               },
               %Numscriptex.Balance{
                 account: "b",
                 asset: "USD/2",
                 final_balance: 20,
                 initial_balance: 0,
                 decimal_final_balance: 0.2,
                 decimal_initial_balance: 0.0
               },
               %Numscriptex.Balance{
                 account: "c",
                 asset: "USD/2",
                 final_balance: 20,
                 initial_balance: 0,
                 decimal_final_balance: 0.2,
                 decimal_initial_balance: 0.0
               },
               %Numscriptex.Balance{
                 account: "d",
                 asset: "USD/2",
                 final_balance: 59,
                 initial_balance: 0,
                 decimal_final_balance: 0.59,
                 decimal_initial_balance: 0.0
               }
             ]
    end

    test "variables injection" do
      script = """
      vars {
        account $user
        monetary $fee
        portion $tax
      }

      send $fee (
        source = $user
        destination = {
          $tax to @platform:tax
          remaining to @platform:revenue
        }
      )
      """

      metadata = %{}
      variables = %{"fee" => "USD/2 100", "tax" => "20%", "user" => "users:1234"}
      balances = %{"users:1234" => %{"USD/2" => 10_000}}

      struct = build_run_struct(balances, metadata, variables)

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 amount: 20,
                 decimal_amount: 0.2,
                 asset: "USD/2",
                 destination: "platform:tax",
                 source: "users:1234"
               },
               %Numscriptex.Posting{
                 amount: 80,
                 decimal_amount: 0.8,
                 asset: "USD/2",
                 destination: "platform:revenue",
                 source: "users:1234"
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "users:1234",
                 asset: "USD/2",
                 final_balance: 9900,
                 initial_balance: 10_000,
                 decimal_final_balance: 99.0,
                 decimal_initial_balance: 100.0
               },
               %Numscriptex.Balance{
                 account: "platform:tax",
                 asset: "USD/2",
                 final_balance: 20,
                 initial_balance: 0,
                 decimal_final_balance: 0.2,
                 decimal_initial_balance: 0.0
               },
               %Numscriptex.Balance{
                 account: "platform:revenue",
                 asset: "USD/2",
                 final_balance: 80,
                 initial_balance: 0,
                 decimal_final_balance: 0.8,
                 decimal_initial_balance: 0.0
               }
             ]
    end

    test "metadata variables" do
      script = """
      vars {
        account $order
        account $merchant = meta($order, "merchant")
        portion $commission = meta($merchant, "commission")
      }

      send [USD/2 *] (
        source = $order
        destination = {
          $commission to @platform:fees
          remaining to $merchant
        }
      )
      """

      variables = %{"order" => "orders:2345"}
      balances = %{"orders:2345" => %{"USD/2" => 1000}}

      metadata = %{
        "merchants:1234" => %{"commission" => "15%"},
        "orders:2345" => %{"merchant" => "merchants:1234"}
      }

      struct = build_run_struct(balances, metadata, variables)

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 amount: 150,
                 decimal_amount: 1.5,
                 asset: "USD/2",
                 destination: "platform:fees",
                 source: "orders:2345"
               },
               %Numscriptex.Posting{
                 amount: 850,
                 decimal_amount: 8.5,
                 asset: "USD/2",
                 destination: "merchants:1234",
                 source: "orders:2345"
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "orders:2345",
                 asset: "USD/2",
                 final_balance: 0,
                 initial_balance: 1000,
                 decimal_final_balance: 0.0,
                 decimal_initial_balance: 10.0
               },
               %Numscriptex.Balance{
                 account: "platform:fees",
                 asset: "USD/2",
                 final_balance: 150,
                 initial_balance: 0,
                 decimal_final_balance: 1.5,
                 decimal_initial_balance: 0.0
               },
               %Numscriptex.Balance{
                 account: "merchants:1234",
                 asset: "USD/2",
                 final_balance: 850,
                 initial_balance: 0,
                 decimal_final_balance: 8.5,
                 decimal_initial_balance: 0.0
               }
             ]
    end

    test "transactions to itself" do
      balances = %{"user" => %{"USD/2" => 1000}}
      struct = build_run_struct(balances, %{}, %{})

      script = """
      send [USD/2 1000] (
        source = @user
        destination = @user
      )
      """

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 amount: 1000,
                 decimal_amount: 10.0,
                 asset: "USD/2",
                 destination: "user",
                 source: "user"
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "user",
                 asset: "USD/2",
                 final_balance: 1000,
                 initial_balance: 1000,
                 decimal_final_balance: 10.0,
                 decimal_initial_balance: 10.0
               }
             ]
    end

    test "transactions to itself and another destination" do
      balances = %{"user" => %{"USD/2" => 1000}, "user2" => %{"USD/2" => 1000}}
      struct = build_run_struct(balances, %{}, %{})

      script = """
      send [USD/2 1000] (
        source = @user
        destination = {
          62% to @user
          27% to @user2
          remaining to @user3
        }
      )
      """

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 amount: 620,
                 decimal_amount: 6.2,
                 asset: "USD/2",
                 destination: "user",
                 source: "user"
               },
               %Numscriptex.Posting{
                 amount: 270,
                 decimal_amount: 2.7,
                 asset: "USD/2",
                 destination: "user2",
                 source: "user"
               },
               %Numscriptex.Posting{
                 amount: 110,
                 decimal_amount: 1.1,
                 asset: "USD/2",
                 destination: "user3",
                 source: "user"
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "user",
                 asset: "USD/2",
                 final_balance: 620,
                 initial_balance: 1000,
                 decimal_final_balance: 6.2,
                 decimal_initial_balance: 10.0
               },
               %Numscriptex.Balance{
                 account: "user2",
                 asset: "USD/2",
                 final_balance: 1270,
                 initial_balance: 1000,
                 decimal_final_balance: 12.7,
                 decimal_initial_balance: 10.0
               },
               %Numscriptex.Balance{
                 account: "user3",
                 asset: "USD/2",
                 final_balance: 110,
                 initial_balance: 0,
                 decimal_final_balance: 1.1,
                 decimal_initial_balance: 0.0
               }
             ]
    end

    test "save a minimum amount from source" do
      balances = %{"user" => %{"USD/2" => 1000}}
      struct = build_run_struct(balances, %{}, %{})

      script = """
      // Now that we are saving $5 from the total amount of $10,
      // the user will only have $5 to spend, thus failing the transaction
      // given that the user will need $5,01.
      save [USD/2 500] from @user
      send [USD/2 501] (
        source = @user
        destination = @dest
      )
      """

      assert {:error, error} = Numscriptex.run(script, struct)
      assert error.details == "Not enough funds. Needed [USD/2 501] (only [USD/2 500] available)"
    end

    test "with experimental feature flags" do
      script = """
      vars {
        monetary $mon = [USD/2 100]
        number $n = get_amount($mon)
      }

      send [USD/2 $n] (
        source = oneof {
          @foo
          @bar
        }

        destination = @baz
      )
      """

      balances = %{"bar" => %{"USD/2" => 500, "EUR/2" => 300}}
      feature_flags = %{"experimental-oneof" => true, "experimental-get-amount-function" => true, "experimental-mid-script-function-call" => true}
      metadata = %{}
      variables = %{}

      struct = build_run_struct(balances, metadata, variables, feature_flags)

      assert {:ok, result} = Numscriptex.run(script, struct)

      assert result.postings == [
               %Numscriptex.Posting{
                 source: "bar",
                 destination: "baz",
                 asset: "USD/2",
                 amount: 100,
                 decimal_amount: 1.0
               }
             ]

      assert result.balances == [
               %Numscriptex.Balance{
                 account: "bar",
                 asset: "EUR/2",
                 final_balance: 300,
                 initial_balance: 300,
                 decimal_final_balance: 3.0,
                 decimal_initial_balance: 3.0
               },
               %Numscriptex.Balance{
                 account: "bar",
                 asset: "USD/2",
                 final_balance: 400,
                 initial_balance: 500,
                 decimal_final_balance: 4.0,
                 decimal_initial_balance: 5.0
               },
               %Numscriptex.Balance{
                 account: "baz",
                 asset: "USD/2",
                 final_balance: 100,
                 initial_balance: 0,
                 decimal_final_balance: 1.0,
                 decimal_initial_balance: 0.0
               }
               # foo is not present because he does not have any balance
             ]
    end

    test "with insufficient amount" do
      script = """
      send [USD/2 100] (
        source = @foo
        destination = @bar
      )
      """

      variables = %{}
      metadata = %{}
      balances = %{"foo" => %{"USD/2" => 99, "EUR/2" => 200}}

      struct = build_run_struct(balances, metadata, variables)

      assert {:error, error} = Numscriptex.run(script, struct)

      assert error.details ==
               "Not enough funds. Needed [USD/2 100] (only [USD/2 99] available)"
    end

    test "with variables missing" do
      script = """
      vars {
        account $user
        monetary $fee
        portion $tax
      }

      send $fee (
        source = $user
        destination = {
          $tax to @platform:tax
          remaining to @platform:revenue
        }
      )
      """

      metadata = %{}
      balances = %{"users:1234" => %{"USD/2" => 10_000}}
      variables = %{"fee" => "USD/2 100", "tax" => "20%"}

      struct = build_run_struct(balances, metadata, variables)

      assert {:error, error} = Numscriptex.run(script, struct)
      assert error.details == "Variable is missing in json: user"
    end

    test "fails with invalid script" do
      script = "sd ( source = @foo destination = @bar)"

      assert {:error, error} = Numscriptex.run(script, %Numscriptex.Run{})

      assert error.details ==
               "Got errors while parsing:\nmismatched input 'source' expecting {'overdraft', '(', ')', '[', PERCENTAGE_PORTION_LITERAL, STRING, IDENTIFIER, NUMBER, ASSET, '@', VARIABLE_NAME}\n  0 | sd ( source = @foo destination = @bar)\n    |      ~~~~~"
    end

    test "fails with invalid script but valid sctruct" do
      assert {:error, error} = Numscriptex.run(%{script: ""}, %Numscriptex.Run{})

      assert error.details ==
               "json: cannot unmarshal object into Go struct field RunInputOpts.script of type string"
    end

    test "fails with valid script but invalid sctruct" do
      script = "send [USD/2 100] ( source = @foo destination = @bar)"

      assert {:error, error} = Numscriptex.run(script, %{})
      assert error.reason == :badarg
    end
  end

  defp build_run_struct(balances, metadata, variables, feature_flags \\ %{}) do
    %Numscriptex.Run{}
    |> Numscriptex.Run.put!(:balances, balances)
    |> Numscriptex.Run.put!(:metadata, metadata)
    |> Numscriptex.Run.put!(:variables, variables)
    |> Numscriptex.Run.put!(:featureFlags, feature_flags)
  end

  describe "version/0" do
    setup do
      numscriptex_version =
        :numscriptex
        |> Application.spec(:vsn)
        |> to_string()

      %{numscriptex_version: numscriptex_version}
    end

    test "shows both the Numscript-WASM and NumscriptEx versions", %{
      numscriptex_version: numscriptex_version
    } do
      [numscript_wasm_version] = AssetsManager.__info__(:attributes)[:numscript_wasm_version]
      versions = Numscriptex.version()

      assert versions.numscript_wasm == "v#{numscript_wasm_version}"
      assert versions.numscriptex == "v#{numscriptex_version}"
    end

    @tag :tmp_dir
    test "in case of errors numscript-wasm version is returned as 'unknown'", %{
      tmp_dir: tmp_dir,
      numscriptex_version: numscriptex_version
    } do
      wasm_binary_path = AssetsManager.binary_path()
      dest_path = Path.join(tmp_dir, "numscript.wasm")

      File.copy!(wasm_binary_path, dest_path)
      File.copy!(wasm_binary_path, wasm_binary_path, 1024)

      versions = Numscriptex.version()

      assert versions.numscript_wasm == "unknown"
      assert versions.numscriptex == "v#{numscriptex_version}"

      File.copy!(dest_path, wasm_binary_path)
    end
  end
end
