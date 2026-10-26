func hexJoin(_ bytes: [UInt8]) -> String {
    var result = ""
    for byte in bytes {
        result.append(String(byte, radix: 16))
        result += " "
    }
    return result
}
