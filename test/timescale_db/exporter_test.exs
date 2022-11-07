defmodule TimescaleDB.ExporterTest do
  use ExUnit.Case
  doctest TimescaleDB.Exporter

  test "greets the world" do
    assert TimescaleDB.Exporter.hello() == :world
  end
end
