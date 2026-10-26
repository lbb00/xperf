func names(_ buf: UnsafeRawBufferPointer) -> [String] {
    var out: [String] = []
    out.reserveCapacity(1)
    for _ in 0..<1 {
        let ptr = buf.baseAddress!.assumingMemoryBound(to: CChar.self)
        out.append(String(cString: ptr))
    }
    return out
}
