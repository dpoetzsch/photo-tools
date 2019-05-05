#!/usr/bin/env ruby

require "yaml"

if ARGV.length < 1
  puts "Usage: find-visual-duplicates.rb <dbfile.yaml> <dhash | idhash>"
  exit 1
end

ALGO = ARGV[1]

db = YAML.load(File.read(arg))

db.each do |k,v|
  db.delete(k) unless File.exists? k
end

db.to_a.each_with_index do |v, i|
  f = v[0]
  h = v[1][ALGO]

  dups = []

  (i+1).upto(db.length - 1).each do |j|
    h2 = db[j][1][ALGO]
    diff = false
    similar = DHashVips::DHash.hamming(h, h2) < 10 if ALGO == "dhash"
    similar = DHashVips::IDHash.distance(h, h2) < 15 if ALGO == "idhash"
    dups.push(db[j][0]) if similar
  end

  if dups.length > 0
    puts "Potential duplicates:"
    puts f
    puts dups
    puts
  end
end
