#!/bin/sh
set -eu

version="2.0.2"
source_dir="/opt/splix"
output_dir="/out"
archive="/tmp/splix.zip"

wget -q -O "$archive" \
  "https://github.com/OpenPrinting/splix/archive/refs/tags/${version}.zip"
unzip -q "$archive" -d /opt
mv "/opt/splix-${version}" "$source_dir"
rm "$archive"

# Debian 12 provides cups-config but does not include a cups.pc file.
sed -i \
  -e 's/pkg-config --cflags cups/cups-config --cflags/g' \
  -e 's/pkg-config --libs cups/cups-config --libs/g' \
  "$source_dir/module.mk"

# QPDL compression 0x11 is a little-endian wire format. Upstream 2.0.2 uses
# native unaligned integer accesses and marks the result host-dependent, which
# selects a broken generic sub-header path. Encode the stream explicitly and
# select the existing little-endian writer instead.
patch -d "$source_dir" -p1 \
  < /usr/local/share/splix-algo0x11-little-endian.patch

# The M2020 does not need JBIG. Its synchronous renderer produces a stream that
# this printer rejects, so use the threaded renderer with one compression
# worker to reduce concurrency in SpliX's legacy page cache.
make -C "$source_dir" \
  DISABLE_JBIG=1 \
  THREADS=1 \
  CUPSFILTER=/usr/lib/cups/filter \
  CUPSPPD=/usr/share/cups/model \
  CUPSPROFILE=/usr/share/cups/profiles

generated_ppd="$source_dir/generated-ppd"
mkdir -p "$generated_ppd"
cd "$source_dir/ppd"
./compile.sh samsung.drv.in -I . -d "$generated_ppd"
test -s "$generated_ppd/m2020.ppd"

install -d \
  "$output_dir/usr/lib/cups/filter" \
  "$output_dir/usr/share/cups/model/splix" \
  "$output_dir/opt/splix"
install -m 755 "$source_dir/optimized/rastertoqpdl" \
  "$output_dir/usr/lib/cups/filter/"
install -m 644 "$generated_ppd/m2020.ppd" \
  "$output_dir/usr/share/cups/model/splix/"
printf '%s+m2020-le+threaded-1w\n' "$version" \
  > "$output_dir/opt/splix/.splix-version"
