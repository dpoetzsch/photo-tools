#!/usr/bin/env ruby
#
# Find all images that are in a folder and are not duplicates.
# Usage example that checks if there are images in example-folder that are not yet sorted into the photos folder:
#
# create-hashdb.rb photos-hashdb.yaml photos/
# create-hashdb.rb example-folder-hashdb.yaml example-folder/
# find-duplicates.rb photos-hashdb.yaml example-folder-hashdb.yaml > dupout.yaml
# find-non-duplicates.rb example-folder/ dupout.yaml
#

require "yaml"
require "set"

if ARGV.length < 2
  puts "Usage: find-non-duplicates.rb <folder-to-search> <duplicates-output-file.yaml>"
  exit 1
end

FOLDER = File.realpath(File.expand_path(ARGV[0]))

# all files in FOLDER that are consideres as duplicates
duplicates = Set.new

YAML.load(File.read(ARGV[1])).each do |k, dups|
  # note that dups are already the real paths, no expansion necessary
  dups_in_folder = dups.find_all { |f| f.start_with?(FOLDER) }

  # if all dups are in the FOLDER then these do not count as duplicates to any external file
  duplicates.merge(dups_in_folder) if dups_in_folder.length < dups.length
end

Dir[File.join(FOLDER, "**/*")].each do |f|
  next unless File.file? f

  puts f if File.file?(f) && !duplicates.include?(f)
end
