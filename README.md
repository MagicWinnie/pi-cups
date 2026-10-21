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
docker compose build --no-cache app
docker compose up -d --force-recreate --remove-orphans
docker compose exec app cat /opt/splix/.splix-version
docker compose exec app lpstat -t
```

After a SpliX update, modify an existing printer in CUPS and select or upload
the new `m2020.ppd`. Re-enable a stopped queue with:

```bash
docker compose exec app cupsenable Samsung_M2020_Series
```

SpliX uses single-threaded compression for stability. Single-sided printing is
unaffected, but its assisted manual-duplex workflow is unavailable.

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

Leave `CUPS_PRIVILEGED=false`. Recreate the app, confirm that `lpinfo -v` lists
the Samsung `usb://` device, then print after the printer has slept and woken:

```bash
docker compose up -d --force-recreate app
docker compose config | grep 'privileged:'
docker compose exec app lpinfo -v
docker compose exec app lpstat -t
```

If `lsusb` sees the printer but the container does not, set
`CUPS_PRIVILEGED=true`, recreate the app, and repeat the test. Privileged mode
grants broad host access, so use it only as a diagnostic or fallback. Relevant
logs are available with:

```bash
docker compose logs --since 30m app
docker compose exec app tail -n 200 /var/log/cups/error_log
sudo journalctl -k -b --no-pager | tail -n 200
```

Based on [olbat/dockerfiles](https://github.com/olbat/dockerfiles/tree/master/cupsd) and [neutralvibes/pi-cups](https://github.com/neutralvibes/pi-cups).
