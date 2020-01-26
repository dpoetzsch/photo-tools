#!/usr/bin/env ruby

require "yaml"
require "dhash-vips"
require "fileutils"

db = {}

i = 0
while i < ARGV.length && ARGV[i] != "dhash" && ARGV[i] != "idheash"
  db = db.merge(YAML.load(File.read(ARGV[i])))
  i += 1
end

if i == ARGV.length
  puts "Usage: find-visual-duplicates.rb <dbfile.yaml>* <dhash | idhash> [prepare]"
  puts "dhash tends to give quite reasonable results with only a slight overestimation."
  puts "idhash tends to find a lot more duplicates but also more false positives."
  puts "prepare: if given, the duplicates will be copied to a tmp folder for review"
  exit 1
end

ALGO = ARGV[i]
PREPARE = ARGV[i+1] == "prepare"

db.each do |k,v|
  db.delete(k) unless File.exists? k
end

db = db.to_a

Dir.mkdir("/tmp/duplicates") if PREPARE

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
    similar = DHashVips::IDHash.distance(h, h2) < 1 if ALGO == "idhash"
    dups.push(db[j][0]) if similar
  end

  if dups.length > 0
    puts "Duplicates #{i}:"
    puts f
    puts dups
    puts

    if PREPARE
      Dir.mkdir "/tmp/duplicates/#{i}"
      FileUtils.cp(f, "/tmp/duplicates/#{i}/")
      dups.each do |d|
        FileUtils.cp(d, "/tmp/duplicates/#{i}/")
      end
    end
  end
end
