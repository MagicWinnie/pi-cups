# Pi-CUPS

A Raspberry Pi print server using Docker Compose, CUPS, and
[OpenPrinting SpliX](https://github.com/OpenPrinting/splix). It supports the
Samsung M2020; unnecessary vendor-driver bundles are not installed. Future
IPP-compatible Wi-Fi printers can use CUPS driverless printing.

## Setup

Requires Debian/Raspberry Pi OS, Docker Engine, Docker Compose v2, and a
USB-connected printer.

```bash
git clone https://github.com/MagicWinnie/pi-cups.git
cd pi-cups
chmod +x scripts/*.sh
cp .env.example .env
nano .env  # Set CUPS_ADMIN_PASSWORD

sudo systemctl disable --now cups cups-browsed
docker compose config --quiet
docker compose up -d --build --remove-orphans
```

These commands assume your user can run `docker info` without `sudo`. If not,
either prefix Docker commands with `sudo` or
[configure Docker for non-root use](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user).
Membership in the `docker` group grants root-level privileges.

- CUPS: `http://<pi-host>:631`
- Admin user: `print`
- Admin password: `CUPS_ADMIN_PASSWORD` from `.env`

## Add the Samsung M2020

In CUPS, select **Administration → Add Printer**, choose the USB-connected
printer, and select **Samsung M2020 Series**.

On Windows, avoid WSD and add the printer manually with this URL:

```text
http://<pi-ip>:631/printers/Samsung_M2020_Series
```

## Update

```bash
./scripts/backup.sh
git pull
docker compose build app
docker compose up -d --force-recreate --remove-orphans
docker compose exec app lpadmin -p Samsung_M2020_Series \
  -P /usr/share/cups/model/splix/m2020.ppd
docker compose exec app cat /opt/splix/.splix-version
docker compose exec app lpstat -t
```

The `lpadmin` command replaces CUPS's cached PPD while preserving the existing
queue and USB URI. Re-enable a stopped queue with:

```bash
docker compose exec app cupsenable Samsung_M2020_Series
```

SpliX uses its synchronous renderer by default because its legacy threaded page
cache has known races and crashes on some current CUPS systems. This changes
more than manual duplex: it is an alternate rendering path. To test the
threaded path without changing driver versions, build with:

```bash
docker compose build --build-arg SPLIX_DISABLE_THREADS=0 app
docker compose up -d --force-recreate app
docker compose exec app cat /opt/splix/.splix-version
```

The version marker must end in `+threaded`. Omit the build argument to return
to the safer default, whose marker ends in `+single-thread`.

The build also applies a narrow M2020 compatibility patch to compression
algorithm `0x11`. It writes QPDL integers explicitly in little-endian order
instead of using SpliX 2.0.2's host-dependent, unaligned integer accesses. The
installed marker starts with `2.0.2+m2020-le`; the driver remains based on
OpenPrinting SpliX 2.0.2.

## Backup and restore

```bash
./scripts/backup.sh
./scripts/restore.sh
```

The archive is stored at `data/backups/config.tar`.

## Troubleshooting

Check USB detection:

```bash
lsusb
ls -l /dev/usb /dev/bus/usb
docker compose exec app lpinfo -v
```

Recreate the app, confirm that `lpinfo -v` lists the Samsung `usb://` device,
then print after the printer has slept and woken:

```bash
docker compose up -d --force-recreate app
docker compose exec app lpinfo -v
docker compose exec app lpstat -t
```

If `lsusb` sees the printer but the container does not, inspect the USB device
permissions and the container logs. Relevant logs are available with:

```bash
docker compose logs --since 30m app
docker compose exec app tail -n 200 /var/log/cups/error_log
sudo journalctl -k -b --no-pager | tail -n 200
```

Based on [olbat/dockerfiles](https://github.com/olbat/dockerfiles/tree/master/cupsd) and [neutralvibes/pi-cups](https://github.com/neutralvibes/pi-cups).
