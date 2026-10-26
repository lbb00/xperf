import re


def match_all(lines):
    pat = re.compile(r"\d+")
    n = 0
    for line in lines:
        if pat.search(line):
            n += 1
    return n
