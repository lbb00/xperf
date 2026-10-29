defmodule Good3 do
  def run(n) do
    s = Enum.sum(1..n)
    IO.puts(s)
    s
  end
end
