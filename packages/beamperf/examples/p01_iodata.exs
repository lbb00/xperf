parts = Enum.map(1..8, &Integer.to_string/1)
IO.puts(IO.iodata_to_binary(parts))
