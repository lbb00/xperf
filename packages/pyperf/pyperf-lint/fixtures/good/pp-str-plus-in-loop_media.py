class Media:
    def __add__(self, other):
        return self

def collect(widgets):
    media = Media()
    for w in widgets:
        media += w.media
    return media
