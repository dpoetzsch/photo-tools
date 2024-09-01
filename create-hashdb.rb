#!/usr/bin/env ruby

require "yaml"
require "digest"
require "dhash-vips"
require "rmagick"
require "exif"
require "fileutils"

HELPTEXT = <<HELP
Usage: create-hashdb.rb <hashdb.yaml> [--dry] [--clean] <folder>*

Hash all images in a folder and write the hashes to a hashdb file.
If the db file already exists, it will only be updated.

Arguments:
  hashdb.yaml: The file to write the hashes to.
      --clean: If set, this script will remove deleted files from db.
        --dry: If set, no changes will be written.
HELP

if ARGV.length < 2 || ARGV.include?("--help") || ARGV.include?("-h")
  puts HELPTEXT
  exit 1
end

HASHDB = ARGV[0]

if File.exist? HASHDB # rubocop:disable Style/ConditionalAssignment
  db = YAML.load(File.read(HASHDB))
else
  db = {}
end

args = []
files = []
nomoreargs = false
ARGV[1..-1].each do |a|
  if nomoreargs || !a.start_with?("--")
    files.push a
  elsif a == "--"
    nomoreargs = true
  else
    args.push a
  end
end

# remove deleted files
if args.include? "--clean"
  db.each do |k,v|
    next if File.exist? k

    puts "Cleaning: #{k}"
    db.delete(k)
  end
end

files = files.map { |a| Dir[a + "/**/*"] }
  .flatten
  .find_all { |f| File.file? f }
  .sort

files.each_with_index do |f, i|
  begin
    printf("%5d/%5d: %s\n", i + 1, files.length, f)

    next unless File.exist? f

    mtime = File.mtime(f).to_f
    path = File.realpath(File.expand_path(f))

    next unless db[path].nil? || db[path]["mtime"] != mtime

    db[path] = {
      "sha" => Digest::SHA2.hexdigest(File.read(f)),
      "mtime" => mtime
    }

    # algo still has problems with large videos files:
    # for these we need way too much RAM
    if f.end_with?(".jpg") || (File.size(f) < 7_000_000) # rubocop:disable Style/Next
      db[path]["dhash"] = DHashVips::DHash.calculate(f)
      db[path]["idhash"] = DHashVips::IDHash.fingerprint(f)
    end

    # jpg might have a orientation set via exif; we save also the correctly rotated image's hashes
    if f.end_with?(".jpg")
      begin
        exif = File.open(f, 'r') { |ff| Exif::Data.new(ff) }
      rescue => e
      end
      if exif && exif.orientation && exif.orientation > 1
        # Orientation values: see https://sirv.com/help/articles/rotate-photos-to-be-upright/
        img = Magick::Image::read(f).first
        img = case exif.orientation
              when 2 then img.flip.rotate(180)
              when 3 then img.rotate(180)
              when 4 then img.flip
              when 5 then img.flip.rotate(270)
              when 6 then img.rotate(90)
              when 7 then img.flip.rotate(90)
              when 8 then img.rotate(270)
              end
        ff = "/tmp/create_hashdb_rotation_tmp#{Time.now.to_f}.jpg"
        img.write ff
        # img.write f + ".rot#{exif.orientation}.jpg" # only for debugging
        db[path]["dhash_rot"] = DHashVips::DHash.calculate(ff)
        db[path]["idhash_rot"] = DHashVips::IDHash.fingerprint(ff)
        FileUtils.rm(ff)
      end
    end
  rescue => e
    puts e
  end
end

# write db
unless args.include? "--dry"
  File.open(HASHDB, 'w') { |f| f.write YAML.dump(db) }
end
