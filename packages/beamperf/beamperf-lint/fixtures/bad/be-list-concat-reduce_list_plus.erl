-module(be001_list_plus).
-export([grow/1]).
grow(N) -> grow(N, []).
grow(0, Acc) -> Acc;
grow(N, Acc) ->
    Acc2 = Acc ++ [N],
    grow(N - 1, Acc2).
