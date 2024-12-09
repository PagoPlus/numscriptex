defmodule Numscriptex do
  alias Numscriptex.Balances

  @binary :numscriptex
  |> :code.priv_dir()
  |> Path.join("numscript.wasm")
  |> File.read!()

  @spec check(binary()) :: {:ok, map()} | {:error, map()}
  def check(input) do
    with :ok <- process(input, :check), do: {:ok, %{script: input}}
  end

  @spec run(binary(), Numscriptex.Run.t()) :: {:ok, term()} | {:error, map()}
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

  defp maybe_put_final_balance({:ok, %{"postings" => postings}}, initial_balance) do
    Balances.put(initial_balance, postings)
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
    end
  end

  defp maybe_put_stderr({:error, reason}, stderr) when is_map(reason) do
    is_stderr_empty? =
      stderr
      |> String.replace(" ", "")
      |> Kernel.==("")

    if is_stderr_empty?,
      do: {:error, reason}, 
      else: {:error, Map.put(reason, :details, stderr)}
  end

  defp maybe_put_stderr({:error, reason}, stderr) do
    error = {:error, %{reason: reason}}

    maybe_put_stderr(error, stderr)
  end

  defp maybe_put_stderr(data, _stderr), do: data

  defp handle_process({:ok, %{"valid" => valid?, "errors" => errors}}) 
    when is_boolean(valid?) and not valid? do
      {:error, %{errors: errors}}
  end

  defp handle_process({:ok, %{"postings" => postings} = result}) do
    if Enum.empty?(postings), 
      do: {:error, %{reason: :invalid_input}},
      else: {:ok, result}
  end

  defp handle_process({:ok, %{"valid" => valid?}}) when is_boolean(valid?) and valid?, do: :ok
  defp handle_process({:ok, %{"errors" => errors}}), do: {:error, %{errors: errors}}
  defp handle_process({:ok, {:error, reason}}), do: {:error, %{reason: reason}}
  defp handle_process({:error, reason}), do: {:error, %{reason: reason}}
  defp handle_process({:ok, _data} = result), do: result
end
