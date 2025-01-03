defmodule Numscriptex.CompilationSettings do
  @file_version Application.compile_env(:numscriptex, :file_version, "0.23.4")
  @url "https://github.com/yarnpkg/yarn/releases/download/v#{@file_version}/yarn-v#{@file_version}.tar.gz"
  @download_path System.tmp_dir()
             |> Path.join("yarn-v#{@file_version}.tar.gz")
             |> String.to_charlist()

  defmacro ensure_wasm_file_exists do
    quote do
      file_path = 
        :numscriptex
        |> :code.priv_dir()
        |> Path.join("dist")

      if File.exists?(file_path) do
        Logger.info("WASM file already exists.")
      else
        Logger.info("Downloading numscript-wasm.tar.gz")
        unquote(download_wasm_file())
        Logger.info("numscript-wasm.tar.gz downloaded")

        Logger.info("Extracting numscript-wasm.tar.gz")
        :erl_tar.extract(unquote(@download_path), [{:cwd, "priv"}, :compressed])
        Logger.info("File successfully extracted on priv directory.")
      end
    end
  end

  defp download_wasm_file do
    quote do
      :inets.start()
      :ssl.start()

      download_path = unquote(@download_path)

      request_opts = [
        ssl: [
          cacerts: :public_key.cacerts_get(),
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ]
        ]
      ]

      {:ok, :saved_to_file} =
        :httpc.request(:get, {unquote(@url), []}, request_opts, [stream: download_path])
    end
  end
end
