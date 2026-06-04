#!/bin/sh

set -e

REPO="https://raw.githubusercontent.com/Coumarin-26026/dashboard/main/vwrt.zip"
TMP="/tmp/vwrt-installer"

echo "========================================="
echo " VWRT Dashboard Installer"
echo "========================================="
echo

# Root check

if [ "$(id -u)" != "0" ]; then
echo "ERROR: Run as root"
exit 1
fi

# Firmware check

if [ ! -f /etc/openwrt_release ]; then
echo "ERROR: OpenWrt/Coumarin not found"
exit 1
fi

echo "[+] Firmware detected:"
grep DISTRIB_DESCRIPTION /etc/openwrt_release || true

# Required tools

for cmd in wget unzip; do
if ! command -v "$cmd" >/dev/null 2>&1; then
echo "ERROR: Missing $cmd"
exit 1
fi
done

echo "[+] Preparing..."
rm -rf "$TMP"
mkdir -p "$TMP"

echo "[+] Downloading package..."
wget --no-check-certificate -O "$TMP/vwrt.zip" "$REPO"

if [ ! -f "$TMP/vwrt.zip" ]; then
echo "ERROR: Download failed"
exit 1
fi

SIZE=$(wc -c < "$TMP/vwrt.zip")

if [ "$SIZE" -lt 10000 ]; then
echo "ERROR: Invalid ZIP"
exit 1
fi

echo "[+] ZIP size: $SIZE bytes"

echo "[+] Extracting..."
unzip -oq "$TMP/vwrt.zip" -d "$TMP"

SRC=$(find "$TMP" -name dashboard.html | head -n 1 | xargs dirname)

if [ -z "$SRC" ]; then
echo "ERROR: dashboard.html not found"
exit 1
fi

echo "[+] Source: $SRC"

# Compatibility check

if command -v mmcli >/dev/null 2>&1; then
echo "[+] ModemManager detected"
else
echo "[!] ModemManager not found"
fi

# Backup

if [ -d /www/vwrt ]; then
rm -rf /tmp/vwrt-backup
cp -a /www/vwrt /tmp/vwrt-backup || true
fi

# Stop services

for svc in mobile_poller sms_sync vwrt_watchdog; do
if [ -x "/etc/init.d/$svc" ]; then
/etc/init.d/$svc stop || true
fi
done

echo "[+] Installing files..."

mkdir -p /www/vwrt
rm -rf /www/vwrt/*
cp -rf "$SRC"/* /www/vwrt/

# Remove development files

rm -rf /www/vwrt/.git
rm -rf /www/vwrt/.github
rm -rf /www/vwrt/.vscode
rm -rf /www/vwrt/dist

# Permissions

chmod -R 755 /www/vwrt

if [ -d /www/vwrt/cgi-bin ]; then
chmod -R 755 /www/vwrt/cgi-bin
fi

if [ -d /www/vwrt/services ]; then
chmod -R 755 /www/vwrt/services
fi

# Install init scripts

if [ -d /www/vwrt/services/init.d ]; then
    echo "[+] Installing services..."

    cp -f /www/vwrt/services/init.d/* /etc/init.d/ 2>/dev/null || true

    chmod +x /etc/init.d/mobile_poller 2>/dev/null || true
    chmod +x /etc/init.d/sms_sync 2>/dev/null || true
    chmod +x /etc/init.d/vwrt_watchdog 2>/dev/null || true

    /etc/init.d/mobile_poller enable 2>/dev/null || true
    /etc/init.d/sms_sync enable 2>/dev/null || true
    /etc/init.d/vwrt_watchdog enable 2>/dev/null || true

    /etc/init.d/mobile_poller start 2>/dev/null || true
    /etc/init.d/sms_sync start 2>/dev/null || true
    /etc/init.d/vwrt_watchdog start 2>/dev/null || true
fi

```
cp -f /www/vwrt/services/init.d/* /etc/init.d/ 2>/dev/null || true

chmod +x /etc/init.d/mobile_poller 2>/dev/null || true
chmod +x /etc/init.d/sms_sync 2>/dev/null || true
chmod +x /etc/init.d/vwrt_watchdog 2>/dev/null || true

/etc/init.d/mobile_poller enable 2>/dev/null || true
/etc/init.d/sms_sync enable 2>/dev/null || true
/etc/init.d/vwrt_watchdog enable 2>/dev/null || true

/etc/init.d/mobile_poller start 2>/dev/null || true
/etc/init.d/sms_sync start 2>/dev/null || true
/etc/init.d/vwrt_watchdog start 2>/dev/null || true
```

fi

# LuCI symlinks

ln -snf /www/luci-static /www/vwrt/luci-static
ln -snf /www/cgi-bin/luci /www/vwrt/cgi-bin/luci

# uhttpd

if command -v uci >/dev/null 2>&1; then
uci set uhttpd.main.home='/www/vwrt'
uci commit uhttpd
/etc/init.d/uhttpd restart || true
fi

echo
echo "========================================="
echo " Installation completed"
echo "========================================="
echo
echo "Dashboard: http://$(uci -q get network.lan.ipaddr || echo 192.168.1.1)/"
echo
