#!/usr/bin/env ruby

require "yaml"
require "digest"
require "dhash-vips"

if ARGV.length < 2
  puts "Usage: create-hashdb.rb <dbfile.yaml> [--dry] [--clean] <folder>*"
  puts "If the db file already exists, it will only be updated."
  puts "If --clean flag is given, it will remove deleted files from db."
  puts "If --dry is passed no changes will be written."
  exit 1
end

HASHDB = ARGV[0]

if File.exist? HASHDB # rubocop:disable Style/ConditionalAssignment
  db = YAML.load(File.read(HASHDB))
else
  db = {}
end

args = []
files = []
nomoreargs = false
ARGV[1..-1].each do |a|
  if nomoreargs || !a.start_with?("--")
    files.push a
  elsif a == "--"
    nomoreargs = true
  else
    args.push a
  end
end

# remove deleted files
if args.include? "--clean"
  db.each do |k,v|
    next if File.exist? k

    puts "Cleaning: #{k}"
    db.delete(k)
  end
end

files = files.map { |a| Dir[a + "/**/*"] }
  .flatten
  .find_all { |f| File.file? f }
  .sort

files.each_with_index do |f, i|
  begin
    printf("%5d/%5d: %s\n", i + 1, files.length, f)

    next unless File.exist? f

    mtime = File.mtime(f).to_f
    path = File.realpath(File.expand_path(f))

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
unless args.include? "--dry"
  File.open(HASHDB, 'w') { |f| f.write YAML.dump(db) }
end
