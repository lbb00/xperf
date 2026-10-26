import re


def match_all(lines):
    n = 0
    for line in lines:
        pat = re.compile(r"\d+")
        if pat.search(line):
            n += 1
    return n
