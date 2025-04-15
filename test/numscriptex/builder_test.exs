defmodule Numscriptex.BuilderTest do
  use ExUnit.Case

  alias Numscriptex.Builder

  doctest Numscriptex.Builder

  describe "build/1" do
    test "simple send with fixed value" do
      metadata = %{
        splits: [
          %{
            type: :fixed,
            amount: 500,
            asset: "USD",
            account: "some:destination"
          }
        ]
      }

      assert {:ok, %{script: script}} = Builder.build(metadata)
      assert {:ok, _script} = Numscriptex.check(script)

      assert script == """
             send [USD 500] (
               source = @user
               destination = @some:destination
             )
             """
    end

    test "simple send with percentage value" do
      metadata = %{
        splits: [
          %{
            type: :percent,
            amount: 20,
            asset: "USD",
            account: "some:destination"
          }
        ],
        percent_asset: "USD"
      }

      assert {:ok, %{script: script}} = Builder.build(metadata)
      assert {:ok, _script} = Numscriptex.check(script)

      assert script == """
             send [USD *] (
               source = @user
               destination = {
                 20% to @some:destination
                 remaining kept
               }
             )
             """
    end

    test "multiple send with both fixed and percentage value with 'remaining_to' opt" do
      metadata = %{
        splits: [
          %{
            type: :percent,
            amount: 20,
            account: "some:destination:a"
          },
          %{
            type: :fixed,
            amount: 1000,
            asset: "USD",
            account: "some:destination:b"
          }
        ],
        percent_asset: "USD",
        remaining_to: "another:destination"
      }

      assert {:ok, %{script: script}} = Builder.build(metadata)
      assert {:ok, _script} = Numscriptex.check(script)

      assert script == """
             send [USD *] (
               source = @user
               destination = {
                 20% to @some:destination:a
                 remaining to @another:destination
               }
             )
             send [USD 1000] (
               source = @user
               destination = @some:destination:b
             )
             """
    end

    test "multiple send with nested destinations and fixed values and 'remaining_to' opt" do
      metadata = %{
        splits: [
          %{
            type: :fixed,
            amount: 1050,
            asset: "EUR",
            account: "some:destination:a"
          },
          %{
            type: :percent,
            amount: 20,
            account: "some:destination:b"
          },
          %{
            type: :percent,
            amount: 30,
            remaining_to: "remaining:destination:b",
            splits: [
              %{
                type: :fixed,
                amount: 1250,
                asset: "USD",
                account: "some:destination:c"
              },
              %{
                type: :percent,
                amount: 15,
                account: "some:destination:e"
              },
              %{
                type: :percent,
                amount: 20,
                account: "some:destination:d"
              },
              %{
                type: :percent,
                amount: 50,
                remaining_to: "remaining:destination:c",
                splits: [
                  %{
                    type: :fixed,
                    amount: 500,
                    asset: "BRL",
                    account: "some:destination:b"
                  },
                  %{
                    type: :percent,
                    amount: 20,
                    account: "some:destination:a"
                  },
                  %{
                    type: :percent,
                    amount: 27,
                    account: "some:destination:a"
                  }
                ]
              }
            ]
          }
        ],
        remaining_to: "remaining:destination:a",
        percent_asset: "EUR"
      }

      assert {:ok, %{script: script}} = Builder.build(metadata)
      assert {:ok, _script} = Numscriptex.check(script)

      assert script == """
             send [EUR *] (
               source = @user
               destination = {
                 20% to @some:destination:b
                 30% to {
                 15% to @some:destination:e
                 20% to @some:destination:d
                 50% to {
                 20% to @some:destination:a
                 27% to @some:destination:a
                   remaining to @remaining:destination:c
                 }
                   remaining to @remaining:destination:b
                 }
                 remaining to @remaining:destination:a
               }
             )
             send [BRL 500] (
               source = @user
               destination = @some:destination:b
             )
             send [USD 1250] (
               source = @user
               destination = @some:destination:c
             )
             send [EUR 1050] (
               source = @user
               destination = @some:destination:a
             )
             """
    end

    test "ignores account if split has nested splits" do
      metadata = %{
        splits: [
          %{
            type: :percent,
            amount: 50,
            account: "ignored:account",
            remaining_to: "remaining:destination",
            splits: [
              %{
                type: :percent,
                amount: 20,
                account: "some:destination"
              }
            ]
          }
        ],
        percent_asset: "EUR",
        remaining_to: "remaining:destination:a"
      }

      assert {:ok, %{script: script}} = Builder.build(metadata)
      assert {:ok, _script} = Numscriptex.check(script)

      assert script == """
             send [EUR *] (
               source = @user
               destination = {
                 50% to {
                 20% to @some:destination
                   remaining to @remaining:destination
                 }
                 remaining to @remaining:destination:a
               }
             )
             """
    end

    test "ignores splits when is empty" do
      metadata = %{
        splits: [
          %{
            type: :percent,
            amount: 50,
            account: "ignored:account",
            remaining_to: "remaining:destination",
            splits: [
              %{
                type: :percent,
                amount: 20,
                account: "some:destination",
                splits: []
              }
            ]
          }
        ],
        percent_asset: "EUR",
        remaining_to: "remaining:destination:a"
      }

      assert {:ok, %{script: script}} = Builder.build(metadata)
      assert {:ok, _script} = Numscriptex.check(script)

      assert script == """
             send [EUR *] (
               source = @user
               destination = {
                 50% to {
                 20% to @some:destination
                   remaining to @remaining:destination
                 }
                 remaining to @remaining:destination:a
               }
             )
             """
    end

    test "if missing remaining_to, default to 'remaining kept'" do
      metadata = %{
        splits: [
          %{
            type: :percent,
            amount: 50,
            # missing remaining_to
            splits: [
              %{
                type: :percent,
                amount: 20,
                account: "some:destination"
              }
            ]
          }
        ],
        percent_asset: "EUR"
        # missing remaining_to
      }

      assert {:ok, %{script: script}} = Builder.build(metadata)
      assert {:ok, _script} = Numscriptex.check(script)

      assert script == """
             send [EUR *] (
               source = @user
               destination = {
                 50% to {
                 20% to @some:destination
                   remaining kept
                 }
                 remaining kept
               }
             )
             """
    end

    test "returns error when split type is invalid" do
      metadata = %{
        splits: [
          %{
            type: :invalid,
            amount: 20,
            account: "some:destination"
          }
        ],
        remaining_to: "remaining:destination",
        percent_asset: "EUR"
      }

      assert {:error, "Missing key on metadata."} = Builder.build(metadata)
    end

    test "returns error when splits key is missing" do
      metadata = %{
        remaining_to: "remaining:destination",
        percent_asset: "EUR"
      }

      assert {:error, "Missing key on metadata."} = Builder.build(metadata)
    end

    test "returns error when remaining_to is not a string" do
      metadata = %{
        splits: [
          %{
            type: :percent,
            amount: 20,
            account: "some:destination"
          }
        ],
        remaining_to: 123,
        percent_asset: "EUR"
      }

      assert {:error, "Invalid remaining destination."} = Builder.build(metadata)
    end

    test "returns error when percent_asset is not a string" do
      metadata = %{
        splits: [
          %{
            type: :percent,
            amount: 20,
            account: "some:destination"
          }
        ],
        percent_asset: 123
      }

      assert {:error, "Invalid asset."} = Builder.build(metadata)
    end

    test "returns error when percent_asset is empty" do
      metadata = %{
        splits: [
          %{
            type: :percent,
            amount: 20,
            account: "some:destination"
          }
        ],
        percent_asset: ""
      }

      assert {:error, "Invalid asset."} = Builder.build(metadata)
    end

    test "returns error when percent splits exist but percent_asset is missing" do
      metadata = %{
        splits: [
          %{
            type: :percent,
            amount: 20,
            account: "some:destination"
          }
        ]
      }

      assert {:error, "Missing key on metadata."} = Builder.build(metadata)
    end

    test "returns error when remaining_to is empty" do
      metadata = %{
        splits: [
          %{
            type: :percent,
            amount: 20,
            account: "some:destination"
          }
        ],
        remaining_to: "",
        percent_asset: "EUR"
      }

      assert {:error, "Invalid remaining destination."} = Builder.build(metadata)
    end

    test "returns error when percent amount is negative" do
      metadata = %{
        splits: [
          %{
            type: :percent,
            amount: -20,
            account: "some:destination"
          }
        ],
        percent_asset: "EUR"
      }

      assert {:error, "Invalid metadata."} = Builder.build(metadata)
    end

    test "returns error when percent amount is greater than 100" do
      metadata = %{
        splits: [
          %{
            type: :percent,
            amount: 120,
            account: "some:destination"
          }
        ],
        percent_asset: "EUR"
      }

      assert {:error, "Invalid metadata."} = Builder.build(metadata)
    end

    test "returns error when percent split has invalid amount" do
      metadata = %{
        splits: [
          %{
            type: :percent,
            amount: 101,
            account: "some:destination"
          }
        ],
        percent_asset: "EUR"
      }

      assert {:error, "Invalid metadata."} = Builder.build(metadata)
    end

    test "returns error when fixed split is missing asset" do
      metadata = %{
        splits: [
          %{
            type: :fixed,
            amount: 500,
            account: "some:destination"
          }
        ]
      }

      assert {:error, "Missing key on metadata."} = Builder.build(metadata)
    end

    test "returns error when fixed split has empty destination" do
      metadata = %{
        splits: [
          %{
            type: :fixed,
            amount: 500,
            asset: "USD",
            account: ""
          }
        ]
      }

      assert {:error, "Invalid destination."} = Builder.build(metadata)
    end

    test "returns error when fixed split has empty asset" do
      metadata = %{
        splits: [
          %{
            type: :fixed,
            amount: 500,
            asset: "",
            account: "some:destination"
          }
        ]
      }

      assert {:error, "Invalid asset."} = Builder.build(metadata)
    end

    test "returns error when fixed split has negative amount" do
      metadata = %{
        splits: [
          %{
            type: :fixed,
            amount: -500,
            asset: "USD",
            account: "some:destination"
          }
        ]
      }

      assert {:error, "Invalid metadata."} = Builder.build(metadata)
    end

    test "returns error when fixed split amount is not a number" do
      metadata = %{
        splits: [
          %{
            type: :fixed,
            amount: "500",
            asset: "USD",
            account: "some:destination"
          }
        ]
      }

      assert {:error, "Invalid metadata."} = Builder.build(metadata)
    end
  end
end
