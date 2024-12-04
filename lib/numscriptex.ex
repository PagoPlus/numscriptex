defmodule Numscriptex do
  def check(input), do: process(input, :check)

  def run(numscript, input) do
    with {:ok, data} <- build_run_data(numscript, input),
    do: process(data, :run)
  end

  defp build_run_data(numscript, input) do
    with {:ok, decoded_input} <- Jason.decode(input) do
      Map.new()
      |> Map.put(:script, numscript)
      |> Map.merge(decoded_input)
      |> Jason.encode()
    end
  end

  defp process(input, _operation) when not is_binary(input),
  do: {:error, :invalid_input}

  defp process(input, operation) do
    binary = File.read!("priv/numscript.wasm")

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

    {:ok, pid} = Wasmex.start_link(%{bytes: binary, wasi: wasi})

    with {:ok, []} <- Wasmex.call_function(pid, :_start, []) do
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

  defp maybe_put_stderr({:error, reason}, stderr) do
    is_stderr_empty? =
      stderr
      |> String.replace(" ", "")
      |> Kernel.==("")

    if is_stderr_empty?,
      do: {:error, reason}, 
      else: {:error, reason, stderr}
  end

  defp maybe_put_stderr(data, _stderr), do: data

  defp handle_process({:ok, %{"valid" => valid?, "errors" => errors}}) 
    when is_boolean(valid?) and not valid? do
      {:error, %{errors: errors}}
  end

  defp handle_process({:ok, %{"postings" => postings} = result}) do
    if Enum.empty?(postings), 
      do: {:error, :invalid_input},
      else: {:ok, result}
  end

  defp handle_process({:ok, %{"valid" => valid?}}) when is_boolean(valid?) and valid?, do: :ok
  defp handle_process({:ok, %{"errors" => errors}}), do: {:error, %{errors: errors}}
  defp handle_process({:ok, {:error, reason}}), do: {:error, reason}
  defp handle_process({:error, reason}), do: {:error, reason}
  defp handle_process({:ok, _data} = result), do: result
end
