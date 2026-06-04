#!/bin/sh

set -e

REPO="https://github.com/Coumarin-26026/dashboard/raw/main/vwrt.zip"
TMP="/tmp/vwrt-installer"

echo "========================================="
echo " VWRT Dashboard Installer for Coumarin "
echo "========================================="
echo

# --------------------------------------------------

# Check root

# --------------------------------------------------

if [ "$(id -u)" != "0" ]; then
echo "ERROR: Run as root"
exit 1
fi

# --------------------------------------------------

# Install dependencies if missing

# --------------------------------------------------

for pkg in wget unzip; do
if ! command -v $pkg >/dev/null 2>&1; then
echo "[+] Installing $pkg ..."
apk add $pkg || true
fi
done

# --------------------------------------------------

# Check OpenWrt/Coumarin

# --------------------------------------------------

if [ ! -f /etc/openwrt_release ]; then
echo "ERROR: OpenWrt not detected"
exit 1
fi

echo "[+] Detected firmware:"
grep DISTRIB_DESCRIPTION /etc/openwrt_release || true

# --------------------------------------------------

# Prepare workspace

# --------------------------------------------------

echo "[+] Cleaning workspace..."

rm -rf "$TMP"
mkdir -p "$TMP"

# --------------------------------------------------

# Download package

# --------------------------------------------------

echo "[+] Downloading VWRT package..."

wget --no-check-certificate 
-O "$TMP/vwrt.zip" 
"$REPO"

# --------------------------------------------------

# Verify

# --------------------------------------------------

if [ ! -s "$TMP/vwrt.zip" ]; then
echo "ERROR: Download failed"
exit 1
fi

# --------------------------------------------------

# Extract

# --------------------------------------------------

echo "[+] Extracting..."

unzip -o "$TMP/vwrt.zip" -d "$TMP" >/dev/null

# --------------------------------------------------

# Locate source directory

# --------------------------------------------------

SRC="$(find "$TMP" -name dashboard.html | head -n1 | xargs dirname)"

if [ -z "$SRC" ]; then
echo "ERROR: dashboard.html not found"
exit 1
fi

echo "[+] Source found:"
echo "    $SRC"

# --------------------------------------------------

# Create target

# --------------------------------------------------

mkdir -p /www/vwrt

# --------------------------------------------------

# Backup old installation

# --------------------------------------------------

if [ -d /www/vwrt ]; then
rm -rf /tmp/vwrt-backup
cp -a /www/vwrt /tmp/vwrt-backup 2>/dev/null || true
fi

# --------------------------------------------------

# Stop services

# --------------------------------------------------

for svc in mobile_poller sms_sync vwrt_watchdog; do
[ -x "/etc/init.d/$svc" ] && /etc/init.d/$svc stop || true
done

# --------------------------------------------------

# Install files

# --------------------------------------------------

echo "[+] Installing files..."

rm -rf /www/vwrt/*
cp -rf "$SRC"/* /www/vwrt/

# --------------------------------------------------

# Remove development files

# --------------------------------------------------

rm -rf /www/vwrt/.git*
rm -rf /www/vwrt/.vscode
rm -rf /www/vwrt/dist
rm -f  /www/vwrt/.DS_Store

# --------------------------------------------------

# Fix permissions

# --------------------------------------------------

chmod -R 755 /www/vwrt

find /www/vwrt/cgi-bin -type f -exec chmod +x {} ; 2>/dev/null || true

find /www/vwrt/services -type f -name "*.sh" 
-exec chmod +x {} ; 2>/dev/null || true

# --------------------------------------------------

# Install init.d services

# --------------------------------------------------

if [ -d /www/vwrt/services/init.d ]; then

```
echo "[+] Installing services..."

cp -f /www/vwrt/services/init.d/* /etc/init.d/

chmod +x /etc/init.d/mobile_poller 2>/dev/null || true
chmod +x /etc/init.d/sms_sync 2>/dev/null || true
chmod +x /etc/init.d/vwrt_watchdog 2>/dev/null || true

/etc/init.d/mobile_poller enable 2>/dev/null || true
/etc/init.d/sms_sync enable 2>/dev/null || true
/etc/init.d/vwrt_watchdog enable 2>/dev/null || true
```

fi

# --------------------------------------------------

# LuCI integration

# --------------------------------------------------

mkdir -p /www/vwrt/cgi-bin

ln -snf /www/luci-static /www/vwrt/luci-static

if [ -f /www/cgi-bin/luci ]; then
ln -snf /www/cgi-bin/luci /www/vwrt/cgi-bin/luci
fi

# --------------------------------------------------

# Configure uhttpd

# --------------------------------------------------

echo "[+] Configuring uhttpd..."

uci set uhttpd.main.home='/www/vwrt'
uci commit uhttpd

/etc/init.d/uhttpd restart

# --------------------------------------------------

# Start services

# --------------------------------------------------

echo "[+] Starting services..."

/etc/init.d/mobile_poller restart 2>/dev/null || true
/etc/init.d/sms_sync restart 2>/dev/null || true
/etc/init.d/vwrt_watchdog restart 2>/dev/null || true

# --------------------------------------------------

# Cleanup

# --------------------------------------------------

rm -rf "$TMP"

echo
echo "========================================="
echo " Installation completed successfully"
echo "========================================="
echo

LAN_IP="$(uci -q get network.lan.ipaddr)"

if [ -n "$LAN_IP" ]; then
echo "Open:"
echo "http://$LAN_IP"
fi

echo
echo "Check status:"
echo "logread | grep -Ei 'mobile|sms|vwrt'"
echo
