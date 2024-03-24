defmodule SimpleChat.HistoryTracker do
  use GenServer

  # Starting the GenServer
  def start_link(_opts) do
    # Initialize state as an empty list for simplicity
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # GenServer callback implementations
  def init(_) do
    # Initialize state as an empty list to store history
    {:ok, []}
  end

  # This function handles calls to retrieve the history
  def handle_call(:get_history, _from, state) do
    # Return the history in reverse order for most recent first
    {:reply, Enum.reverse(state), state}
  end

  # This function handles casts to log a request
  def handle_cast({:log_request, request}, state) do
    # Log the request
    {:noreply, [{:request, request} | state]}
  end

  # This function handles casts to log a complete response
  def handle_cast({:log_response, response}, state) do
    # Log the complete response
    {:noreply, [{:response, response} | state]}
  end

  # Public API for logging and retrieving history

  # Function to log a request
  def log_request(request) do
    GenServer.cast(__MODULE__, {:log_request, request})
  end

  # Function to log a complete response
  def log_response(response) do
    GenServer.cast(__MODULE__, {:log_response, response})
  end

  # Function to retrieve the history
  def get_history do
    GenServer.call(__MODULE__, :get_history)
  end
end
