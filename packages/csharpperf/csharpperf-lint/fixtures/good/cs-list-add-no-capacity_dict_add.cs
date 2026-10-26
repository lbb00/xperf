using System.Collections.Generic;
using System.Linq;
static class G {
  // Dictionary.Add must not be reported as List.Add (cs-list-add-no-capacity).
  static void Mark(IEnumerable<string> first) {
    var flags = new Dictionary<string, bool>();
    var keys = new List<string>(32);
    foreach (var item in first.Where(k => !flags.ContainsKey(k))) {
      flags.Add(item, true);
      keys.Add(item); // Capacity pre-sized via ctor
    }
  }
}
