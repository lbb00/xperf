using System.Text.Json;
using Newtonsoft.Json;

class Good {
  public void Run(string[] rows) {
    foreach (var row in rows) {
      JsonSerializer.Deserialize<Payload>(row);
      JsonSerializer.Serialize(row);
      JsonConvert.DeserializeObject<Payload>(row);
      JsonConvert.SerializeObject(row);
    }
  }

  class Payload { public int Id { get; set; } }
}
