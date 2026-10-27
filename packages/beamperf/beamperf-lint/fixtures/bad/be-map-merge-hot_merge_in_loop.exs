defmodule Bad4 do
  def merge_all(maps) do
    Enum.reduce(maps, %{}, fn m, acc ->
      Map.merge(acc, m)
    end)
  end

  def kw(maps) do
    Enum.reduce(maps, [], fn m, acc ->
      Keyword.merge(acc, m)
    end)
  end
end
