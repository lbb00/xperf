def load_all(text, n)
  out = []
  n.times do
    out << JSON.parse(text)
  end
  out
end
