defmodule Numscriptex do
  @supported_operations ~w(
    run
    check
  )a

  def check(input), do: process(input, :check)

  def run(numscript, input) do
    numscript
    |> build_run_data(input)
    |> process(:run)
  end

  def check_and_run(numscript, input) do
    with :ok <- process(numscript, :check),
    do: run(numscript, input)
  end

  defp build_run_data(numscript, input) do
    decoded_input = Jason.decode!(input)

    Map.new()
    |> Map.put(:script, numscript)
    |> Map.merge(decoded_input)
    |> Jason.encode!()
  end

  defp process(_input, operation) when operation not in @supported_operations,
  do: {:invalid_operation}

  defp process(input, _operation) when not is_binary(input),
  do: {:invalid_input}

  defp process(input, operation) do
    binary = File.read!("priv/numscript.wasm")

    {:ok, stdout_pipe} = Wasmex.Pipe.new()
    {:ok, stdin_pipe} = Wasmex.Pipe.new()

    Wasmex.Pipe.write(stdin_pipe, input)
    Wasmex.Pipe.seek(stdin_pipe, 0)

    wasi = %Wasmex.Wasi.WasiOptions{
      args: ["numscript.wasm", to_string(operation)],
      stdout: stdout_pipe,
      stdin: stdin_pipe
    }

    {:ok, pid} = Wasmex.start_link(%{bytes: binary, wasi: wasi})

    with {:ok, []} <- Wasmex.call_function(pid, :_start, []) do
      Wasmex.Pipe.seek(stdout_pipe, 0)

      stdout_pipe
      |> Wasmex.Pipe.read()
      |> Jason.decode!()
      |> handle_process()
    end
  end

  defp handle_process(%{"valid" => valid?}) when valid?, do: :ok

  defp handle_process(%{"valid" => valid?} = result) when not valid?,
  do: {:error, %{errors: result["errors"]}} 

  defp handle_process(result) when is_map(result),
  do: {:ok, result} 

  defp handle_process(result), do: result
end
