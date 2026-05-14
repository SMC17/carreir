defmodule CarrierSovereignDashboard.Listener do
  @moduledoc """
  Sovereign Listener for the Carrier AI Fleet.
  Ingests COBS-framed binary data from the Zig Silicon Nodes.
  """
  require Logger

  def start(port \\ 4000) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: 0, active: false, reuseaddr: true])
    Logger.info("Sovereign Listener active on port \#{port}. Awaiting Zig stream...")
    accept_loop(socket)
  end

  defp accept_loop(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    spawn(fn -> handle_client(client) end)
    accept_loop(socket)
  end

  defp handle_client(client) do
    case :gen_tcp.recv(client, 0) do
      {:ok, data} ->
        # In a full implementation, we would decode COBS and update LiveView state
        Logger.info("Received data from Sovereign Node: \#{inspect(data)}")
        handle_client(client)
      {:error, :closed} ->
        Logger.info("Sovereign Node disconnected.")
    end
  end
end

# To run: elixir -e 'CarrierSovereignDashboard.Listener.start()'
