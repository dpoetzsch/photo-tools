#!/usr/bin/env ruby

require "yaml"
require "digest"

if ARGV.length < 2
  puts "Usage: create-hashdb.rb <folder> <dbfile.yaml>"
  exit 1
end

db = {}

files = Dir[ARGV[0] + "/**/*"].find_all { |f| File.file? f }
files.each_with_index do |f,i|
  printf("%5d/%5d: %s\n", i+1, files.length, f)
  db[File.expand_path(f)] = Digest::SHA2.hexdigest(File.read(f)),
end

# write db
File.open(ARGV[1], 'w') { |f| f.write YAML.dump(db) }
