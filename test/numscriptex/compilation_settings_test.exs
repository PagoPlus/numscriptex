defmodule Numscriptex.CompilationSettingsTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias Numscriptex.CompilationSettings

  require CompilationSettings
  require Logger

  doctest CompilationSettings

  setup_all do
    binary_path =
      :numscriptex
      |> :code.priv_dir()
      |> Path.join("numscript.wasm")

    %{binary_path: binary_path}
  end

  describe "ensure_wasm_binary_is_installed_and_valid/0" do
    test "binary does not exists", %{binary_path: binary_path} do
      File.rm!(binary_path)

      expected_logs = [
        "Downloading Numscript-WASM binary.",
        "Numscript-WASM binary downloaded.",
        "Getting remote checksums.",
        "Numscript-WASM checksums downloaded.",
        "Numscript-WASM binary validated with checksums successfully."
      ]

      logs =
        capture_log(fn ->
          CompilationSettings.ensure_wasm_binary_is_installed_and_valid()
        end)

      assert Enum.all?(expected_logs, fn expected_log -> logs =~ expected_log end)
    end

    test "binary exists and is valid" do
      expected_logs = [
        "Numscript-WASM binary already exists, validating with checksums.",
        "Getting remote checksums.",
        "Numscript-WASM checksums downloaded.",
        "Numscript-WASM binary validated with checksums successfully."
      ]

      logs =
        capture_log(fn ->
          CompilationSettings.ensure_wasm_binary_is_installed_and_valid()
        end)

      assert Enum.all?(expected_logs, fn expected_log -> logs =~ expected_log end)
    end

    @tag :tmp_dir
    test "binary exists but is not invalid", %{binary_path: binary_path, tmp_dir: tmp_dir} do
      dest_path = Path.join(tmp_dir, "numscript.wasm")

      File.copy!(binary_path, dest_path)
      File.copy!(binary_path, binary_path, 1024)

      expected_logs = [
        "Numscript-WASM binary already exists, validating with checksums.",
        "Getting remote checksums.",
        "Numscript-WASM checksums downloaded.",
        "Based on the checksums, the numscript-wasm binary is not valid"
      ]

      logs =
        capture_log(fn ->
          CompilationSettings.ensure_wasm_binary_is_installed_and_valid()
        end)

      File.copy!(dest_path, binary_path)

      assert Enum.all?(expected_logs, fn expected_log -> logs =~ expected_log end)
    end
  end
end
