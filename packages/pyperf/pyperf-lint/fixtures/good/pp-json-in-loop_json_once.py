import json


def load_all(blob):
    rows = json.loads(blob)
    out = []
    for row in rows:
        out.append(row)
    return out
