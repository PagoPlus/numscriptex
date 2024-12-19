defmodule Numscriptex.CheckLogTest do
  use ExUnit.Case
  doctest Numscriptex.CheckLog

  alias Numscriptex.CheckLog

  describe "from_map/1" do
    test "creates a new struct from a map" do
      map = %{
        character: 10,
        level:  :warning,
        line: 1,
        message: "warning message"
      }

      assert struct = CheckLog.from_map(map)
      assert struct == %CheckLog{
        character: 10,
        level:  :warning,
        line: 1,
        message: "warning message"
      }
    end
  end
end
