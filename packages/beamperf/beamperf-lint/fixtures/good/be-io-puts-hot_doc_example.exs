defmodule DocExample do
  @doc """
  Invokes fun for each element.

  ## Examples

      Enum.each(["some", "example"], fn x -> IO.puts(x) end)
      #=> :ok

  """
  def each(enum, fun), do: Enum.each(enum, fun)
end
