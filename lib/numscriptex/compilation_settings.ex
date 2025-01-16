defmodule Numscriptex.CompilationSettings do
  @moduledoc false

  @file_version Application.compile_env(:numscriptex, :file_version, "0.23.4")
  @ensure_wasm_file_exists? Application.compile_env(:numscriptex, :ensure_wasm_file_exists?, true)
  # @url "https://github.com/PagoPlus/numscript-wasm/releases/download/v#{@file_version}/numscript-wasm_v#{@file_version}_Wasip1_wasm.tar.gz"
  @url "https://github.com/yarnpkg/yarn/releases/download/v#{@file_version}/yarn-v#{@file_version}.tar.gz"
  @download_path System.tmp_dir()
                 # |> Path.join("numscript-wasm_v#{@file_version}_Wasip1_wasm.tar.gz")
                 |> Path.join("yarn-v#{@file_version}.tar.gz")
                 |> String.to_charlist()

  defmacro download_and_extract_wasm_file do
    quote do
      if unquote(@ensure_wasm_file_exists?) do
        download_result = unquote(download_wasm_file())

        with :ok <- download_result, do: unquote(extract_wasm_file())
      end
    end
  end

  defp download_wasm_file do
    quote do
      Logger.info("Downloading numscript-wasm.tar.gz")

      case :httpc.request(:get, {unquote(@url), []}, [], stream: unquote(@download_path)) do
        {:ok, :saved_to_file} ->
          Logger.info("numscript-wasm.tar.gz downloaded")

          :ok

        {:ok, {{_, status_code, detail}, _, _}} when status_code not in 200..299 ->
          Logger.error("Download request failed with status code #{status_code} #{detail}.")

          :error

        {:error, reason} ->
          Logger.error("Failed to download numscript-wasm. Reason: #{reason}.")

          :error
      end
    end
  end

  defp extract_wasm_file do
    quote do
      Logger.info("Extracting numscript-wasm.tar.gz")

      extraction_result =
        :erl_tar.extract(unquote(@download_path), [
          {:cwd, :code.priv_dir(:numscriptex)},
          :compressed
        ])

      case extraction_result do
        :ok ->
          Logger.info("File successfully extracted on priv directory.")

          :ok

        {:ok, _} ->
          Logger.info("File successfully extracted on priv directory.")

          :ok

        {:error, reason} ->
          Logger.error("Failed to extract the tar.gz file. Reason: #{inspect(reason)}.")

          :error
      end
    end
  end
end
