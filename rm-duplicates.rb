#!/usr/bin/env ruby

require "fileutils"

if ARGV.length < 1
  puts "Usage: rm-duplicates <duplicates-output-file.txt> <rm>"
  exit 1
end

dups = File.read(ARGV[0]).split("\n\nDuplicates:\n")
dups[0] = dups[0].split("\n")[1..-1].join("\n")

dups.map! { |d| d.split("\n")[1..-1] }

dups.flatten.each { |f| 
  puts f
  FileUtils.rm(f) if ARGV[1] == "rm"
}