defmodule SimpleChat.HttpStream do
  alias SimpleChat.HistoryTracker

  @model "wizard-vicuna-uncensored"
  # @model "mistral"
  # @model "llama2-uncensored"

  # url for locally running Ollama
  @url "http://localhost:11434/api/chat"

  def post(prompt) do

    message = %{
      "role" => "user",
      "content" => prompt
    }

    HistoryTracker.log_request(message)

    headers = headers()
    body = body()

    # IO.puts("URL: #{@url}")
    # IO.puts("HEADERS: #{inspect(headers)}")

    Stream.resource(
      fn -> HTTPoison.post!(@url, body, headers, stream_to: self(), async: :once) end ,
      fn resp ->
        case handle_async_response(resp) do
          :done ->
            {:halt, []}

          chunk when is_binary(chunk) ->
            {[chunk], resp}

          _ ->
            {[], resp}
        end
      end,
      fn _ -> :ok end
    )
    |> Enum.to_list()
    |> Enum.join()
    |> (fn concatenated_content -> %{"content" => concatenated_content} end).()
    # |> HistoryTracker.log_response()

    :ok
  end

  defp handle_async_response({:done, _resp}) do
    :done
  end

  defp handle_async_response(%HTTPoison.AsyncResponse{id: id} = resp, acc \\ "") do
    receive do
      %HTTPoison.AsyncStatus{id: ^id, code: _code} ->
        # IO.puts("Received status for #{inspect(id)}: #{_code}")
        HTTPoison.stream_next(resp)
        handle_async_response(resp, acc)

      %HTTPoison.AsyncHeaders{id: ^id, headers: _headers} ->
        # IO.puts("Received headers for #{inspect(id)}")
        HTTPoison.stream_next(resp)
        handle_async_response(resp, acc)

      %HTTPoison.AsyncChunk{id: ^id, chunk: chunk} ->
        # IO.puts("Received chunk for #{inspect(id)}")
        HTTPoison.stream_next(resp)
        case Jason.decode(chunk) do
          {:ok, %{"message" => %{"content" => content}}} when is_binary(content) ->
            IO.write(content)
            new_acc = acc <> content
            handle_async_response(resp, new_acc)

          _ ->
            handle_async_response(resp, acc)
        end

      %HTTPoison.AsyncEnd{id: ^id} ->
        # IO.puts("Received end for #{inspect(id)}")
        HistoryTracker.log_response(%{"content" => acc, "role" => "assistant"})
        :done
    after
      5_000 ->
        IO.puts("Timeout while waiting for more chunks for #{inspect(id)}")
        HistoryTracker.log_response(%{"content" => acc})
        :timeout
    end
  end

  defp headers() do
    [
      Accept: "application/json",
      "Content-Type": "application/json"
    ]
  end

  defp body() do
    messages = Enum.map(HistoryTracker.get_history(), fn {_type, data} -> data end)

    body = Jason.encode!(%{
      "model" => @model,
      "stream" => true,
      "messages" => messages
    })

    # IO.puts("BODY: #{body}")

    body
  end
end
