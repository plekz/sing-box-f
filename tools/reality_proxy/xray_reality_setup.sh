#!/usr/bin/env bash
set -euo pipefail

# Xray Reality front + sing-box socks backend helper
# - Installs Xray
# - Generates /etc/xray/config.json (Reality inbound @443 -> socks 127.0.0.1:10800)
# - Adds socks inbound to sing-box config if missing
# - Creates/starts systemd xray.service
#
# Env (required):
#   SB_CONFIG=/etc/sing-box/config.json
#   UUID=2b4f7f6d-5e2b-41ed-8d0c-6b2e2d6d6e2f
#   REALITY_PRIVATE_KEY=<base64url priv>
#   REALITY_SHORT_ID=<8hex or empty>
#   REALITY_SERVER_NAME=addons.mozilla.org
#   SOCKS_ADDR=127.0.0.1
#   SOCKS_PORT=10800

SB_CONFIG=${SB_CONFIG:-/etc/sing-box/config.json}
UUID=${UUID:?missing UUID}
RPRIV=${REALITY_PRIVATE_KEY:?missing REALITY_PRIVATE_KEY}
RSID=${REALITY_SHORT_ID:-}
RSNI=${REALITY_SERVER_NAME:-addons.mozilla.org}
SADDR=${SOCKS_ADDR:-127.0.0.1}
SPORT=${SOCKS_PORT:-10800}

echo "==> Install Xray"
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y unzip >/dev/null 2>&1 || true
cd /tmp && curl -fsSLo xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o xray.zip >/dev/null 2>&1
install -m 0755 xray /usr/local/bin/xray
mkdir -p /etc/xray

echo "==> Write /etc/xray/config.json (port 443)"
cat >/etc/xray/config.json <<JSON
{
  "log": {"loglevel": "debug"},
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {"decryption": "none", "clients": [{"id": "$UUID", "flow": "xtls-rprx-vision"}]},
    "streamSettings": {
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "$RSNI:443",
        "serverNames": ["$RSNI"],
        "privateKey": "$RPRIV",
        "shortIds": ["$RSID"]
      },
      "tlsSettings": {"alpn": ["h2","http/1.1"]}
    }
  }],
  "outbounds": [{
    "protocol": "socks",
    "settings": {"servers": [{"address": "$SADDR", "port": $SPORT }]}
  }]
}
JSON

echo "==> Ensure sing-box socks inbound ($SADDR:$SPORT) present"
python3 - <<'PY'
import json,sys
p=sys.argv[1]
with open(p) as f: m=json.load(f)
ibs=m.get('inbounds',[])
need=True
for ib in ibs:
    if ib.get('type')=='socks' and ib.get('listen')=='127.0.0.1' and ib.get('listen_port')==10800:
        need=False; break
if need:
    ibs.append({"type":"socks","tag":"socks-in","listen":"127.0.0.1","listen_port":10800})
    m['inbounds']=ibs
    with open(p,'w') as f: json.dump(m,f,separators=(',',':'))
    print('added socks inbound')
else:
    print('socks inbound exists')
PY
"$SB_CONFIG"

echo "==> systemd xray.service"
cat >/etc/systemd/system/xray.service <<'UNIT'
[Unit]
Description=Xray Service (Reality front)
After=network-online.target

[Service]
ExecStart=/usr/local/bin/xray -c /etc/xray/config.json
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now xray
sleep 1
systemctl is-active xray && echo "xray active" || (echo "xray failed"; journalctl -u xray --no-pager -n 50)

echo "==> Restart sing-box to load socks inbound"
systemctl restart sing-box || true
sleep 1
systemctl is-active sing-box && echo "sing-box active"

echo "==> Done"

