defmodule Numscriptex.CompilationSettings do
  @moduledoc """
  `Numscriptex.CompilationSettings` is responsible for ensuring that the Numscriptex
  library have all that it needs to run correctly at compile time.
  """
  require Logger

  @numscript_checksums_url "https://github.com/PagoPlus/numscript-wasm/releases/download/v0.0.2/numscript_checksums.txt"
  @numscript_wasm_url "https://github.com/PagoPlus/numscript-wasm/releases/download/v0.0.2/numscript.wasm"
  @binary_path :numscriptex
               |> :code.priv_dir()
               |> Path.join("numscript.wasm")
               |> to_charlist()

  defmacro ensure_wasm_binary_is_installed_and_valid do
    quote do
      if File.exists?(unquote(@binary_path)) do
        Logger.info("Numscript-WASM binary already exists, validating with checksums.")

        unquote(compare_binary_hash_with_checksums())
      else
        case unquote(download_and_validate_wasm_file()) do
          {:error, :invalid_checksums} ->
            unquote(download_and_validate_wasm_file())

          result ->
            result
        end
      end
    end
  end

  defp download_and_validate_wasm_file do
    quote do
      with :ok <- unquote(download_wasm_file()) do
        unquote(compare_binary_hash_with_checksums())
      end
    end
  end

  defp compare_binary_hash_with_checksums do
    quote do
      with {:ok, checksums} <- unquote(remote_checksums()),
           {:ok, hash} <- unquote(local_checksums()) do
        if checksums == hash do
          Logger.info("Numscript-WASM binary validated with checksums successfully.")

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
      Logger.info("Downloading Numscript-WASM binary.")

      request =
        :httpc.request(
          :get,
          {unquote(@numscript_wasm_url), []},
          [],
          stream: unquote(@binary_path)
        )

      case request do
        {:ok, :saved_to_file} ->
          Logger.info("Numscript-WASM binary downloaded.")

          :ok

        {:ok, {{_, status_code, status_message}, _, _}} when status_code not in 200..299 ->
          Logger.error(
            "Download request failed with status code #{status_code} - #{status_message}."
          )

          :error

        {:error, reason} ->
          Logger.error("Failed to download Numscript-WASM binary. Reason: #{inspect(reason)}.")

          :error
      end
    end
  end

  defp remote_checksums do
    quote do
      Logger.info("Getting remote checksums.")

      case :httpc.request(:get, {unquote(@numscript_checksums_url), []}, [], []) do
        {:ok, {{_, status_code, detail}, _, _}} when status_code not in 200..299 ->
          Logger.error("Download request failed with status code #{status_code} #{detail}.")

          :error

        {:ok, {{_protocol, _status_code, _status_message}, _header, body}} ->
          Logger.info("Numscript-WASM checksums downloaded.")

          [checksums, _file_name] =
            body
            |> to_string()
            |> String.split()

          {:ok, String.trim(checksums)}

        {:error, reason} ->
          Logger.error("Failed to download Numscript-WASM binary. Reason: #{reason}.")

          :error
      end
    end
  end

  defp local_checksums do
    quote do
      try do
        hash =
          File.stream!(unquote(@binary_path), 2048)
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
