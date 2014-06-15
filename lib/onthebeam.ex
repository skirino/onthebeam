defmodule Onthebeam do
  use Application

  def start(_type, _args) do
    Onthebeam.Supervisor.start_link
  end
end
