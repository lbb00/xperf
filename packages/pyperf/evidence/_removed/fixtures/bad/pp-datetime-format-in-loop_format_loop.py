from datetime import datetime


def parse_all(rows):
    out = []
    for row in rows:
        out.append(datetime.strptime(row, "%Y-%m-%d"))
        out.append(datetime.strftime(datetime.now(), "%Y-%m-%d"))
    return out
