defmodule Numscriptex.CompilationSettings do
  @moduledoc """
  `Numscriptex.CompilationSettings` is responsible for ensuring that the Numscriptex
  library have all that it needs to run correctly at compile time.
  """

  @numscript_checksums_url "https://github.com/PagoPlus/yarn/releases/download/v0.1.0/numscript_checksums.txt"
  @numscript_wasm_url "https://github.com/PagoPlus/yarn/releases/download/v0.1.0/numscript.wasm"
  @binary_path :code.priv_dir(:numscriptex)

  defmacro ensure_wasm_binary_is_installed_and_valid() do
    quote do
      if File.exists?(unquote(@binary_path)) do
        unquote(compare_binary_hash_with_checksums())
      else
        with :ok <- unquote(download_and_validate_wasm_file()) do
          :ok
        else
          {:error, :invalid_checksums} ->
            unquote(download_and_validate_wasm_file())

          error ->
            error
        end
      end
    end
  end

  defp download_and_validate_wasm_file() do
    quote do
      with :ok <- unquote(download_wasm_file()),
           :ok <- unquote(compare_binary_hash_with_checksums()) do
        :ok
      end
    end
  end

  defp compare_binary_hash_with_checksums do
    quote do
      with {:ok, checksums} <- unquote(remote_checksums()),
           {:ok, hash} <- unquote(local_checksums()) do
        if checksums == hash do
          Logger.info("numscript-wasm binary validated with checksums successfully.")

          :ok
        else
          Logger.error("Based on the checksums, the numscript-wasm binary is not valid.")

          {:error, :invalid_checksums}
        end
      end
    end
  end

  defp download_wasm_file do
    quote do
      Logger.info("Downloading numscript-wasm binary.")

      request =
        :httpc.request(
          :get,
          {unquote(@numscript_wasm_url), []},
          [],
          stream: unquote(@binary_path)
        )

      case request do
        {:ok, :saved_to_file} ->
          Logger.info("numscript-wasm binary downloaded.")

          :ok

        {:ok, {{_, status_code, detail}, _, _}} when status_code not in 200..299 ->
          Logger.error("Download request failed with status code #{status_code} #{detail}.")

          :error

        {:error, reason} ->
          Logger.error("Failed to download numscript-wasm binary. Reason: #{reason}.")

          :error
      end
    end
  end

  defp remote_checksums() do
    quote do
      Logger.info("Getting remote checksums.")

      case :httpc.request(:get, {unquote(@numscript_checksums_url), []}, [], []) do
        {:ok, {{_, status_code, detail}, _, _}} when status_code not in 200..299 ->
          Logger.error("Download request failed with status code #{status_code} #{detail}.")

          :error

        {:ok, {{_protocol, _status_code, _status_message}, _header, body}} ->
          Logger.info("numscript-wasm checsums downloaded.")
          [checksums, _file_name] = String.split(body)

          {:ok, checksums}

        {:error, reason} ->
          Logger.error("Failed to download numscript-wasm binary. Reason: #{reason}.")

          :error
      end
    end
  end

  defp local_checksums() do
    quote do
      try do
        hash =
          File.stream!("tmp/numscript.wasm", 2048)
          |> Enum.reduce(:crypto.hash_init(:sha256), fn line, acc ->
            :crypto.hash_update(acc, line)
          end)
          |> :crypto.hash_final()
          |> Base.encode16()
          |> String.downcase()

        {:ok, hash}
      rescue
        File.Error ->
          Logger.error("Could not stream numscript binary: no such file or directory.")

          :error
      end
    end
  end
end
