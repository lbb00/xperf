def count_lines(tokens):
    lineno = 1
    for tok in tokens:
        lineno += tok.count("\n")
    return lineno
