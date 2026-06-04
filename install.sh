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
echo

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
echo "[+] Backing up existing installation..."
rm -rf /tmp/vwrt-backup
cp -a /www/vwrt /tmp/vwrt-backup || true
fi

# Stop services

for svc in mobile_poller sms_sync vwrt_watchdog; do
[ -x "/etc/init.d/$svc" ] && /etc/init.d/$svc stop || true
done

# Install files

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

    /etc/init.d/$svc enable 2>/dev/null || true

done
```

fi

# LuCI links

mkdir -p /www/vwrt/cgi-bin

if [ -d /www/luci-static ]; then
ln -snf /www/luci-static /www/vwrt/luci-static
fi

if [ -f /www/cgi-bin/luci ]; then
ln -snf /www/cgi-bin/luci /www/vwrt/cgi-bin/luci
fi

# Detect webserver

echo "[+] Detecting webserver..."

if pidof nginx >/dev/null 2>&1; then
WEBSERVER="nginx"
elif pidof uhttpd >/dev/null 2>&1; then
WEBSERVER="uhttpd"
else
WEBSERVER="none"
fi

echo "[+] Current webserver: $WEBSERVER"

# Switch nginx -> uhttpd

if [ "$WEBSERVER" = "nginx" ]; then

```
echo "[+] nginx detected"
echo "[+] Switching to uhttpd..."

if command -v apk >/dev/null 2>&1; then
    apk add uhttpd >/dev/null 2>&1 || true
fi

/etc/init.d/nginx stop 2>/dev/null || true
/etc/init.d/nginx disable 2>/dev/null || true

/etc/init.d/uhttpd enable 2>/dev/null || true
```

fi

# Configure uhttpd

if command -v uci >/dev/null 2>&1; then

```
echo "[+] Configuring uhttpd..."

uci set uhttpd.main.home='/www/vwrt'
uci set uhttpd.main.cgi_prefix='/cgi-bin'
uci commit uhttpd

/etc/init.d/uhttpd restart || true
```

fi

# Start services

for svc in mobile_poller sms_sync vwrt_watchdog; do

```
if [ -x "/etc/init.d/$svc" ]; then
    /etc/init.d/$svc start 2>/dev/null || true
fi
```

done

sleep 2

# CGI test

echo "[+] Testing CGI..."

if wget -qO- http://127.0.0.1/cgi-bin/system/version >/dev/null 2>&1; then
echo "[OK] CGI working"
else
echo "[WARNING] CGI test failed"
fi

# Cleanup

rm -rf "$TMP"

IP="$(uci -q get network.lan.ipaddr 2>/dev/null)"

[ -n "$IP" ] || IP="192.168.1.1"

echo
echo "[+] Installation completed"
echo "[+] Dashboard: http://$IP/dashboard.html"
echo "[+] API Test : http://$IP/cgi-bin/system/info"
echo
