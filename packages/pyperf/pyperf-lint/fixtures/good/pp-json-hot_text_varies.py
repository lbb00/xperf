import json


def load_all(rows):
    out = []
    for row in rows:
        out.append(json.loads(row))
    return out
