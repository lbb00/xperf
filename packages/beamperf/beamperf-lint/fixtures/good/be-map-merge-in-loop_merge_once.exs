defmodule Good4 do
  def merge_once(a, b), do: Map.merge(a, b)

  def put_in_loop(maps) do
    Enum.reduce(maps, %{}, fn %{k: k, v: v}, acc ->
      Map.put(acc, k, v)
    end)
  end
end
