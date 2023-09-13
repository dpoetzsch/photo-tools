#!/bin/sh

if [ -z "$1" ]; then
  echo "Usage: convert-heic.sh <directory with heic files>"
  exit 1
fi


HEIC_ARCHIVE="/run/media/dph/lake/nextcloud/heic-archive"
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
