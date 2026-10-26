from copy import deepcopy


def snap(base, n):
    prototype = deepcopy(base)
    out = []
    for _ in range(n):
        out.append(prototype)
    return out
