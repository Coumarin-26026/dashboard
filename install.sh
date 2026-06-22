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

echo "[+] Firmware:"
grep DISTRIB_DESCRIPTION /etc/openwrt_release || true
echo

# Required tools

for cmd in wget unzip; do
command -v "$cmd" >/dev/null 2>&1 || {
echo "ERROR: Missing $cmd"
exit 1
}
done

# Workspace

rm -rf "$TMP"
mkdir -p "$TMP"

echo "[+] Downloading package..."
wget --no-check-certificate -O "$TMP/vwrt.zip" "$REPO"

[ -s "$TMP/vwrt.zip" ] || {
echo "ERROR: Download failed"
exit 1
}

SIZE=$(wc -c < "$TMP/vwrt.zip")

if [ "$SIZE" -lt 10000 ]; then
echo "ERROR: Invalid ZIP"
exit 1
fi

echo "[+] ZIP size: $SIZE bytes"

# Extract

echo "[+] Extracting..."
unzip -oq "$TMP/vwrt.zip" -d "$TMP"

SRC="$(find "$TMP" -name dashboard.html | head -n1 | xargs dirname)"

if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
echo "ERROR: dashboard source not found"
exit 1
fi

echo "[+] Source: $SRC"

# Backup

if [ -d /www/vwrt ]; then
echo "[+] Backup existing installation..."
rm -rf /tmp/vwrt-backup
cp -a /www/vwrt /tmp/vwrt-backup || true
fi

# Stop services

for svc in mobile_poller sms_sync vwrt_watchdog; do
[ -x "/etc/init.d/$svc" ] && /etc/init.d/$svc stop || true
done

echo "[+] Installing dashboard..."

mkdir -p /www/vwrt
rm -rf /www/vwrt/*
cp -a "$SRC"/. /www/vwrt/

# Cleanup development files

rm -rf /www/vwrt/.git
rm -rf /www/vwrt/.github
rm -rf /www/vwrt/.vscode
rm -rf /www/vwrt/dist

# Permissions

chmod -R 755 /www/vwrt

# Install CGI

if [ -d "$SRC/cgi-bin" ]; then
echo "[+] Installing CGI..."


mkdir -p /www/cgi-bin

for d in "$SRC"/cgi-bin/*; do
    name="$(basename "$d")"

    # Never replace LuCI
    [ "$name" = "luci" ] && continue

    rm -rf "/www/cgi-bin/$name"
    cp -a "$d" /www/cgi-bin/
done

chmod -R 755 /www/cgi-bin


fi

# LuCI compatibility links

mkdir -p /www/vwrt/cgi-bin

if [ -d /www/luci-static ]; then
ln -snf /www/luci-static /www/vwrt/luci-static
fi

if [ -f /www/cgi-bin/luci ]; then
ln -snf /www/cgi-bin/luci /www/vwrt/cgi-bin/luci
fi

# Install services

if [ -d /www/vwrt/services/init.d ]; then


echo "[+] Installing services..."

cp -f /www/vwrt/services/init.d/* /etc/init.d/ 2>/dev/null || true

for svc in mobile_poller sms_sync vwrt_watchdog; do
    [ -f "/etc/init.d/$svc" ] || continue

    chmod +x "/etc/init.d/$svc"

    /etc/init.d/$svc enable 2>/dev/null || true
done

fi

# Detect web server

if pidof nginx >/dev/null 2>&1; then
WEBSERVER="nginx"
elif pidof uhttpd >/dev/null 2>&1; then
WEBSERVER="uhttpd"
else
WEBSERVER="none"
fi

echo "[+] Web server: $WEBSERVER"

# Configure uhttpd

if command -v uci >/dev/null 2>&1; then


echo "[+] Configuring uhttpd..."

uci set uhttpd.main.home='/www'
uci set uhttpd.main.cgi_prefix='/cgi-bin'

if [ "$WEBSERVER" = "nginx" ]; then
    uci set uhttpd.main.listen_http='0.0.0.0:8081'
    uci set uhttpd.main.listen_https='0.0.0.0:8443'
fi

uci commit uhttpd

/etc/init.d/uhttpd restart || true


fi

sleep 2

# Start services

for svc in mobile_poller sms_sync vwrt_watchdog; do
if [ -x "/etc/init.d/$svc" ]; then
/etc/init.d/$svc start 2>/dev/null || true
fi
done

# API test

PORT=80

if [ "$WEBSERVER" = "nginx" ]; then
PORT=8081
fi

echo "[+] Testing API..."

if wget -qO- "[http://127.0.0.1:$PORT/cgi-bin/csrf/get](http://127.0.0.1:$PORT/cgi-bin/csrf/get)" >/dev/null 2>&1; then
echo "[OK] CGI working"
else
echo "[WARNING] CGI test failed"
fi

# Cleanup

rm -rf "$TMP"

IP="$(uci -q get network.lan.ipaddr 2>/dev/null)"
[ -n "$IP" ] || IP="192.168.1.1"

echo
echo "========================================="
echo " Installation Complete"
echo "========================================="

if [ "$WEBSERVER" = "nginx" ]; then
echo "Dashboard:"
echo "http://$IP:8081/vwrt/dashboard.html"


echo
echo "API:"
echo "http://$IP:8081/cgi-bin/system/info"


else
echo "Dashboard:"
echo "http://$IP/vwrt/dashboard.html"


echo
echo "API:"
echo "http://$IP/cgi-bin/system/info"

fi

echo
