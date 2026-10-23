#!/bin/sh
set -eu

: "${SPLIX_VERSION:?SPLIX_VERSION is required}"

source_dir="/opt/splix"
output_dir="/out"
archive="/tmp/splix.zip"

wget -q -O "$archive" \
  "https://github.com/OpenPrinting/splix/archive/refs/tags/${SPLIX_VERSION}.zip"
unzip -q "$archive" -d /opt
mv "/opt/splix-${SPLIX_VERSION}" "$source_dir"
rm "$archive"

# Debian 12 provides cups-config but does not include a cups.pc file.
sed -i \
  -e 's/pkg-config --cflags cups/cups-config --cflags/g' \
  -e 's/pkg-config --libs cups/cups-config --libs/g' \
  "$source_dir/module.mk"

# Backport OpenPrinting/splix@63956b6: SPL/QPDL page-header dimensions use a
# 300-DPI grid, independently of the resolution used for raster bands.
patch -d "$source_dir" -p1 \
  < /usr/local/share/splix-300dpi-page-header.patch

# The M2020 does not need JBIG. Disabling SpliX's legacy threaded page cache
# avoids its crash-prone path; the tradeoff is that manual duplex is disabled.
make -C "$source_dir" \
  DISABLE_JBIG=1 \
  DISABLE_THREADS=1 \
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
printf '%s\n' "$SPLIX_VERSION" > "$output_dir/opt/splix/.splix-version"
