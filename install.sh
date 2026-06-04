#!/bin/sh

set -e

REPO="https://raw.githubusercontent.com/Coumarin-26026/dashboard/main/vwrt.zip"
TMP="/tmp/vwrt-installer"

echo "========================================="
echo " VWRT Dashboard Installer"
echo "========================================="
echo

# Check root

[ "$(id -u)" = "0" ] || {
echo "ERROR: Run as root"
exit 1
}

# Check firmware

[ -f /etc/openwrt_release ] || {
echo "ERROR: OpenWrt/Coumarin not found"
exit 1
}

echo "[+] Firmware detected:"
grep DISTRIB_DESCRIPTION /etc/openwrt_release || true

# Check tools

for cmd in wget unzip; do
command -v "$cmd" >/dev/null 2>&1 || {
echo "ERROR: Missing $cmd"
exit 1
}
done

# Workspace

echo "[+] Preparing..."
rm -rf "$TMP"
mkdir -p "$TMP"

# Download

echo "[+] Downloading package..."
wget --no-check-certificate -O "$TMP/vwrt.zip" "$REPO"

[ -f "$TMP/vwrt.zip" ] || {
echo "ERROR: Download failed"
exit 1
}

SIZE=$(wc -c < "$TMP/vwrt.zip")

[ "$SIZE" -gt 10000 ] || {
echo "ERROR: Invalid ZIP"
exit 1
}

echo "[+] ZIP size: $SIZE bytes"

# Extract

echo "[+] Extracting..."
unzip -oq "$TMP/vwrt.zip" -d "$TMP"

SRC=$(find "$TMP" -name dashboard.html | head -n1 | xargs dirname)

[ -n "$SRC" ] || {
echo "ERROR: dashboard.html not found"
exit 1
}

echo "[+] Source: $SRC"

# Backup

if [ -d /www/vwrt ]; then
rm -rf /tmp/vwrt-backup
cp -a /www/vwrt /tmp/vwrt-backup || true
fi

# Stop services

for svc in mobile_poller sms_sync vwrt_watchdog; do
[ -x "/etc/init.d/$svc" ] && /etc/init.d/$svc stop || true
done

# Install

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

[ -d /www/vwrt/cgi-bin ] && chmod -R 755 /www/vwrt/cgi-bin
[ -d /www/vwrt/services ] && chmod -R 755 /www/vwrt/services

# Install init scripts

if [ -d /www/vwrt/services/init.d ]; then

```
echo "[+] Installing services..."

cp -f /www/vwrt/services/init.d/* /etc/init.d/ 2>/dev/null || true

for svc in mobile_poller sms_sync vwrt_watchdog; do
    [ -f "/etc/init.d/$svc" ] || continue

    chmod +x "/etc/init.d/$svc"

    /etc/init.d/$svc enable || true
done
```

fi

# LuCI links

mkdir -p /www/vwrt/cgi-bin

[ -d /www/luci-static ] && 
ln -snf /www/luci-static /www/vwrt/luci-static

[ -f /www/cgi-bin/luci ] && 
ln -snf /www/cgi-bin/luci /www/vwrt/cgi-bin/luci

# uhttpd

if command -v uci >/dev/null 2>&1; then

```
echo "[+] Configuring uhttpd..."

uci set uhttpd.main.home='/www/vwrt'
uci commit uhttpd

/etc/init.d/uhttpd restart || true
```

fi

# Start services

for svc in mobile_poller sms_sync vwrt_watchdog; do
[ -x "/etc/init.d/$svc" ] && 
/etc/init.d/$svc restart || true
done

# Cleanup

rm -rf "$TMP"

echo
echo "========================================="
echo " Installation completed "
echo "========================================="
echo

LAN_IP=$(uci -q get network.lan.ipaddr)

if [ -n "$LAN_IP" ]; then
echo "Dashboard:"
echo "http://$LAN_IP"
fi

echo
echo "Check status:"
echo "logread | grep -Ei 'mobile|sms|vwrt'"
echo
