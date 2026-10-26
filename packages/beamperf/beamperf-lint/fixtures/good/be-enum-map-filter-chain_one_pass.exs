defmodule Good5 do
  def one_pass(xs) do
    Enum.reduce(xs, [], fn x, acc ->
      y = x * 2
      if y > 0, do: [y | acc], else: acc
    end)
    |> Enum.reverse()
  end

  def single_map(xs), do: Enum.map(xs, &(&1 * 2))
end
