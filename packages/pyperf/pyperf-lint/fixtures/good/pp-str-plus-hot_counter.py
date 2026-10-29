def advance(chunks):
    pos = 0
    for c in chunks:
        pos += len(c)
    return pos
