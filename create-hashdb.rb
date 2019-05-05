#!/usr/bin/env ruby

require "yaml"
require "digest"
require "dhash-vips"

if ARGV.length < 2
  puts "Usage: create-hashdb.rb <folder> <dbfile.yaml>"
  puts "If the db file already exists, it will only be updated."
  exit 1
end

if File.exists? ARGV[1]
  db = YAML.load(File.read(ARGV[1]))
else
  db = {}
end

files = Dir[ARGV[0] + "/**/*"].find_all { |f| File.file? f }
files.each_with_index do |f,i|
  printf("%5d/%5d: %s\n", i+1, files.length, f)

  mtime = File.mtime(f).to_f
  path = File.expand_path(f)
  if db[path].nil? || db[path]["mtime"] != mtime
    db[path] = {
      "sha" => Digest::SHA2.hexdigest(File.read(f)),
      "dhash" => DHashVips::DHash.calculate(f),
      "idhash" => DHashVips::IDHash.fingerprint(f),
      "mtime" => File.mtime(f).to_f
    }
  end
end

# write db
File.open(ARGV[1], 'w') { |f| f.write YAML.dump(db) }
