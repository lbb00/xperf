static int Good(string[] words) {
  int s = 0;
  foreach (var word in words) {
    var re = new Regex(word);
    if (re.IsMatch("id-2026")) s = 1;
  }
  return s;
}
