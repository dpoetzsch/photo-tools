#!/usr/bin/env ruby

require "yaml"
require "./lib-dups.rb"

if ARGV.length < 1
  puts "Usage: find-duplicates.rb <dbfile.yaml>*"
  exit 1
end

invdb = {}

db = cleanup_db(merge_dbs(ARGV))

db.each do |k,v|
  invdb[v["sha"]] ||= []
  invdb[v["sha"]].push(k)
end

i = 0
invdb.each_with_index do |kv|
  v = kv[1]

  if v.length > 1
    remove_false_positives(db, v).each do |d|
      print_dups(i, d)
      i += 1
    end
  end
end
