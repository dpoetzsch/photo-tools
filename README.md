# photo-tools

This repository contains a collection of scripts to manage photos, especially to find duplicates and visually similar images.
The following tools are available:

- `convert-heic.sh` converts HEIC files to JPEG
- `create-hashdb.rb` creates a hash database of all files in a folder (see below for details)
- `find-duplicates.rb` finds duplicate images (based on a HashDB)
- `find-non-duplicates.rb` finds images that are in a folder and are not duplicates.
- `find-visual-duplicates.rb` finds images that are visually similar (based on a HashDB); usefull e.g. for finding duplicate WhatsApp images that have a lower resolution
- `mark-unequal.rb` marks images in a hashdb that are known to not be duplicates (useful to reduce the number of false positives in `find-visual-duplicates.rb`)
- `rename-photos.rb` renames photos to a standard filename format; guesses info from the filename and EXIF data
- `rm-duplicates.rb` removes duplicate images (based on the output of a `find-duplicates.rb` run)
- `show-duplicates.rb` shows duplicate images for manual inspection

All tools have a `--help` option that shows the available options.
Also, see below for an overview on how to find and process duplicate images using these tools.

## Setup

Under fedora do the following:

```bash
sudo dnf install ruby-devel libexif-devel perl-Image-ExifTool vips vips-devel libheif-tools
bundler
```

## Finding & processing duplicates

Many tools in this respository deal with duplicate or visually similar images.
Generally this task can be quite time consuming, so the tools are split into three steps:

1. **HashDB**:
    A HashDB is a YAML file that contains various hashes and metadata of a number of images.
    This information will be the basis for finding duplicates or visually similar images.
    Use `create-hashdb.rb` to create a HashDB for a folder.
    Use `create-hashdb.rb --help` to learn more and see the available options.

2. **Finding duplicates**:
    Based on a HashDB, you can find exact duplicates with `find-duplicates.rb` or visually similar images with `find-visual-duplicates.rb`.
    Both scripts output a YAML for further processing such as removing or manual inspection.
    It is recommended to pipe the output into a file for further processing.

3. **Processing duplicates**:
    You can use `rm-duplicates.rb` to remove duplicates or `show-duplicates.rb` to show them for manual inspection.
    Or you can use `find-non-duplicates.rb` to find images in a folder that are not duplicates (e.g. to make sure that you don't overlook an image).
    As finding visually similar images can create false positives, you can use `mark-unequal.rb` to mark images that are known to not be duplicates.
    Note that because the output of the previous step is a YAML file, you can easily manually edit it before feeding it into the above tools!

Generally, all tools are quite conservative meaning that they usually will not remove or alter any images without explicit options.
