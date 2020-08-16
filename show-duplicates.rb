#!/usr/bin/env ruby

require "yaml"

if ARGV.length < 1
  puts "Usage: show-duplicates.rb <duplicates-output.yaml>"
  puts "Opens an eog instance for every duplicate so you can check them easily"
  exit 1
end

YAML.load(File.read(ARGV[0])).each do |k, dups|
  puts k
  `eog "#{dups.join('" "')}"`
end
