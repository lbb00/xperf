-module(m01_cons).
-export([grow/1]).
grow(N) -> lists:reverse(grow(N, [])).
grow(0, Acc) -> Acc;
grow(N, Acc) -> grow(N - 1, [N | Acc]).
