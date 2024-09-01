#!/usr/bin/env ruby

require 'exif'
require "exiftool"
require 'fileutils'
require "date"
require "active_support/time"

if ARGV.empty? || ARGV.include?("--help") || ARGV.include?("-h")
  puts 'Usage: rename-photos.rb <dir> [rename]'
  puts
  puts 'Renames photos in the given directory to a standard filename.'
  puts 'This script will try to guess the date and time of the photo from the filename '
  puts 'and EXIF data.'
  puts 'The resulting output filename will be of the format:'
  puts '  YYYY-MM-DD[_HH.MM.SS][_number][_comment].ext'
  puts
  puts 'Arguments:'
  puts '     dir: The directory containing the photos to rename.'
  puts '          Subdirectories will be included.'
  puts '  rename: If specified, the files will be renamed.'
  puts '          Otherwise, only the new names will be printed ("dry run").'
  exit 1
end

def dotteddate(date)
  date[0..3] + '.' + date[4..5] + '.' + date[6..7]
end

def dottedtime(time)
  time[0..1] + ':' + time[2..3] + ':' + time[4..5]
end

def time2str(t)
  year, month, day = t.year, t.month, t.day
  hour, min, sec = t.hour, t.min, t.sec

  # format
  date = format("%04d.%02d.%02d", year, month, day)
  time = format("%02d:%02d:%02d", hour, min, sec)

  return [date, time]
end

def utc2cet(date, time)
  t = Time.utc(*(date.split(".") + time.split(":"))).in_time_zone("Berlin")
  return time2str(t)
end

def fast_exif(f)
  begin
    exif = File.open(f, 'r') { |ff| Exif::Data.new(ff) }
  rescue => e
  end
  if exif && exif.date_time_original
    if exif.date_time_original =~ /^(\d\d\d\d):(\d\d):(\d\d) (\d\d:\d\d:\d\d)$/
      date = $1 + '.' + $2 + '.' + $3
      time = $4
      # if (f.include? "DSC")
      #   h,m,s = $4.split(":")
      #   time = "#{h.to_i+12}:#{m}:#{s}"
      # end
      return [date, time]
    else
      puts "FAILED: unknown exif date format for #{f}: #{exif.date_time}"
    end
  end
  return nil
end

def full_exif(f)
  exif = Exiftool.new(f)
  unless exif.errors?
    datetime = exif[:date_time_original] || exif[:creation_date] || exif[:create_date]

    if datetime.to_s =~ /^(\d\d\d\d):(\d\d):(\d\d) (\d\d):(\d\d):(\d\d)$/
      year, month, day = $1.to_i, $2.to_i, $3.to_i
      hour, min, sec = $4.to_i, $5.to_i, $6.to_i
      zone = []
    elsif datetime.to_s =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d) (.)(\d\d)(\d\d)$/
      year, month, day = $1.to_i, $2.to_i, $3.to_i
      hour, min, sec = $4.to_i, $5.to_i, $6.to_i
      zone = [$7, $8.to_i, $9.to_i]
    else
      return nil
    end

    # switch zone
    if zone.empty?
      t = Time.utc(year, month, day, hour, min, sec).in_time_zone("Berlin")
    else
      t = Time.utc(year, month, day, hour, min, sec) # already in local time
    end

    return time2str(t)
  end
  return nil
end

def parse_datetime(date, time, f)
  return nil unless date

  year, month, day = date.split(".").map(&:to_i)
  return nil if year == 0 || month == 0 || day == 0

  if time
    hour, min, sec = time.split(":").map(&:to_i)
  else
    hour = min = sec = 0
  end

  begin
    Time.new(year, month, day, hour, min, sec)
  rescue => e
    puts f
    puts(year, month, day, hour, min, sec)
    raise e
  end
end

def whatsapp(nametype, bname)
  nametype.start_with?("WhatsApp:") || (nametype.start_with?("david") && bname =~ /WA\d\d\d\d/)
end

files = Dir["#{ARGV[0]}/**/*"].find_all { |f| File.file? f }.sort

puts "PHASE 1: Analysing..."
data = {}
files.each do |f|
  suffix = f.split('.')[-1]
  bname = File.basename(f, "." + suffix)

  nametype = nil
  date = nil
  time = nil
  number = nil
  comment = nil

  norm_bname = bname.start_with?("Copy of ") ? bname[8..-1] : bname

  if norm_bname =~ /^(\d\d\d\d-\d\d-\d\d)(_(\d\d\.\d\d\.\d\d))?(_(.*))?$/
    nametype = "david"
    date = $1
    time = $3
    comment = $5

    date.gsub!("-", ".")
    time.gsub!(".", ":") unless time.nil?
  elsif norm_bname =~ /^(\d\d\d\d\.\d\d\.\d\d)(_(\d\d:\d\d:\d\d))?(_(.*))?$/
    nametype = "davidold"
    date = $1
    time = $3
    comment = $5
  elsif norm_bname =~ /^IMG_(\d{8})_(\d{6})(_(.*))?$/ && $1.start_with?('20')
    nametype = "IMG_date_time"
    date = dotteddate($1)
    time = dottedtime($2)
    comment = $4
  elsif norm_bname =~ /^IMG_(\d{8})_(\d{6})~(\d)(_(.*))?$/ && $1.start_with?('20')
    nametype = "IMG_date_time~number"
    date = dotteddate($1)
    time = dottedtime($2)
    number = $3
    comment = $5
  elsif norm_bname =~ /^IMG_(\d{8})_(\d{6})(\d\d\d)(_(.*))?$/ && $1.start_with?('20')
    nametype = "IMG_date_timenumber"
    date = dotteddate($1)
    time = dottedtime($2)
    number = $3
    comment = $5
  elsif norm_bname =~ /^IMG_(\d{8})_(\d\d\d)(_(.*))?$/ && $1.start_with?('20')
    nametype = "IMG_date_number"
    date = dotteddate($1)
    number = $2
    comment = $4
  elsif norm_bname =~ /^IMG_(E?\d\d\d\d(-\d+)?)((_| |-)(.*))?$/
    nametype = "IMG_number"
    number = $1
    comment = $5
  elsif norm_bname =~ /^IMG_(\d\d\d\d)(~(photo|video))$/
    nametype = "IMG_number~type"
    number = $1
    comment = $4
  elsif norm_bname =~ /^YI(\d{6})(_(.*))?$/
    nametype = "YInumber"
    number = $1
    comment = $3
  elsif norm_bname =~ /^PANO_(\d{8})_(\d{6})(_(.*))?$/ && $1.start_with?('20')
    nametype = "PANO_date_time"
    date = dotteddate($1)
    time = dottedtime($2)
    comment = $4
  elsif norm_bname =~ /^P_(\d{8})_(\d{6})(_(.*))?$/ && $1.start_with?('20')
    nametype = "P_date_time"
    date = dotteddate($1)
    time = dottedtime($2)
    comment = $4
  elsif norm_bname =~ /^[Pp](\d{7})(_(.*))?$/
    nametype = "Pnumber"
    number = $1
    comment = $3
  elsif norm_bname =~ /^[Pp](\d{7}) \((\d+)\)$/
    nametype = "Pnumbernumber"
    number = $1
    comment = $2
  elsif norm_bname =~ /^PB(\d{6})(_(.*))?$/
    nametype = "PBnumber"
    number = $1
    comment = $3
  elsif norm_bname =~ /^WP_(\d{8})_(\d\d\d)(_(.*))?$/ && $1.start_with?('20') # e.g. WP_20160303_011.jpg
    nametype = "WP_date_number"
    date = dotteddate($1)
    number = $2
    comment = $4
  elsif norm_bname =~ /^WP_(\d{8})_(\d\d)_(\d\d)_(\d\d)(_(.*))?$/ && $1.start_with?('20') # e.g. WP_20160303_011.jpg
    nametype = "WP_date_time"
    date = dotteddate($1)
    time = $2 + ":" + $3 + ":" + $4
    comment = $6
  elsif norm_bname =~ /^IMG-(\d{8})-(WA\d\d\d\d)((_|-)(.*))?$/ && $1.start_with?('20')
    nametype = "WhatsApp:IMG-date-number"
    date = dotteddate($1)
    number = $2
    comment = $5
  elsif norm_bname =~ /^_(\d\d\d\d\d\d\d)(_(.*))?$/
    nametype = "underscore_number"
    number = $1
    comment = $4
  elsif norm_bname =~ /^DSC_(\d\d\d\d(-\d+)?)(_(.*))?$/
    nametype = "DSC_number"
    number = $1
    comment = $4
  elsif norm_bname =~ /^_?DSC(\d\d\d\d\d?)(_(.*))?$/
    nametype = "DSCnumber"
    number = $1
    comment = $3
  elsif norm_bname =~ /^DSCF(\d\d\d\d)(_(.*))?$/
    nametype = "DSCFnumber"
    number = $1
    comment = $3
  elsif norm_bname =~ /^DSCN(\d\d\d\d)(_(.*))?$/
    nametype = "DSCNnumber"
    number = $1
    comment = $3
  elsif norm_bname =~ /^IMAG(\d\d\d\d)(_(.*))?$/
    nametype = "IMAGnumber"
    number = $1
    comment = $3
  elsif norm_bname =~ /^IMGP(\d\d\d\d\w?)(_(.*))?$/
    nametype = "IMGPnumber"
    number = $1
    comment = $3
  elsif norm_bname =~ /^CIMG(\d\d\d\d\d?)(_(.*))?$/
    nametype = "CIMGnumber"
    number = $1
    comment = $3
  elsif norm_bname =~ /^MVI_(\d\d\d\d)(_(.*))?$/
    nametype = "MVI_number"
    number = $1
    comment = $3
  elsif norm_bname =~ /^VID_(\d{8})_(\d{6})(_(.*))?$/ && $1.start_with?('20')
    nametype = "VID_date_time"
    date = dotteddate($1)
    time = dottedtime($2)
    comment = $4
  elsif norm_bname =~ /^VID_(\d{8})_(\d{6})(\d\d\d)(_(.*))?$/ && $1.start_with?('20')
    nametype = "VID_date_timenumber"
    date = dotteddate($1)
    time = dottedtime($2)
    number = $3
    comment = $5
  elsif norm_bname =~ /^PXL_(\d{8})_(\d{6})(\d{3}(\..*)?(~\d+)?(-PANO)?)$/
    nametype = "PXL"
    date = dotteddate($1)
    time = dottedtime($2)
    comment = $3.gsub(".", "-").gsub("~", "-")

    # Google Pixel uses UTC instead of local time; correct it to Berlin Time
    date, time = utc2cet(date, time)
  elsif norm_bname =~ /^(original_.+?)_PXL_(\d{8})_(\d{6})(\d{3}(\..*)?(~\d+)?)$/
    nametype = "PXL"
    date = dotteddate($2)
    time = dottedtime($3)
    comment = $1 + "_" + $4.gsub(".", "-").gsub("~", "-")

    # Google Pixel uses UTC instead of local time; correct it to Berlin Time
    date, time = utc2cet(date, time)
  elsif norm_bname =~ /^VID-(\d{8})-(WA\d\d\d\d)((_|-)(.*))?$/ && $1.start_with?('20')
    nametype = "WhatsApp:VID-date-number"
    date = dotteddate($1)
    number = $2
    comment = $5
  elsif norm_bname =~ /^CYMERA_(\d{8})_(\d{6})(\((\d+)\))?(_(.*))?$/ && $1.start_with?('20') # e.g. CYMERA_20150501_135402.jpg
    nametype = "CYMERA_date_time"
    date = dotteddate($1)
    time = dottedtime($2)
    number = $4
    comment = $6
  elsif norm_bname =~ /^(\d{8})_(\d{6})(\((\d+)\))?(_(.*))?$/ && $1.start_with?('20') # e.g. 20150501_135402.jpg
    nametype = "date_time"
    date = dotteddate($1)
    time = dottedtime($2)
    number = $4
    comment = $6
  elsif norm_bname =~ /^(\d\d)-(\d\d)-(\d\d) (\d\d)-(\d\d)-(\d\d) (\d+)$/ # e.g. 24-03-09 14-32-11 1948.jpg
    nametype = "date_time_dashed"
    date = dotteddate("20" + $1 + $2 + $3)
    time = dottedtime($4 + $5 + $6)
    number = $7
  elsif norm_bname =~ /^Screenshot from (\d\d\d\d)-(\d\d)-(\d\d) (\d\d)-(\d\d)-(\d\d)$/ # e.g. Screenshot from 2016-03-24 14-32-11.png
    nametype = "Screenshot date_time"
    date = dotteddate($1 + $2 + $3)
    time = dottedtime($4 + $5 + $6)
    comment = "Screenshot"
  elsif norm_bname =~ /^Photo ([A-Za-z]+) (\d\d?), (\d\d?) (\d\d?) (\d\d?)$/ # e.g. Photo 7-18-15, 1 03 32 PM.jpg
    nametype = "USA:Photo partial_date, time"
    time = format("%02d:%02d:%02d", $3.to_i, $4.to_i, $5.to_i)
  elsif norm_bname =~ /^Photo (\d\d?)-(\d\d?)-(\d\d), (\d\d?) (\d\d?) (\d\d?) ([AP]M)$/ # e.g. Photo 7-18-15, 1 03 32 PM.jpg
    nametype = "USA:Photo date, time"
    date = format("20%s.%02d.%02d", $3, $1.to_i, $2.to_i)

    h = $4.to_i
    h -= 12 if h == 12
    h += 12 if $7 == "PM"
    time = format("%02d:%02d:%02d", h, $5.to_i, $6.to_i)
  elsif norm_bname =~ /^Video ([A-Za-z]+) (\d\d?), (\d\d?) (\d\d?) (\d\d?)$/ # e.g. Video 7-18-15, 1 03 32 PM.jpg
    nametype = "USA:Video partial_date, time"
    time = format("%02d:%02d:%02d", $3.to_i, $4.to_i, $5.to_i)
  elsif norm_bname =~ /^Video (\d\d?)-(\d\d?)-(\d\d), (\d\d?) (\d\d?) (\d\d?) ([AP]M)$/ # e.g. Photo 7-18-15, 1 03 32 PM.jpg
    nametype = "USA:Video date, time"
    date = format("20%s.%02d.%02d", $3, $1.to_i, $2.to_i)

    h = $4.to_i
    h -= 12 if h == 12
    h += 12 if $7 == "PM"
    time = format("%02d:%02d:%02d", h, $5.to_i, $6.to_i)
  elsif norm_bname =~ /^Video (\d\d)\.(\d\d)\.(\d\d), (\d\d) (\d\d) (\d\d)(_(.*))?$/ # e.g. Video 03.03.16, 21 01 55.mov
    nametype = "Video date time"
    date = "20" + $3 + "." + $2 + "." + $1
    time = $4 + ":" + $5 + ":" + $6
    comment = $8
  elsif norm_bname =~ /^Clip (#\d\d)?$/ # e.g. Video 03.03.16, 21 01 55.mov
    nametype = "Clip number"
    number = $1
  elsif norm_bname =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d).(\d\d).(\d\d)(-(\d))?$/ && $1.start_with?('20') # e.g. Video 03.03.16, 21 01 55.mov
    nametype = "date time"
    date = $1 + "." + $2 + "." + $3
    time = $4 + ":" + $5 + ":" + $6
    number = $8
  elsif norm_bname =~ /^(\d\d)\.(\d\d)\.(\d\d\d\d)(_.*)?/
    nametype = "date"
    date = $3 + "." + $2 + "." + $1
    comment = $4
  elsif norm_bname =~ /^(\d+)( \((\d+)\))?(_(.*))?$/   # e.g. 12345.jpg
    nametype = "number"
    number = $1
    number += $3 unless $3.nil?
    comment = $5
  elsif norm_bname =~ /^(\w+-?\d*?)$/ # e.g. feier-1.jpg
    nametype = "name-number"
    comment = $1
  elsif norm_bname =~ /^(\w{8}-\w{4}-\w{4}-\w{4}-\w{12})$/ # e.g. E3AFC2B5-F070-4696-8422-A926D2B94F79.jpeg
    nametype = "iphoneid"
    number = $1
  else
    puts "unknown file name format: #{bname}.#{suffix}    (#{f})"
    next
  end

  # don't do exif for whatsapp, this just makes things more chaotic as
  # the times are broken as hell
  if !whatsapp(nametype, bname) && !nametype.start_with?("david") && !nametype.start_with?("USA:")
    exifdate = fast_exif(f)
    if exifdate
      ndate, ntime = exifdate
      if date && ndate != date
        puts "WARN: file date was #{date} but exif date was #{ndate} for    #{f}"
      elsif time && (parse_datetime(date, time, f) - parse_datetime(ndate, ntime, f)).abs > 5 # 5 seconds tolerance due to save times etc.
        puts "WARN: file time was #{time} but exif time was #{ntime} for    #{f}"
      end
      date, time = ndate, ntime
    elsif !date || !time  # try full exif
      exifdate = full_exif(f)
      if exifdate
        date, time = exifdate
      else
        puts "FAILED to read exif for    #{f}"
      end
    end
  end

  while time && time[0..1].to_i > 23
    time = format("%02d%s", time[0..1].to_i - 24, time[2..-1])
  end

  data[f] = {
    bname: bname,
    suffix: suffix,
    nametype: nametype,
    date: date,
    time: time,
    number: number,
    comment: comment,
  }
end

puts 
puts "PHASE 2: Validating..."
files.each_with_index do |f, i|
  dir = File.dirname(f)
  d = data[f]
  next unless d

  # within each name group the files should still be in the same order
  prevf = i > 0 ? files[i-1] : nil
  prev = prevf && data[prevf]
  if prev && File.dirname(prevf) == dir && prev[:nametype] == d[:nametype]
    incl_time = d[:time] && prev[:time] # only include time if both have a time
    datetime = parse_datetime(d[:date], incl_time && d[:time], f)
    prev_datetime = parse_datetime(prev[:date], incl_time && prev[:time], prevf)

    if datetime && prev_datetime && (prev_datetime - datetime) > 0
      prev_datestr = "#{prev[:date]}_#{prev[:time]}"
      datestr = "#{d[:date]}_#{d[:time]}"

      puts "Possibly invalid: "
      printf("%-100s was estimated at %s and should be BEFORE\n", prevf, prev_datestr)
      printf("%-100s     estimated at %s\n\n", f, datestr)
    end
  end
end

puts 
puts "PHASE 3: Renaming..."
files.each do |f|
  d = data[f]

  if d && d[:date] && !d[:date].empty?
    # date is of format YYYY.MM.DD and should be YYYY-MM-DD
    newname = d[:date].gsub(".", "-")

    if d[:time] && !d[:time].empty?
      # time is of format HH:MM:SS and should be HH.MM.SS (for windows compatibility)
      newname += "_" + d[:time].gsub(":", ".")
    end

    if d[:number] && !d[:number].empty?
      newname += "_" + d[:number]
    end

    if d[:comment] && !d[:comment].empty?
      newname += "_" + d[:comment]
    end
  else
    puts "Cannot rename due to unknown date:   #{f}"
    next
  end

  newbname = newname

  newname += "." + d[:suffix].downcase
  oldname = "#{d[:bname]}.#{d[:suffix]}"
  next if newname == oldname

  dirname = File.dirname(f)
  newpath = dirname + "/" + newname

  i = 0
  while File.exist? newpath
    newname = newbname + "_#{i += 1}" + "." + d[:suffix].downcase
    dirname = File.dirname(f)
    newpath = dirname + "/" + newname
  end

  printf("%-100s  -->  %s\n", f, newname)

  if ARGV[1] == "rename"
    unless File.exist?(newpath)
      FileUtils.mv(f, newpath)
    else
      puts "File exists; SKIPPING:   #{newpath}"
    end
  end
end
