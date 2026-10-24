#!/bin/sh
set -eu

: "${SPLIX_VERSION:?SPLIX_VERSION is required}"
: "${SPLIX_DISABLE_THREADS:=1}"

case "$SPLIX_DISABLE_THREADS" in
  0|1) ;;
  *)
    echo "SPLIX_DISABLE_THREADS must be 0 or 1" >&2
    exit 2
    ;;
esac

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

# QPDL compression 0x11 is a little-endian wire format. Upstream 2.0.2 uses
# native unaligned integer accesses and marks the result host-dependent, which
# selects a broken generic sub-header path. Encode the stream explicitly and
# select the existing little-endian writer instead.
patch -d "$source_dir" -p1 \
  < /usr/local/share/splix-algo0x11-little-endian.patch

# The M2020 does not need JBIG. The threaded renderer can be enabled for
# compatibility testing, but remains disabled by default because its legacy
# page cache has known races and crashes on some current CUPS systems.
make -C "$source_dir" \
  DISABLE_JBIG=1 \
  DISABLE_THREADS="$SPLIX_DISABLE_THREADS" \
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
if [ "$SPLIX_DISABLE_THREADS" = 1 ]; then
  render_mode="single-thread"
else
  render_mode="threaded"
fi

printf '%s+m2020-le+%s\n' "$SPLIX_VERSION" "$render_mode" \
  > "$output_dir/opt/splix/.splix-version"
