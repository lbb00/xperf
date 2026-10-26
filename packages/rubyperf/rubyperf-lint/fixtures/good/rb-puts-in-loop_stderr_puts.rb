# $stderr.puts / CLI status tables are intentional
configs = %w[local remote]
configs.each do |db|
  $stderr.puts "skip #{db}" unless db == "local"
end
