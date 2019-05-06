#!/usr/bin/env ruby

require "yaml"
require "digest"
require "dhash-vips"

if ARGV.length < 2
  puts "Usage: create-hashdb.rb <dbfile.yaml> <folder>*"
  puts "If the db file already exists, it will only be updated."
  exit 1
end

HASHDB = ARGV[0]

if File.exist? HASHDB # rubocop:disable Style/ConditionalAssignment
  db = YAML.load(File.read(HASHDB))
else
  db = {}
end

# remove deleted files
db.each do |k,v|
  db.delete(k) unless File.exist? k
end

files = ARGV[1..-1].map { |a| Dir[a + "/**/*"] }
  .flatten
  .find_all { |f| File.file? f }
  .sort

files.each_with_index do |f, i|
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
File.open(HASHDB, 'w') { |f| f.write YAML.dump(db) }
