#!/bin/sh

set -e

REPO="https://raw.githubusercontent.com/Coumarin-26026/dashboard/main/vwrt.zip"
TMP="/tmp/vwrt-installer"

echo "========================================="
echo " VWRT Dashboard Installer for Coumarin "
echo "========================================="
echo

# Root check

if [ "$(id -u)" != "0" ]; then
echo "ERROR: Please run as root"
exit 1
fi

# OpenWrt check

if [ ! -f /etc/openwrt_release ]; then
echo "ERROR: OpenWrt/Coumarin not detected"
exit 1
fi

echo "[+] Firmware:"
grep DISTRIB_DESCRIPTION /etc/openwrt_release || true

# Install dependencies if needed

for pkg in wget unzip; do
if ! command -v $pkg >/dev/null 2>&1; then
echo "[+] Installing $pkg ..."
apk add $pkg || true
fi
done

# Prepare workspace

echo "[+] Cleaning workspace..."
rm -rf "$TMP"
mkdir -p "$TMP"

# Download package

echo "[+] Downloading VWRT package..."
wget --no-check-certificate -O "$TMP/vwrt.zip" "$REPO"

# Verify download

if [ ! -f "$TMP/vwrt.zip" ]; then
echo "ERROR: Download failed"
exit 1
fi

SIZE=$(wc -c < "$TMP/vwrt.zip")

if [ "$SIZE" -lt 10000 ]; then
echo "ERROR: Invalid ZIP file"
exit 1
fi

echo "[+] Downloaded $SIZE bytes"

# Extract

echo "[+] Extracting..."
unzip -o "$TMP/vwrt.zip" -d "$TMP" >/dev/null

# Find dashboard source

SRC=$(find "$TMP" -name dashboard.html | head -n1 | xargs dirname)

if [ -z "$SRC" ]; then
echo "ERROR: dashboard.html not found"
find "$TMP" -type f | head
exit 1
fi

echo "[+] Source: $SRC"

# Backup

if [ -d /www/vwrt ]; then
rm -rf /tmp/vwrt-backup
cp -a /www/vwrt /tmp/vwrt-backup 2>/dev/null || true
fi

# Stop services

for svc in mobile_poller sms_sync vwrt_watchdog; do
if [ -x "/etc/init.d/$svc" ]; then
/etc/init.d/$svc stop || true
fi
done

# Install files

echo "[+] Installing dashboard..."
mkdir -p /www/vwrt
rm -rf /www/vwrt/*
cp -rf "$SRC"/* /www/vwrt/

# Remove dev files

rm -rf /www/vwrt/.git*
rm -rf /www/vwrt/.vscode
rm -rf /www/vwrt/dist
rm -f /www/vwrt/.DS_Store

# Permissions

chmod -R 755 /www/vwrt

find /www/vwrt/cgi-bin -type f -exec chmod +x {} ; 2>/dev/null || true

# Install services

if [ -d /www/vwrt/services/init.d ]; then

```
echo "[+] Installing init.d services..."

cp -f /www/vwrt/services/init.d/* /etc/init.d/

chmod +x /etc/init.d/mobile_poller 2>/dev/null || true
chmod +x /etc/init.d/sms_sync 2>/dev/null || true
chmod +x /etc/init.d/vwrt_watchdog 2>/dev/null || true

/etc/init.d/mobile_poller enable 2>/dev/null || true
/etc/init.d/sms_sync enable 2>/dev/null || true
/etc/init.d/vwrt_watchdog enable 2>/dev/null || true
```

fi

# LuCI integration

echo "[+] Creating LuCI links..."

mkdir -p /www/vwrt/cgi-bin

ln -snf /www/luci-static /www/vwrt/luci-static

if [ -f /www/cgi-bin/luci ]; then
ln -snf /www/cgi-bin/luci /www/vwrt/cgi-bin/luci
fi

# Configure uhttpd

echo "[+] Configuring uhttpd..."

uci set uhttpd.main.home='/www/vwrt'
uci commit uhttpd

/etc/init.d/uhttpd restart

# Start services

echo "[+] Starting services..."

for svc in mobile_poller sms_sync vwrt_watchdog; do
if [ -x "/etc/init.d/$svc" ]; then
/etc/init.d/$svc restart || true
fi
done

# Cleanup

rm -rf "$TMP"

LAN_IP=$(uci -q get network.lan.ipaddr)

echo
echo "========================================="
echo " Installation completed"
echo "========================================="

if [ -n "$LAN_IP" ]; then
echo
echo "Dashboard URL:"
echo "http://$LAN_IP"
fi

echo
echo "Useful commands:"
echo "logread | grep -Ei 'mobile|sms|vwrt'"
echo "ps | grep -E 'mobile_poller|sms_sync'"
echo
