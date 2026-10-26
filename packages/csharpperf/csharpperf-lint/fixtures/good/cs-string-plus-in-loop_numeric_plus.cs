using System.Collections.Generic;
static class G {
  static int Cap(List<int> positions) {
    int capacity = 0;
    for (int i = 0; i < positions.Count; i++) {
      capacity += positions[i];
    }
    return capacity;
  }
  static int Hash(string key) {
    int hashCode = key.Length;
    for (int i = 0; i < key.Length; i++) {
      hashCode += (hashCode << 7) ^ key[i];
    }
    return hashCode;
  }
}
