defmodule Numscriptex do
  @moduledoc """
  NumscriptEx is a library that allows its users to check and run [numscripts](https://docs.formance.com/numscript/)
  via Elixir.

  Want to check if your script is valid and ready to go? Use the `check/1` function.
  Already checked the script and want to execute him? Use the `run/2` function.
  """

  alias Numscriptex.Balances
  alias Numscriptex.CheckLog
  alias Numscriptex.Utilities

  @type check_log() :: CheckLog.t()

  @type check_result() :: %{
          required(:script) => binary(),
          optional(:hints) => list(check_log()),
          optional(:infos) => list(check_log()),
          optional(:warnings) => list(check_log())
        }

  @type run_result() :: %{
          required(:balances) => balances(),
          required(:postings) => postings(),
          required(:accountsMeta) => map(),
          required(:txMeta) => map()
        }

  @type balances() :: %{
          required(:initial_balance) => integer(),
          required(:final_balance) => integer(),
          required(:asset) => binary(),
          required(:account) => binary()
        }

  @type postings() :: %{
          required(:destination) => binary(),
          required(:source) => binary(),
          required(:asset) => binary(),
          required(:amount) => integer()
        }

  @type errors() :: %{
          required(:reason) => list(check_log()) | any(),
          optional(:details) => any()
        }

  @binary :numscriptex
          |> :code.priv_dir()
          |> Path.join("numscript.wasm")
          |> File.read!()

  @doc """
  To use `check/1` you just need to pass your numscript as its argument.
  Ex:

  ```elixir
  iex> script = "send [USD/2 100] ( source = @foo destination = @bar)"
  iex> Numscriptex.check(script)
  {:ok, %{script: script}}
  ```

  It could also return some warnings, infos or hints inside the map
  """
  @spec check(binary()) :: {:ok, check_result()} | {:error, errors()}
  def check(input) do
    case process(input, :check) do
      {:ok, details} ->
        {:ok, %{script: input, details: normalize_check_logs(details)}}

      :ok ->
        {:ok, %{script: input}}

      {:error, %{reason: errors}} ->
        {:error, %{reason: normalize_check_logs(errors)}}
    end
  end

  @doc """
  To use `run/2` your first argument must be your script, and the second must
  be a `%Numscriptex.Run{}` (go to Numscriptex.Run module to see more) struct.
  Ex:
   
  ```elixir
  iex> script = "send [USD/2 100] ( source = @foo destination = @bar)"
  ...> balances = %{"foo" => %{"USD/2" => 500, "EUR/2" => 300}}
  ...> 
  ...> struct = 
  ...> Numscriptex.Run.new()
  ...> |> Numscriptex.Run.put!(:balances, balances)
  ...> |> Numscriptex.Run.put!(:metadata, %{})
  ...> |> Numscriptex.Run.put!(:variables, %{})
  ...>
  ...> Numscriptex.run(script, struct)
  ```
  """
  @spec run(binary(), Numscriptex.Run.t()) :: {:ok, run_result()} | {:error, errors()}
  def run(numscript, %Numscriptex.Run{} = run_struct) do
    initial_balance = Map.get(run_struct, :balances)

    run_struct
    |> Map.from_struct()
    |> Map.merge(%{script: numscript})
    |> JSON.encode!()
    |> process(:run)
    |> maybe_put_final_balance(initial_balance)
    |> standardize_run_result()
  end

  def run(_numscript, _run_struct), do: {:error, %{reason: :badarg}}

  defp standardize_run_result({:ok, result}) do
    standardized_result =
      result
      |> Map.put_new(:accountsMeta, %{})
      |> Map.put_new(:txMeta, %{})

    {:ok, standardized_result}
  end

  defp standardize_run_result({:error, _reason} = errors), do: errors

  defp maybe_put_final_balance({:ok, %{"postings" => postings} = result}, initial_balance) do
    balances = Balances.put(initial_balance, postings)

    normalized_result =
      result
      |> Map.put("balances", balances)
      |> Utilities.normalize_keys(:atom)

    {:ok, normalized_result}
  end

  defp maybe_put_final_balance({:error, _reason} = error, _initial_balance),
    do: error

  defp process(input, operation) do
    {:ok, stdout_pipe} = Wasmex.Pipe.new()
    {:ok, stdin_pipe} = Wasmex.Pipe.new()
    {:ok, stderr_pipe} = Wasmex.Pipe.new()

    Wasmex.Pipe.write(stdin_pipe, input)
    Wasmex.Pipe.seek(stdin_pipe, 0)

    wasi = %Wasmex.Wasi.WasiOptions{
      args: ["numscript.wasm", to_string(operation)],
      stdout: stdout_pipe,
      stdin: stdin_pipe,
      stderr: stderr_pipe
    }

    {:ok, pid} = Wasmex.start_link(%{bytes: @binary, wasi: wasi})

    case Wasmex.call_function(pid, :_start, []) do
      {:ok, []} ->
        GenServer.stop(pid)

        Wasmex.Pipe.seek(stderr_pipe, 0)
        error = Wasmex.Pipe.read(stderr_pipe)

        Wasmex.Pipe.seek(stdout_pipe, 0)

        stdout_pipe
        |> Wasmex.Pipe.read()
        |> JSON.decode()
        |> handle_process()
        |> maybe_put_stderr(error)
        |> handle_errors()

      {:error, _reason} ->
        GenServer.stop(pid)

        Wasmex.Pipe.seek(stderr_pipe, 0)
        error = Wasmex.Pipe.read(stderr_pipe)

        Wasmex.Pipe.seek(stdout_pipe, 0)
        stdout = Wasmex.Pipe.read(stdout_pipe)

        {:error, stdout}
        |> handle_process()
        |> maybe_put_stderr(error)
        |> handle_errors()
    end
  end

  defp maybe_put_stderr({:error, reason}, stderr) when is_map(reason) do
    is_stderr_empty? =
      stderr
      |> String.replace(" ", "")
      |> Kernel.==("")

    if is_stderr_empty?, do: {:error, reason}, else: {:error, Map.put(reason, :details, stderr)}
  end

  defp maybe_put_stderr(data, _stderr), do: data

  defp handle_process({:ok, %{"valid" => valid?} = result}) when is_boolean(valid?) and valid? do
    normalized_result = Map.delete(result, "valid")

    has_details? = not Enum.empty?(normalized_result)

    if has_details?, do: {:ok, normalized_result}, else: :ok
  end

  defp handle_process({:ok, %{"valid" => valid?, "errors" => _err} = result})
       when is_boolean(valid?) and not valid? do
    {:error, %{reason: Map.delete(result, "valid")}}
  end

  defp handle_process({:ok, %{"postings" => postings} = result}) do
    if Enum.empty?(postings),
      do: {:error, %{reason: :invalid_input}},
      else: {:ok, result}
  end

  defp handle_process({:error, reason}), do: {:error, %{reason: reason}}
  defp handle_process({:ok, _data} = result), do: result

  defp handle_errors({:ok, _} = result), do: result

  defp handle_errors(:ok), do: :ok

  defp handle_errors({:error, %{reason: reason, details: details}}) do
    {:error, %{reason: normalize_error(reason), details: normalize_error(details)}}
  end

  defp handle_errors({:error, %{reason: reason}}) do
    {:error, %{reason: normalize_error(reason)}}
  end

  defp normalize_error(error) when is_binary(error) do
    error
    |> String.replace("panic:", "")
    |> String.trim()
  end

  defp normalize_error(error), do: error

  defp normalize_check_logs(logs) do
    logs
    |> Utilities.normalize_keys(:atom)
    |> check_log_level_to_atom()
    |> check_logs_to_struct()
    |> Enum.into(%{})
  end

  defp check_logs_to_struct(logs) do
    Enum.map(logs, fn {key, value} ->
      {key, Enum.map(value, &CheckLog.from_map/1)}
    end)
  end

  defp check_log_level_to_atom(check_logs) do
    Enum.flat_map(check_logs, fn {key, logs} ->
      normalized_level_field =
        Enum.map(logs, fn log ->
          Map.update(log, :level, nil, &String.to_existing_atom/1)
        end)

      Map.replace(check_logs, key, normalized_level_field)
    end)
  end
end
