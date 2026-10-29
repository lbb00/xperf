# Array += / numeric count += must stay quiet for rb-string-plus-hot
load_path = []
config = { load_path: %w[a b] }
config.each do |setting, value|
  case setting
  when :load_path
    load_path += value
  end
end
enqueued_count = 0
jobs = [[1, 2], [3]]
jobs.each do |group|
  enqueued_count += group.size
end
