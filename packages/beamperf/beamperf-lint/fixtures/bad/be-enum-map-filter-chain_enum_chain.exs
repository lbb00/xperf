defmodule Bad5 do
  def hot(xs) do
    xs |> Enum.map(&(&1 * 2)) |> Enum.filter(&(&1 > 0))
  end

  def hot2(xs) do
    Enum.map(xs, &(&1 + 1)) |> Enum.reject(&(&1 == 0))
  end
end
