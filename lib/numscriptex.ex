defmodule Numscriptex do
  alias Numscriptex.Balances

  @binary :numscriptex
          |> :code.priv_dir()
          |> Path.join("numscript.wasm")
          |> File.read!()

  @spec check(binary()) :: {:ok, map()} | {:error, map()}
  def check(input) do
    case process(input, :check) do
      {:ok, details} ->
        {:ok, %{script: input, details: details}}

      :ok ->
        {:ok, %{script: input}}

      error ->
        error
    end
  end

  @spec run(binary(), Numscriptex.Run.t()) :: {:ok, map()} | {:error, map()}
  def run(numscript, %Numscriptex.Run{} = run_struct) do
    initial_balance = Map.get(run_struct, :balances)

    run_struct
    |> Map.from_struct()
    |> Map.merge(%{script: numscript})
    |> Jason.encode!()
    |> process(:run)
    |> maybe_put_final_balance(initial_balance)
  end

  def run(_numscript, _run_struct), do: {:error, %{reason: :badarg}}

  defp maybe_put_final_balance({:ok, %{"postings" => postings} = result}, initial_balance) do
    balances = Balances.put(initial_balance, postings)

    {:ok, Map.put(result, "balances", balances)}
  end

  defp maybe_put_final_balance({:error, _reason} = error, _initial_balance),
    do: error

  defp process(input, _operation) when not is_binary(input),
    do: {:error, %{reason: :invalid_input}}

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

    with {:ok, []} <- Wasmex.call_function(pid, :_start, []) do
      GenServer.stop(pid)

      Wasmex.Pipe.seek(stderr_pipe, 0)
      error = Wasmex.Pipe.read(stderr_pipe)

      Wasmex.Pipe.seek(stdout_pipe, 0)

      stdout_pipe
      |> Wasmex.Pipe.read()
      |> Jason.decode()
      |> handle_process()
      |> maybe_put_stderr(error)
    else
      {:error, _reason} ->
        Wasmex.Pipe.seek(stderr_pipe, 0)
        error = Wasmex.Pipe.read(stderr_pipe)

        Wasmex.Pipe.seek(stdout_pipe, 0)
        stdout = Wasmex.Pipe.read(stdout_pipe)

        {:error, stdout}
        |> handle_process()
        |> maybe_put_stderr(error)
    end
  end

  defp maybe_put_stderr({:error, reason}, stderr) when is_map(reason) do
    is_stderr_empty? =
      stderr
      |> String.replace(" ", "")
      |> Kernel.==("")

    if is_stderr_empty?, do: {:error, reason}, else: {:error, Map.put(reason, :details, stderr)}
  end

  defp maybe_put_stderr({:error, reason}, stderr) do
    error = {:error, %{reason: reason}}

    maybe_put_stderr(error, stderr)
  end

  defp maybe_put_stderr(data, _stderr), do: data

  defp handle_process({:ok, %{"valid" => valid?} = result}) when is_boolean(valid?) and valid? do
    normalized_result = Map.delete(result, "valid")

    has_details? = not Enum.empty?(normalized_result)

    if has_details?, do: {:ok, normalized_result}, else: :ok
  end

  defp handle_process({:ok, %{"valid" => valid?, "errors" => _err} = result})
       when is_boolean(valid?) and not valid? do
    {:error, Map.delete(result, "valid")}
  end

  defp handle_process({:ok, %{"postings" => postings} = result}) do
    if Enum.empty?(postings),
      do: {:error, %{reason: :invalid_input}},
      else: {:ok, result}
  end

  defp handle_process({:ok, %{"errors" => _errors} = result}),
    do: {:error, Map.delete(result, "valid")}

  defp handle_process({:ok, {:error, reason}}), do: {:error, %{reason: reason}}
  defp handle_process({:error, reason}), do: {:error, %{reason: reason}}
  defp handle_process({:ok, _data} = result), do: result
end
