#!/bin/sh
set -eu

: "${SPLIX_COMMIT:?SPLIX_COMMIT is required}"

checkout_dir="/opt/splix-${SPLIX_COMMIT}"
source_dir="$checkout_dir/splix"
output_dir="/out"
archive="/tmp/splix.zip"

wget -q -O "$archive" \
  "https://gitlab.com/ScumCoder/splix/-/archive/${SPLIX_COMMIT}/splix-${SPLIX_COMMIT}.zip"
unzip -q "$archive" -d /opt
rm "$archive"
test -d "$source_dir"

# Reproduce the SpliX build previously proven with this M2020. Pinning the
# commit avoids depending on the moving patches branch.
make -C "$source_dir" \
  DISABLE_JBIG=1 \
  CUPSFILTER=/usr/lib/cups/filter \
  CUPSPPD=/usr/share/cups/model \
  CUPSPROFILE=/usr/share/cups/profiles

test -s "$source_dir/optimized/rastertoqpdl"
test -s "$source_dir/ppd/m2020.ppd"

install -d \
  "$output_dir/usr/lib/cups/filter" \
  "$output_dir/usr/share/cups/model/splix" \
  "$output_dir/opt/splix"
install -m 755 "$source_dir/optimized/rastertoqpdl" \
  "$output_dir/usr/lib/cups/filter/"
install -m 644 "$source_dir/ppd/m2020.ppd" \
  "$output_dir/usr/share/cups/model/splix/"
printf 'ScumCoder/splix@%s\n' "$SPLIX_COMMIT" \
  > "$output_dir/opt/splix/.splix-version"
