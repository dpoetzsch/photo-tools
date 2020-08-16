#!/usr/bin/env ruby

require "yaml"

if ARGV.length < 2
  puts "Usage: mark-unequal.rb <dbfile.yaml> <duplicates-output.yaml> [--dry]"
  puts "Marks files to be unequal for later (visual) duplicate comparison."
  puts "This allows to manually reduce the number of false positives."
  puts "To use, clean up the ouput of a duplicate finder so only the "
  puts "false positives remain and pass this to mark-unequal.rb"
  puts "If --dry is passed, no changes will be written."
  exit 1
end

HASHDB = ARGV[0]
DUPS_FILE = ARGV[1]
DRY = ARGV.include? "--dry"

db = YAML.load(File.read(HASHDB))

dups = YAML.load(File.read(DUPS_FILE))

dups.each do |k, v|
  puts "Setting unequals of #{v[0]}..."

  v.combination(2).each do |e|
    e.sort!
    db[e[0]]["unequal_to"] ||= {}
    db[e[0]]["unequal_to"][e[1]] = { "mtime" => File.mtime(e[1]).to_f }
  end
end

unless DRY
  File.open(HASHDB, 'w') { |f| f.write YAML.dump(db) }
end
