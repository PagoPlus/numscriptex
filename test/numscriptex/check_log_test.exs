defmodule Numscriptex.CheckLogTest do
  use ExUnit.Case

  alias Numscriptex.CheckLog

  doctest Numscriptex.CheckLog

  describe "from_map/1" do
    test "transform a map into a Posting struct" do
      map = %{
        character: 10,
        level: :warning,
        line: 1,
        message: "warning message"
      }

      assert struct = CheckLog.from_map(map)

      assert struct == %CheckLog{
               character: 10,
               level: :warning,
               line: 1,
               message: "warning message"
             }
    end
  end
end
