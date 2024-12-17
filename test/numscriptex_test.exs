defmodule NumscriptexTest do
  use ExUnit.Case

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
      assert {:ok, result} = Numscriptex.check(script)
      assert is_map(result)
      assert result.script == script
    end

    test "with valid script, but unused var", %{warning_script: warning_script} do
      assert {:ok, result} = Numscriptex.check(warning_script)
      assert is_map(result)
      assert result.script == warning_script

      assert result.details == %{
               "warnings" => [
                 %{
                   "character" => 10,
                   "level" => "warning",
                   "line" => 1,
                   "warning" => "The variable '$unused' is never used"
                 }
               ]
             }

      has_errors? = Map.has_key?(result.details, "errors")

      refute has_errors?
    end

    test "with invalid script", %{script: script} do
      error_script = String.replace(script, "a", "e")

      assert {:error, result} = Numscriptex.check(error_script)
      assert [error | _errors] = result["errors"]

      assert error == %{
               "character" => 0,
               "level" => "error",
               "line" => 0,
               "error" => "The function 'vers' does not exist"
             }
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

      assert result["postings"] == [
               %{
                 "amount" => 100,
                 "asset" => "USD/2",
                 "destination" => "bar",
                 "source" => "foo"
               }
             ]

      assert result["balances"] == [
               %{
                 "account" => "foo",
                 "asset" => "EUR/2",
                 "final_balance" => 300,
                 "initial_balance" => 300
               },
               %{
                 "account" => "foo",
                 "asset" => "USD/2",
                 "final_balance" => 400,
                 "initial_balance" => 500
               },
               %{
                 "account" => "bar",
                 "asset" => "USD/2",
                 "final_balance" => 100,
                 "initial_balance" => 0
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

      assert result["postings"] == [
               %{"amount" => 100, "asset" => "USD/2", "destination" => "bar", "source" => "foo"},
               %{"amount" => 100, "asset" => "USD/2", "destination" => "baz", "source" => "bar"}
             ]

      assert result["balances"] == [
               %{
                 "account" => "foo",
                 "asset" => "USD/2",
                 "final_balance" => 400,
                 "initial_balance" => 500
               },
               %{
                 "account" => "baz",
                 "asset" => "USD/2",
                 "final_balance" => 100,
                 "initial_balance" => 0
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

      assert result["postings"] == [
               %{
                 "amount" => 5000,
                 "asset" => "USD/2",
                 "destination" => "orders:4567:payment",
                 "source" => "users:1234:main"
               },
               %{
                 "amount" => 1000,
                 "asset" => "USD/2",
                 "destination" => "orders:4567:payment",
                 "source" => "users:1234:vouchers:2024-01-31"
               },
               %{
                 "amount" => 3000,
                 "asset" => "USD/2",
                 "destination" => "orders:4567:payment",
                 "source" => "users:1234:vouchers:2024-02-17"
               },
               %{
                 "amount" => 1000,
                 "asset" => "USD/2",
                 "destination" => "orders:4567:payment",
                 "source" => "users:1234:vouchers:2024-03-22"
               }
             ]

      assert result["balances"] == [
               %{
                 "account" => "users:1234:main",
                 "asset" => "USD/2",
                 "final_balance" => 0,
                 "initial_balance" => 5000
               },
               %{
                 "account" => "users:1234:vouchers:2024-01-31",
                 "asset" => "USD/2",
                 "final_balance" => 0,
                 "initial_balance" => 1000
               },
               %{
                 "account" => "users:1234:vouchers:2024-02-17",
                 "asset" => "USD/2",
                 "final_balance" => 0,
                 "initial_balance" => 3000
               },
               %{
                 "account" => "users:1234:vouchers:2024-03-22",
                 "asset" => "USD/2",
                 "final_balance" => 9000,
                 "initial_balance" => 10_000
               },
               %{
                 "account" => "orders:4567:payment",
                 "asset" => "USD/2",
                 "final_balance" => 10_000,
                 "initial_balance" => 0
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

      assert result["postings"] == [
               %{
                 "amount" => 2000,
                 "asset" => "USD/2",
                 "destination" => "payments:4567",
                 "source" => "coupons:FALL24"
               },
               %{
                 "amount" => 27_900,
                 "asset" => "USD/2",
                 "destination" => "payments:4567",
                 "source" => "users:1234"
               },
               %{
                 "amount" => 900,
                 "asset" => "USD/2",
                 "destination" => "payments:5678",
                 "source" => "coupons:FALL24"
               },
               %{
                 "amount" => 8100,
                 "asset" => "USD/2",
                 "destination" => "payments:5678",
                 "source" => "users:1234"
               }
             ]

      assert result["balances"] == [
               %{
                 "account" => "coupons:FALL24",
                 "asset" => "USD/2",
                 "final_balance" => 97_000,
                 "initial_balance" => 99_900
               },
               %{
                 "account" => "users:1234",
                 "asset" => "USD/2",
                 "final_balance" => 64_000,
                 "initial_balance" => 100_000
               },
               %{
                 "account" => "payments:4567",
                 "asset" => "USD/2",
                 "final_balance" => 29_900,
                 "initial_balance" => 0
               },
               %{
                 "account" => "payments:5678",
                 "asset" => "USD/2",
                 "final_balance" => 9000,
                 "initial_balance" => 0
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

      assert result["postings"] == [
               %{
                 "amount" => 10,
                 "asset" => "USD/2",
                 "destination" => "platform:fees",
                 "source" => "orders:1234"
               },
               %{
                 "amount" => 90,
                 "asset" => "USD/2",
                 "destination" => "merchants:6789",
                 "source" => "orders:1234"
               }
             ]

      assert result["balances"] == [
               %{
                 "account" => "orders:1234",
                 "asset" => "USD/2",
                 "final_balance" => 900,
                 "initial_balance" => 1000
               },
               %{
                 "account" => "platform:fees",
                 "asset" => "USD/2",
                 "final_balance" => 10,
                 "initial_balance" => 0
               },
               %{
                 "account" => "merchants:6789",
                 "asset" => "USD/2",
                 "final_balance" => 90,
                 "initial_balance" => 0
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

      assert result["postings"] == [
               %{
                 "amount" => 300,
                 "asset" => "USD/2",
                 "destination" => "platform:commission:sales_tax",
                 "source" => "orders:1234"
               },
               %{
                 "amount" => 1200,
                 "asset" => "USD/2",
                 "destination" => "platform:commission:revenue",
                 "source" => "orders:1234"
               },
               %{
                 "amount" => 500,
                 "asset" => "USD/2",
                 "destination" => "users:1234:cashback",
                 "source" => "orders:1234"
               },
               %{
                 "amount" => 8000,
                 "asset" => "USD/2",
                 "destination" => "merchants:6789",
                 "source" => "orders:1234"
               }
             ]

      assert result["balances"] == [
               %{
                 "account" => "orders:1234",
                 "asset" => "USD/2",
                 "final_balance" => 0,
                 "initial_balance" => 10_000
               },
               %{
                 "account" => "platform:commission:sales_tax",
                 "asset" => "USD/2",
                 "final_balance" => 300,
                 "initial_balance" => 0
               },
               %{
                 "account" => "platform:commission:revenue",
                 "asset" => "USD/2",
                 "final_balance" => 1200,
                 "initial_balance" => 0
               },
               %{
                 "account" => "users:1234:cashback",
                 "asset" => "USD/2",
                 "final_balance" => 500,
                 "initial_balance" => 0
               },
               %{
                 "account" => "merchants:6789",
                 "asset" => "USD/2",
                 "final_balance" => 8000,
                 "initial_balance" => 0
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

      assert result["postings"] == [
               %{
                 "amount" => 500,
                 "asset" => "USD/2",
                 "destination" => "payment",
                 "source" => "users:1234"
               }
             ]

      assert result["balances"] == [
               %{
                 "account" => "users:1234",
                 "asset" => "USD/2",
                 "final_balance" => 0,
                 "initial_balance" => 500
               },
               %{
                 "account" => "payment",
                 "asset" => "USD/2",
                 "final_balance" => 500,
                 "initial_balance" => 0
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

      assert result["postings"] == [
               %{
                 "amount" => 100,
                 "asset" => "USD/2",
                 "destination" => "payments:4567",
                 "source" => "users:1234"
               },
               %{
                 "amount" => 1000,
                 "asset" => "USD/2",
                 "destination" => "payments:4567",
                 "source" => "users:2345:credit"
               },
               %{
                 "amount" => 5000,
                 "asset" => "USD/2",
                 "destination" => "payments:4567",
                 "source" => "users:2345:main"
               }
             ]

      assert result["balances"] == [
               %{
                 "account" => "users:2345:main",
                 "asset" => "USD/2",
                 "final_balance" => 0,
                 "initial_balance" => 5000
               },
               %{
                 "account" => "users:1234",
                 "asset" => "USD/2",
                 "final_balance" => -100,
                 "initial_balance" => 0
               },
               %{
                 "account" => "payments:4567",
                 "asset" => "USD/2",
                 "final_balance" => 6100,
                 "initial_balance" => 0
               },
               %{
                 "account" => "users:2345:credit",
                 "asset" => "USD/2",
                 "final_balance" => -1000,
                 "initial_balance" => 0
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

      assert result["postings"] == [
               %{
                 "amount" => 5,
                 "asset" => "USD/2",
                 "destination" => "platform:fees",
                 "source" => "users:1234"
               }
             ]

      assert result["balances"] == [
               %{
                 "account" => "users:1234",
                 "asset" => "USD/2",
                 "final_balance" => 495,
                 "initial_balance" => 500
               },
               %{
                 "account" => "platform:fees",
                 "asset" => "USD/2",
                 "final_balance" => 5,
                 "initial_balance" => 0
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

      assert result["postings"] == [
               %{"amount" => 50, "asset" => "USD/2", "destination" => "bar", "source" => "foo"},
               %{"amount" => 49, "asset" => "USD/2", "destination" => "baz", "source" => "foo"},
               %{"amount" => 20, "asset" => "USD/2", "destination" => "b", "source" => "a"},
               %{"amount" => 20, "asset" => "USD/2", "destination" => "c", "source" => "a"},
               %{"amount" => 59, "asset" => "USD/2", "destination" => "d", "source" => "a"}
             ]

      assert result["balances"] == [
               %{
                 "account" => "a",
                 "asset" => "USD/2",
                 "final_balance" => 901,
                 "initial_balance" => 1000
               },
               %{
                 "account" => "foo",
                 "asset" => "USD/2",
                 "final_balance" => 901,
                 "initial_balance" => 1000
               },
               %{
                 "account" => "bar",
                 "asset" => "USD/2",
                 "final_balance" => 50,
                 "initial_balance" => 0
               },
               %{
                 "account" => "baz",
                 "asset" => "USD/2",
                 "final_balance" => 49,
                 "initial_balance" => 0
               },
               %{
                 "account" => "b",
                 "asset" => "USD/2",
                 "final_balance" => 20,
                 "initial_balance" => 0
               },
               %{
                 "account" => "c",
                 "asset" => "USD/2",
                 "final_balance" => 20,
                 "initial_balance" => 0
               },
               %{
                 "account" => "d",
                 "asset" => "USD/2",
                 "final_balance" => 59,
                 "initial_balance" => 0
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

      assert result["postings"] == [
               %{
                 "amount" => 20,
                 "asset" => "USD/2",
                 "destination" => "platform:tax",
                 "source" => "users:1234"
               },
               %{
                 "amount" => 80,
                 "asset" => "USD/2",
                 "destination" => "platform:revenue",
                 "source" => "users:1234"
               }
             ]

      assert result["balances"] == [
               %{
                 "account" => "users:1234",
                 "asset" => "USD/2",
                 "final_balance" => 9900,
                 "initial_balance" => 10_000
               },
               %{
                 "account" => "platform:tax",
                 "asset" => "USD/2",
                 "final_balance" => 20,
                 "initial_balance" => 0
               },
               %{
                 "account" => "platform:revenue",
                 "asset" => "USD/2",
                 "final_balance" => 80,
                 "initial_balance" => 0
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

      assert result["postings"] == [
               %{
                 "amount" => 150,
                 "asset" => "USD/2",
                 "destination" => "platform:fees",
                 "source" => "orders:2345"
               },
               %{
                 "amount" => 850,
                 "asset" => "USD/2",
                 "destination" => "merchants:1234",
                 "source" => "orders:2345"
               }
             ]

      assert result["balances"] == [
               %{
                 "account" => "orders:2345",
                 "asset" => "USD/2",
                 "final_balance" => 0,
                 "initial_balance" => 1000
               },
               %{
                 "account" => "platform:fees",
                 "asset" => "USD/2",
                 "final_balance" => 150,
                 "initial_balance" => 0
               },
               %{
                 "account" => "merchants:1234",
                 "asset" => "USD/2",
                 "final_balance" => 850,
                 "initial_balance" => 0
               }
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
      assert error.reason == "panic: Not enough funds. Needed [USD/2 100] (only [USD/2 99] available)\n"
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
      assert error.reason == "panic: Variable is missing in json: user\n"
    end
  end

  defp build_run_struct(balances, metadata, variables) do
    %Numscriptex.Run{}
    |> Numscriptex.Run.put!(:balances, balances)
    |> Numscriptex.Run.put!(:metadata, metadata)
    |> Numscriptex.Run.put!(:variables, variables)
  end
end
