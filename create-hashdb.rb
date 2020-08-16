#!/usr/bin/env ruby

require "yaml"
require "digest"
require "dhash-vips"
require "rmagick"
require "exif"
require "fileutils"

if ARGV.length < 2
  puts "Usage: create-hashdb.rb <dbfile.yaml> [--dry] [--clean] <folder>*"
  puts "If the db file already exists, it will only be updated."
  puts "If --clean flag is given, it will remove deleted files from db."
  puts "If --dry is passed no changes will be written."
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
      "mtime" => File.mtime(f).to_f
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
        f = "/tmp/create_hashdb_rotation_tmp#{Time.now.to_f}.jpg"
        img.write f
        # img.write f + ".rot#{exif.orientation}.jpg" # only for debugging
        db[path]["dhash_rot"] = DHashVips::DHash.calculate(f)
        db[path]["idhash_rot"] = DHashVips::IDHash.fingerprint(f)
        FileUtils.rm(f)
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
