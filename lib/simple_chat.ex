defmodule SimpleChat do
  require HTTPoison
  alias SimpleChat.HttpStream
  alias SimpleChat.HistoryTracker

  @timeout 5000

  def start() do
    # Start the GenServer
    {:ok, _pid} = HistoryTracker.start_link([])

    loop()
  end

  defp loop() do
    prompt = IO.gets("\nEnter a prompt:\n") |> String.trim()

    case prompt do
      "exit" ->
        IO.puts("Exiting...")
        IO.puts("Chat History:")
        HistoryTracker.get_history() |> IO.inspect()
        GenServer.stop(SimpleChat.HistoryTracker, :normal, @timeout)
        :ok

      _input ->
        HttpStream.post(prompt)
        IO.puts("\n")
        loop()
    end
  end
end
