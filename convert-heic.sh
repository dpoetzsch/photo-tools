#!/bin/bash

HEIC_ARCHIVE="/run/media/dph/lake/nextcloud/heic-archive"

if [ "$1" = "" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: convert-heic.sh <directory with heic files>"
  echo
  echo "Converts all HEIC files in the given directory to JPEG, and moves the"
  echo "HEIC files to a new subdirectoy in $HEIC_ARCHIVE."
  echo "This script does not overwrite existing files."
  echo
  echo "This script requires the 'heif-convert' and 'exiftool' commands."
  exit 1
fi

UUID=`uuid`

if [ -d "$HEIC_ARCHIVE/$UUID" ]; then
  echo "Archive directory $HEIC_ARCHIVE/$UUID already exists."
  exit 2
fi

mkdir "$HEIC_ARCHIVE/$UUID"

for f in "$1"/*.HEIC; do
  KEY="$UUID/"`basename "$f"`
  DEST="$HEIC_ARCHIVE/$KEY"
  JPG_FILE=`dirname "$f"`/`basename "$f" .HEIC`.jpg

  if [ -f "$DEST" ]; then
    echo "Cannot archive $f; destination $DEST already exists"
    exit 3
  fi

  if [ -f "$JPG_FILE" ]; then
    echo "Cannot convert $f; jpeg destination $JPG_FILE already exists"
    exit 4
  fi

  # convert
  heif-convert "$f" "$JPG_FILE"

  # add reference to original
  exiftool -ImageHistory="HEIC:$KEY" -overwrite_original "$JPG_FILE"

  # move heic to archive
  mv -v "$f" "$DEST"

  echo
done
