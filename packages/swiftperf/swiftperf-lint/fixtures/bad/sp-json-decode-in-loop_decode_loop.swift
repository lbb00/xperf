struct Item {}

func decodeAll(_ blobs: [Data]) throws -> [Item] {
    var out: [Item] = []
    out.reserveCapacity(blobs.count)
    for blob in blobs {
        let item = try JSONDecoder().decode(Item.self, from: blob)
        out.append(item)
    }
    return out
}

func objects(_ blobs: [Data]) throws -> [Any] {
    var out: [Any] = []
    out.reserveCapacity(blobs.count)
    for blob in blobs {
        let obj = try JSONSerialization.jsonObject(with: blob)
        out.append(obj)
    }
    return out
}
