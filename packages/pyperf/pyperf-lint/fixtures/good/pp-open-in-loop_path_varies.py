def good(files):
    total = 0
    for i in range(len(files)):
        with open(files[i]) as handle:
            total += len(handle.read())
    return total
