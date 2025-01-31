defmodule Numscriptex.AssetsManager do
  @moduledoc """
  `Numscriptex.AssetsManager` is responsible for ensuring that the Numscriptex
  library have all it needs (i.e. a WASM binary file that is used to check and run Numscripts)
  to run correctly at compile time.
  """

  Module.register_attribute(__MODULE__, :numscript_wasm_version, persist: true)
  @numscript_wasm_version Application.compile_env(:numscriptex, :version, "0.0.2")
  @retries Application.compile_env(:numscriptex, :retries, 3)
  @numscript_checksums_url "https://github.com/PagoPlus/numscript-wasm/releases/download/v#{@numscript_wasm_version}/numscript_checksums.txt"
  @numscript_wasm_url "https://github.com/PagoPlus/numscript-wasm/releases/download/v#{@numscript_wasm_version}/numscript.wasm"
  @binary_path :numscriptex
               |> :code.priv_dir()
               |> Path.join("numscript.wasm")
               |> to_charlist()

  defmacro ensure_wasm_binary_is_valid do
    quote do
      require Logger

      File.mkdir_p!(:code.priv_dir(:numscriptex))

      if File.exists?(unquote(@binary_path)) do
        unquote(maybe_retry_download(compare_checksums()))
      else
        unquote(maybe_retry_download(download_and_compare_binary()))
      end
    end
  end

  def binary_path, do: @binary_path

  def hash_wasm_binary do
    # Logic explanation:
    #   1. Opens the wasm binary as a stream and split it by chunks of 1024 bytes and then iterate
    #      the chunks with `Enum.reduce/3`;
    #   2. The reduce takes a `:crypto.hash_init/1` state as it's argument, then update the state
    #      with each line hash using `:crypto.hash_update/2`;
    #   2.1. The `:crypto.hash_init/1` is using the sha256 hash algorithm because it's the same as the checksums,
    #        so if the algorithm on the checksums changed, you'll need to change here too.
    #   3. Uses `:crypto.hash_final/1` to finalize the streaming hash calculation;
    #   4. Encode the hash to the hexadecimal base (also the same as the checksums).
    quote do
      File.stream!(unquote(@binary_path), 1024)
      |> Enum.reduce(:crypto.hash_init(:sha256), fn line, acc ->
        :crypto.hash_update(acc, line)
      end)
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)
    end
  end

  defp maybe_retry_download(result) do
    quote do
      case unquote(result) do
        {:error, :invalid_checksums} ->
          unquote(retry_numscript_wasm_download())

        result ->
          result
      end
    end
  end

  defp download_and_compare_binary do
    quote do
      with :ok <- unquote(download_wasm_file()) do
        unquote(compare_checksums())
      end
    end
  end

  defp retry_numscript_wasm_download do
    quote do
      retries = unquote(@retries)

      cond do
        retries <= 0 ->
          :ok

        retries == 1 ->
          unquote(download_and_compare_binary())

        retries > 1 ->
          unquote(retry_download_reduce())
      end
    end
  end

  defp retry_download_reduce do
    quote do
      Enum.reduce_while(1..retries, :try_again, fn retry, prev_result ->
        if prev_result != :ok do
          {:cont, unquote(download_and_compare_binary())}
        else
          {:halt, prev_result}
        end
      end)
    end
  end

  defp compare_checksums do
    quote do
      with {:ok, checksums} <- unquote(remote_checksums()),
           hash <- unquote(hash_wasm_binary()) do
        if checksums == hash do
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
      unquote(maybe_delete_wasm_binary())

      request =
        :httpc.request(
          :get,
          {unquote(@numscript_wasm_url), []},
          [],
          stream: unquote(@binary_path)
        )

      case request do
        {:ok, :saved_to_file} ->
          :ok

        {:ok, {{_, status_code, status_message}, _, _}} when status_code not in 200..299 ->
          Logger.error("Download request failed (#{status_code}): #{status_message}.")

          raise CompileError

        {:error, reason} ->
          Logger.error(
            "Failed to download Numscript-WASM binary. Reason: #{inspect(reason)}. Binary path: #{unquote(@binary_path)}"
          )

          raise CompileError
      end
    end
  end

  defp maybe_delete_wasm_binary do
    quote do
      case File.rm(unquote(@binary_path)) do
        :ok ->
          :ok

        {:error, :enoent} ->
          :ok

        {:error, reason} ->
          raise File.Error, reason: reason
      end
    end
  end

  defp remote_checksums do
    quote do
      case :httpc.request(:get, {unquote(@numscript_checksums_url), []}, [], []) do
        {:ok, {{_, status_code, status_message}, _, _}} when status_code not in 200..299 ->
          Logger.error("Download request failed (#{status_code}): #{status_message}.")

          raise CompileError

        {:ok, {{_protocol, _status_code, _status_message}, _header, body}} ->
          [checksums, _file_name] =
            body
            |> to_string()
            |> String.split()

          {:ok, String.trim(checksums)}

        {:error, reason} ->
          Logger.error(
            "Failed to download Numscript-WASM checksums from release assets. Reason: #{reason}."
          )

          raise CompileError
      end
    end
  end
end
