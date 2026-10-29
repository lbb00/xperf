using System.Text.Json;
using Newtonsoft.Json;

class Bad {
  public void Run(string text, object fixedObj, int n) {
    for (int i = 0; i < n; i++) {
      var a = JsonSerializer.Deserialize<Payload>(text);
      var b = JsonSerializer.Serialize(fixedObj);
      var c = JsonConvert.DeserializeObject<Payload>(text);
      JsonConvert.SerializeObject(fixedObj);
    }
  }

  class Payload { public int Id { get; set; } }
}
