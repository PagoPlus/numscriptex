defmodule Numscriptex.CompilationSettings do
  @moduledoc false

  @file_version Application.compile_env(:numscriptex, :file_version, "0.23.4")
  @url "https://github.com/yarnpkg/yarn/releases/download/v#{@file_version}/yarn-v#{@file_version}.tar.gz"
  @download_path System.tmp_dir()
                 |> Path.join("yarn-v#{@file_version}.tar.gz")
                 |> String.to_charlist()

  defmacro ensure_wasm_file_exists do
    quote do
      file_path =
        :numscriptex
        |> :code.priv_dir()
        |> Path.join("dist")

      if File.exists?(file_path) do
        Logger.info("WASM file already exists.")
      else
        Logger.info("Downloading numscript-wasm.tar.gz")
        unquote(download_wasm_file())
        Logger.info("numscript-wasm.tar.gz downloaded")

        Logger.info("Extracting numscript-wasm.tar.gz")

        :erl_tar.extract(unquote(@download_path), [
          {:cwd, :code.priv_dir(:numscriptex)},
          :compressed
        ])

        Logger.info("File successfully extracted on priv directory.")
      end
    end
  end

  defp download_wasm_file do
    quote do
      download_path = unquote(@download_path)

      {:ok, :saved_to_file} =
        :httpc.request(:get, {unquote(@url), []}, [], stream: download_path)
    end
  end
end
