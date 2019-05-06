#!/usr/bin/env ruby

require "yaml"
require "digest"
require "dhash-vips"

if ARGV.length < 2
  puts "Usage: create-hashdb.rb <folder> <dbfile.yaml>"
  puts "If the db file already exists, it will only be updated."
  exit 1
end

if File.exist? ARGV[1] # rubocop:disable Style/ConditionalAssignment
  db = YAML.load(File.read(ARGV[1]))
else
  db = {}
end

# remove deleted files
db.each do |k,v|
  db.delete(k) unless File.exist? k
end

files = Dir[ARGV[0] + "/**/*"].find_all { |f| File.file? f }
files.each_with_index do |f,i|
  begin
    printf("%5d/%5d: %s\n", i + 1, files.length, f)

    next unless File.exist? f

    mtime = File.mtime(f).to_f
    path = File.expand_path(f)

    next unless db[path].nil? || db[path]["mtime"] != mtime

    db[path] = {
      "sha" => Digest::SHA2.hexdigest(File.read(f)),
      "mtime" => File.mtime(f).to_f
    }

    # algo still has problems with large videos files:
    # for these we need way too much RAM
    if f.end_with?(".jpg") || (File.size(f) < 7_000_000) # rubocop:disable Style/Next
      db[path]["dhash"] = DHashVips::DHash.calculate(f)
      db[path]["idhash"] = DHashVips::IDHash.fingerprint(f)
    end
  rescue => e
    puts e
  end
end

# write db
File.open(ARGV[1], 'w') { |f| f.write YAML.dump(db) }
