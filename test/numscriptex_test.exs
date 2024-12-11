defmodule NumscriptexTest do
  use ExUnit.Case

  setup_all do
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

  describe "check/1" do
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
end
