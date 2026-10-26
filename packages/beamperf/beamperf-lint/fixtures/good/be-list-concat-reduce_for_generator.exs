defmodule ForGen do
  def vars(args, result) do
    for type_expr <- args ++ [result],
        var <- [type_expr],
        uniq: true,
        do: var
  end
end
