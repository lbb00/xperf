func bad(_ b: NSObject, _ n: Int) -> Int {
  var acc = 0
  for _ in 0..<n {
    acc = (b.value(forKey: "a") as? Int) ?? 0
  }
  return acc
}
