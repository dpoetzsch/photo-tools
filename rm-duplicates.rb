#!/usr/bin/env ruby

require "yaml"
require "fileutils"

if ARGV.length < 1
  puts "Usage: rm-duplicates <duplicates-output-file.yaml> [rm]"
  exit 1
end

YAML.load(File.read(ARGV[0])).each do |k, dups|
  dups[1..-1].each do |f|
    puts f
    FileUtils.rm(f) if ARGV[1] == "rm"
  end
end
