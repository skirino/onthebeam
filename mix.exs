defmodule Onthebeam.Mixfile do
  use Mix.Project

  def project do
    [
      app:     :onthebeam,
      version: "0.0.1",
      elixir:  ">= 0.12.0",
      deps:    deps,
    ]
  end

  def application do
    [
      applications: [:node_finder],
      mod:          { Onthebeam, [] },
    ]
  end

  defp deps do
    [
      { :node_finder, "~> 0.0.1", github: "skirino/node_finder" },
    ]
  end
end
