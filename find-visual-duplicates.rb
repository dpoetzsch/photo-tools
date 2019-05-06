#!/usr/bin/env ruby

require "yaml"
require "dhash-vips"
require "fileutils"

if ARGV.length < 2
  puts "Usage: find-visual-duplicates.rb <dbfile.yaml> <dhash | idhash> [prepare]"
  exit 1
end

ALGO = ARGV[1]

db = YAML.load(File.read(ARGV[0]))

db.each do |k,v|
  db.delete(k) unless File.exists? k
end

db = db.to_a

Dir.mkdir("/tmp/duplicates") if ARGV[2] == "prepare"

db.each_with_index do |v, i|
  f = v[0]
  h = v[1][ALGO]

  next if h.nil?

  dups = []

  (i+1).upto(db.length - 1).each do |j|
    h2 = db[j][1][ALGO]
    next if h2.nil?

    diff = false
    similar = DHashVips::DHash.hamming(h, h2) < 1 if ALGO == "dhash"
    similar = DHashVips::IDHash.distance(h, h2) < 15 if ALGO == "idhash"
    dups.push(db[j][0]) if similar
  end

  if dups.length > 0
    puts "Duplicates:"
    puts f
    puts dups
    puts

    if ARGV[2] == "prepare"
      Dir.mkdir "/tmp/duplicates/#{i}"
      FileUtils.cp(f, "/tmp/duplicates/#{i}/")
      dups.each do |d|
        FileUtils.cp(d, "/tmp/duplicates/#{i}/")
      end
    end
  end
end
