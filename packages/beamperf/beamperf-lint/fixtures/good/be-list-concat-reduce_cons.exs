defmodule Good do
  def grow(n), do: do_grow(n, [])
  defp do_grow(0, acc), do: Enum.reverse(acc)
  defp do_grow(n, acc), do: do_grow(n - 1, [n | acc])
end
