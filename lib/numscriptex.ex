defmodule Numscriptex do
  @supported_operations ~w(
    run
    check
  )a

  # TODO:
  # Melhorar o retorno disso, já que mesmo com erro retorna uma tupla
  # com {:ok, result}
  def check(input), do: process(input, :check)

  # TODO:
  # Melhorar o retorno disso, já que mesmo com erro retorna uma tupla
  # com {:ok, result}
  def run(numscript, input) do
    numscript
    |> build_run_data(input)
    |> process(:run)
  end

  # TODO: 
  # Acho que da pra melhorar o nome dessa função
  defp build_run_data(numscript, input) do
    decoded_input = Jason.decode!(input)

    Map.new()
    |> Map.put(:script, numscript)
    |> Map.merge(decoded_input)
    |> Jason.encode!()
  end

  def process(_input, operation) when operation not in @supported_operations,
    do: {:invalid_operation}

  def process(input, _operation) when not is_binary(input),
    do: {:invalid_input}

  def process(input, operation) do
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
      |> Jason.decode()
    end
  end
end
