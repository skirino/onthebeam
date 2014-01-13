defmodule Onthebeam.Supervisor do
  use Supervisor.Behaviour

  def start_link do
    :supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = [
      worker(Onthebeam.CommandHandler, []),
    ]
    supervise(children, strategy: :one_for_one)
  end
end
