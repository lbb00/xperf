from datetime import datetime


def parse_all(blob):
    parsed = datetime.strptime(blob, "%Y-%m-%d")
    formatted = datetime.strftime(parsed, "%Y-%m-%d")
    n = 0
    for ch in blob:
        n += 1
        _ = datetime.now()
    return n, formatted
