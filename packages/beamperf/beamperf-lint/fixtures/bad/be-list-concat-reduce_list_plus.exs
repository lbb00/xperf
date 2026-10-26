defmodule Bad do
  def grow(n) do
    Enum.reduce(1..n, [], fn i, acc ->
      acc ++ [i]
    end)
  end
end
