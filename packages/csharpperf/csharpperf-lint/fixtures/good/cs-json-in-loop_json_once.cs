using System.IO;
using System.Text.Json;
using Newtonsoft.Json;

class Good {
  public string Once(string row) {
    var a = JsonSerializer.Deserialize<Payload>(row);
    var text = JsonSerializer.Serialize(a);
    var c = JsonConvert.DeserializeObject<Payload>(text);
    var again = JsonConvert.SerializeObject(c);
    var n = 0;
    foreach (var ch in again) {
      JsonSerializer.SerializeAsync(Stream.Null, a);
      if (ch == '{') n++;
    }
    return text;
  }

  class Payload { public int Id { get; set; } }
}
