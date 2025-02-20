defmodule Numscriptex.PostingTest do
  use ExUnit.Case

  alias Numscriptex.Posting

  doctest Numscriptex.Posting

  describe "from_map/1" do
    setup_all do
      postings = [
        %{
          amount: 100,
          asset: "USD/2",
          destination: "bar",
          source: "foo"
        },
        %{
          amount: 100,
          asset: "USD/2",
          destination: "baz",
          source: "foo"
        }
      ]

      %{postings: postings}
    end

    test "transforms a list of maps into a list of %Posting{}", %{postings: list} do
      assert postings = Posting.from_list(list)

      assert postings == [
               %Numscriptex.Posting{
                 amount: 100,
                 asset: "USD/2",
                 destination: "bar",
                 source: "foo"
               },
               %Numscriptex.Posting{
                 amount: 100,
                 asset: "USD/2",
                 destination: "baz",
                 source: "bar"
               }
             ]
    end

    test "transforms a map into %Posting{}", %{postings: [map | _]} do
      assert posting = Posting.from_map(map)

      assert posting == %Numscriptex.Posting{
               amount: 100,
               asset: "USD/2",
               destination: "bar",
               source: "foo"
             }
    end
  end
end
