defmodule Bad3 do
  def run(n) do
    for i <- 1..n do
      IO.puts(i)
    end
  end
end
