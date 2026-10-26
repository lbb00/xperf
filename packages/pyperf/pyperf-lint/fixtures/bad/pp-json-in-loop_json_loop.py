import json


def load_all(text, n):
    out = []
    for _ in range(n):
        out.append(json.loads(text))
    return out
