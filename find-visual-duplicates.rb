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
  puts "Usage: find-visual-duplicates.rb <dbfile.yaml>* <dhash | idhash> [--ignore-within] [prepare]"
  puts "dhash tends to give quite reasonable results with only a slight overestimation."
  puts "idhash tends to find a lot more duplicates but also more false positives."
  puts "--ignore-within: if given, the algorithm will not compare images that are within the same hashdb"
  puts "prepare: if given, the duplicates will be copied to a tmp folder for review"
  exit 1
end

ALGO = ARGV[i]
ignore_within = false
if ARGV[i+1] == "--ignore-within"
  ignore_within = true
  i += 1
end
PREPARE = ARGV[i+1] == "prepare"

dba = db.to_a

Dir.mkdir("/tmp/duplicates") if PREPARE

def similar(h1, h2)
  if ALGO == "dhash"
    DHashVips::DHash.hamming(h1, h2) < 1
  elsif ALGO == "idhash"
    DHashVips::IDHash.distance(h1, h2) < 1
  else
    raise "Unknown algo: #{ALGO}"
  end
end

id_idx = 0
dba.each_with_index do |v, i|
  STDERR.puts "# Processing... [#{i} / #{dba.length}]" if (i % 1000) == 0

  f = v[0]
  h = v[1][ALGO]
  h_rot = v[1][ALGO + "_rot"]

  origin_hashdb = v[1]["origin_hashdb"]

  next if h.nil?

  dups = []

  (i+1).upto(dba.length - 1).each do |j|
    next if ignore_within && dba[j][1]["origin_hashdb"] == origin_hashdb

    h2 = dba[j][1][ALGO]
    h2_rot = dba[j][1][ALGO + "_rot"]
    next if h2.nil?

    sim = similar(h, h2)
    sim ||= similar(h_rot, h2) unless h_rot.nil?
    # sim ||= similar(h, h2_rot) unless h2_rot.nil?
    # sim ||= similar(h_rot, h2_rot) unless h_rot.nil? || h2_rot.nil?

    dups.push(dba[j][0]) if sim
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
