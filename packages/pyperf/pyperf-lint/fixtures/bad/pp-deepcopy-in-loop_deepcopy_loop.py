from copy import deepcopy


def snap(base, n):
    out = []
    for _ in range(n):
        out.append(deepcopy(base))
    return out
