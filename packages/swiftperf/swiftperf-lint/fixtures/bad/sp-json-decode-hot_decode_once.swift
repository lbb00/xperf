struct Item {}

func decodeAll(_ blobs: [Data]) throws -> [Item] {
    let decoder = JSONDecoder()
    var out: [Item] = []
    out.reserveCapacity(blobs.count)
    for blob in blobs {
        let item = try decoder.decode(Item.self, from: blob)
        out.append(item)
    }
    return out
}

func once(_ blob: Data) throws -> Any {
    return try JSONSerialization.jsonObject(with: blob)
}
