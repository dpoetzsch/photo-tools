#!/usr/bin/env ruby

require "yaml"

if ARGV.length < 1
  puts "Usage: find-duplicates.rb <dbfile.yaml>*"
  exit 1
end

invdb = {}

ARGV.each do |arg|
  db = YAML.load(File.read(arg))

  db.each do |k,v|
    if File.exists? k
      invdb[v] ||= []
      invdb[v].push(k)
    end
  end
end

invdb.each do |k,v|
  if v.length > 1
    puts "Duplicates:"
    puts v
    puts
  end
end
