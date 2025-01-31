defmodule Numscriptex.AssetsManagerTest do
  use ExUnit.Case, async: false

  alias Numscriptex.AssetsManager

  import AssetsManager, only: [hash_wasm_binary: 0]

  require AssetsManager
  require Logger

  doctest AssetsManager

  setup_all do
    binary_path =
      :numscriptex
      |> :code.priv_dir()
      |> Path.join("numscript.wasm")

    %{binary_path: binary_path}
  end

  describe "ensure_wasm_binary_is_installed_and_valid/0" do
    test "if the binary exists and is valid, do nothing", %{binary_path: binary_path} do
      assert File.exists?(binary_path)
      assert {:ok, file_stats_before} = File.stat(binary_path)

      AssetsManager.ensure_wasm_binary_is_valid()
      assert {:ok, file_stats_after} = File.stat(binary_path)

      assert File.exists?(binary_path)
      assert file_stats_before.ctime == file_stats_after.ctime
    end

    test "if the binary does not exists, install a new one", %{binary_path: binary_path} do
      assert File.rm(binary_path) == :ok
      refute File.exists?(binary_path)

      AssetsManager.ensure_wasm_binary_is_valid()

      assert File.exists?(binary_path)
    end

    @tag :tmp_dir
    test "if the binary exists but is invalid, install a valid one", %{
      binary_path: binary_path,
      tmp_dir: tmp_dir
    } do
      dest_path = Path.join(tmp_dir, "numscript.wasm")
      expected_checksums = unquote(hash_wasm_binary())

      File.copy!(binary_path, dest_path)
      File.copy!(binary_path, binary_path, 1024)

      wrong_checksums = unquote(hash_wasm_binary())
      assert expected_checksums != wrong_checksums

      AssetsManager.ensure_wasm_binary_is_valid()

      new_checksums = unquote(hash_wasm_binary())
      assert new_checksums == expected_checksums

      File.copy!(dest_path, binary_path)
    end
  end
end
