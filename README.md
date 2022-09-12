## Setup

Under fedora do the following:

```bash
sudo dnf install ruby-devel libexif-devel perl-Image-ExifTool vips vips-devel
bundler
```

## Find out if there are pictures in a folder that are not yet in Photos

```bash
create-hashdb.rb photos-hashdb.yaml photos/
create-hashdb.rb example-folder-hashdb.yaml example-folder/
find-duplicates.rb photos-hashdb.yaml example-folder-hashdb.yaml > dupout.yaml
find-non-duplicates.rb example-folder/ dupout.yaml
```
