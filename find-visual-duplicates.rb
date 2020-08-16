#!/usr/bin/env ruby

require "yaml"
require "dhash-vips"
require "fileutils"
require "./lib-dups.rb"

db_files = []
i = 0
while i < ARGV.length && ARGV[i] != "dhash" && ARGV[i] != "idhash"
  db_files.push ARGV[i]
  i += 1
end

db = cleanup_db(merge_dbs(db_files))

if i == ARGV.length
  puts "Usage: find-visual-duplicates.rb <dbfile.yaml>* <dhash | idhash> [prepare]"
  puts "dhash tends to give quite reasonable results with only a slight overestimation."
  puts "idhash tends to find a lot more duplicates but also more false positives."
  puts "prepare: if given, the duplicates will be copied to a tmp folder for review"
  exit 1
end

ALGO = ARGV[i]
PREPARE = ARGV[i+1] == "prepare"

dba = db.to_a

Dir.mkdir("/tmp/duplicates") if PREPARE

id_idx = 0
dba.each_with_index do |v, i|
  f = v[0]
  h = v[1][ALGO]

  next if h.nil?

  dups = []

  (i+1).upto(dba.length - 1).each do |j|
    h2 = dba[j][1][ALGO]
    next if h2.nil?

    diff = false
    similar = DHashVips::DHash.hamming(h, h2) < 1 if ALGO == "dhash"
    similar = DHashVips::IDHash.distance(h, h2) < 1 if ALGO == "idhash"
    dups.push(dba[j][0]) if similar
  end

  if dups.length > 0
    remove_false_positives(db, [f] + dups).each do |d|
      print_dups(id_idx, d)

      if PREPARE
        Dir.mkdir "/tmp/duplicates/#{id_idx}"
        FileUtils.cp(f, "/tmp/duplicates/#{id_idx}/")
        dups.each do |d|
          FileUtils.cp(d, "/tmp/duplicates/#{id_idx}/")
        end
      end

      id_idx += 1
    end
  end
end
