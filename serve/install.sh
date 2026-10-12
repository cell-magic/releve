#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
#
# install — put the service on a machine given over to it, or renew it there.
#
#     sudo bash serve/install.sh NAME CONTACT [--look DIR] [--playwright VERSION]
#
#   NAME          the name the service answers to; its DNS record points here
#   CONTACT       the public page that says who runs the robot and how to refuse it
#   --look        a folder holding a page for each language (*.en.html, *.fr.html)
#                 to set the reports in, and what those pages need (static/)
#   --playwright  a newer Playwright than observe/requirements.txt names, which
#                 brings a newer browser. The checks decide whether it serves.
#
# For Ubuntu 24.04. In order, stopping at the first thing that fails:
#
#   1. the compiler, Python and the proxy (Caddy), from the system's packages;
#   2. relevé, built from the source this file sits in, in a folder of its own
#      under /opt/releve, with its browser;
#   3. relevé's three sets of checks, run there as the user the service runs as;
#   4. only then the service: a unit that keeps none of its output and is
#      confined to what it needs, behind a proxy that keeps no log of requests;
#   5. the running service is asked for the report of CONTACT. If none comes
#      back, the service returns to what it was before.
#
# Run again, from newer source or with a newer browser, it does the same, and
# the service keeps running as it was until step 4. The folder before the
# current one is kept, older ones are removed.
#
# What is not here: the browser's own sandbox. The browser is confined by the
# unit, as a user that owns nothing, on a machine that holds no data and no key.
set -euo pipefail

usage() { echo "usage: sudo bash $0 NAME CONTACT [--look DIR] [--playwright VERSION]" >&2; exit 2; }
[ $# -ge 2 ] || usage
name=$1 contact=$2 look='' playwright=''
shift 2
while [ $# -gt 0 ]; do
    case $1 in
        --look) look=$(cd "${2:?}" && pwd); shift 2 ;;
        --playwright) playwright=${2:?}; shift 2 ;;
        *) usage ;;
    esac
done
[[ $name =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]] || { echo "install: $name is not a name" >&2; exit 2; }
[[ $contact =~ ^https?://[A-Za-z0-9._~:/?#@=+,-]+$ ]] || { echo "install: $contact is not an address" >&2; exit 2; }
[ "$(id -u)" = 0 ] || { echo "install: to be run as root" >&2; exit 2; }

exec > >(tee -a /var/log/releve-install.log) 2>&1
say() { printf '\n== %s\n' "$*"; }
source=$(cd "$(dirname "$0")/.." && pwd)
home=/opt/releve
new=$home/$(date -u +%Y%m%dT%H%M%SZ)
previous=$(readlink -f $home/current 2>/dev/null || true)
serving=''
trap '[ -n "$serving" ] || rm -rf "$new"' EXIT  # what does not come to serve is not left lying
[ -n "$look" ] || [ ! -d "$previous/look" ] || look=$previous/look
# shellcheck source=/dev/null
. /etc/os-release
date -u +"install of %Y-%m-%d %H:%M UTC, for $name, on $PRETTY_NAME"
[ "$ID-$VERSION_ID" = ubuntu-24.04 ] || echo "Written for Ubuntu 24.04, and this is not it. Going on."

say "1. The system's packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ghc libghc-aeson-dev libghc-cryptohash-sha256-dev python3-venv caddy curl unattended-upgrades
id releve >/dev/null 2>&1 || useradd --system --user-group --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin releve

say "2. relevé, built from $source"
mkdir -p "$new"
cp -a "$source" "$new/src"
build=$(mktemp -d)
ghc -O1 -i"$new/src/kernel/src" "$new/src/kernel/app/Main.hs" -outputdir "$build" -o "$new/releve" >/dev/null
rm -rf "$build"
"$new/releve" --version
python3 -m venv "$new/venv"
if [ -n "$playwright" ]; then
    "$new/venv/bin/pip" install -q --disable-pip-version-check "playwright==$playwright"
else
    "$new/venv/bin/pip" install -q --disable-pip-version-check -r "$new/src/observe/requirements.txt"
fi
"$new/venv/bin/pip" show playwright | sed -n 's/^Version: /Playwright /p'
PLAYWRIGHT_BROWSERS_PATH=$new/browsers "$new/venv/bin/python" -m playwright install --with-deps chromium
[ -z "$look" ] || cp -a "$look" "$new/look"
chmod -R go+rX,go-w "$new"

say "3. The checks, as the user the service runs as"
for checks in run conduct service; do
    if out=$(cd "$new/src" && runuser -u releve -- env -i PATH=/usr/bin:/bin HOME=/tmp LANG=C.UTF-8 PYTHONDONTWRITEBYTECODE=1 \
             RELEVE="$new/releve" PLAYWRIGHT_BROWSERS_PATH="$new/browsers" "$new/venv/bin/python" "tests/$checks.py" 2>&1); then
        echo "tests/$checks.py: $(grep -c '^ok' <<<"$out") checks, all ok"
    else
        echo "$out"
        echo "tests/$checks.py did not pass. Nothing was changed: the service is as it was."
        exit 1
    fi
done

say "4. The service"
shells=''
for l in en fr; do
    for f in "$new"/look/*."$l".html; do [ ! -f "$f" ] || shells="$shells --shell $l=$home/current/look/${f##*/}"; done
done
[ ! -d "$new/look/static" ] || shells="$shells --static $home/current/look/static"
unit=/etc/systemd/system/releve.service proxy=/etc/caddy/Caddyfile
[ -e $proxy.before-releve ] || [ ! -e $proxy ] || cp -p $proxy $proxy.before-releve
for f in $unit $proxy; do [ ! -e "$f" ] || cp -p "$f" "$f.previous"; done
cat > $unit <<UNIT
[Unit]
Description=relevé behind a form: an address in, a report out, nothing kept
After=network-online.target
Wants=network-online.target

[Service]
User=releve
Environment=RELEVE=$home/current/releve PLAYWRIGHT_BROWSERS_PATH=$home/current/browsers HOME=/tmp PYTHONDONTWRITEBYTECODE=1
ExecStart=$home/current/venv/bin/python $home/current/src/serve/serve.py --contact $contact --counts /var/lib/releve/counts.json$shells
Restart=always
RestartSec=2
# Nothing the service or its browser says is kept.
StandardOutput=null
StandardError=null
# A page that tries to exhaust the machine ends the service, which starts again.
MemoryMax=1500M
# The second lock on private addresses. The first is in the service.
IPAddressDeny=10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 100.64.0.0/10 fc00::/7 fe80::/10
# Confined to what it needs: it reads its own folder, and writes only the weekly counts.
StateDirectory=releve
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectControlGroups=yes
RestrictSUIDSGID=yes
LockPersonality=yes
CapabilityBoundingSet=

[Install]
WantedBy=multi-user.target
UNIT
cat > $proxy <<PROXY
# Written by relevé's serve/install.sh.
{
	# No log of requests is kept. A request that fails would be logged with
	# the address of who made it: that is left out too.
	log {
		exclude http.log.error
	}
}

$name {
	encode zstd gzip
	header Strict-Transport-Security "max-age=31536000"
	header -Server
	request_body {
		max_size 3MB
	}
	reverse_proxy 127.0.0.1:8000
}
PROXY
install -d -o releve -g releve -m 0750 /var/lib/releve
ln -sfn "$new" $home/current
systemctl daemon-reload
systemctl enable -q releve caddy
systemctl restart releve
systemctl reload-or-restart caddy

say "5. The running service, asked for the report of $contact"
for _ in $(seq 30); do ! curl -s -o /dev/null -m 2 http://127.0.0.1:8000/ || break; sleep 1; done
answer=$(curl -s -m 150 -D /tmp/releve-install.head --data-urlencode "url=$contact" http://127.0.0.1:8000/ || true)
if [[ $answer == *'data:application/gzip;base64,'* ]] && ! grep -qi '^set-cookie' /tmp/releve-install.head; then
    echo "A report came back: $(echo "$answer" | sed -n 's:.*<title>\(.*\)</title>.*:\1:p' | head -n 1)"
    echo "It set no cookie."
else
    echo "No report came back. The service said:"
    echo "${answer:-nothing}" | sed -n '/<h1/,/<\/p>/p' | sed 's/<[^>]*>//g' | head -n 5
    if [ -n "$previous" ]; then
        ln -sfn "$previous" $home/current
        for f in $unit $proxy; do mv -f "$f.previous" "$f"; done
        systemctl daemon-reload
        systemctl restart releve
        systemctl reload-or-restart caddy
        echo "The service is back to what it was ($previous)."
    else
        systemctl disable -q --now releve
        rm -f $home/current
        echo "The service is stopped."
    fi
    echo "(If the reason is robots.txt: $contact has to admit the robot releve-observe.)"
    rm -f /tmp/releve-install.head
    exit 1
fi
serving=$new
rm -f /tmp/releve-install.head $unit.previous $proxy.previous
for d in "$home"/2*; do [ "$d" = "$new" ] || [ "$d" = "$previous" ] || rm -rf "$d"; done

say "6. By its name"
code=''
for _ in $(seq 12); do
    code=$(curl -s -o /dev/null -w '%{http_code}' -m 10 "https://$name/" || true)
    [ "$code" != 200 ] || break
    sleep 5
done
if [ "$code" = 200 ]; then
    echo "https://$name/ answers."
else
    echo "https://$name/ does not answer yet. The certificate is asked for once the name points"
    echo "at this machine and TCP 80 and 443 are open to it. Then: curl -I https://$name/"
fi
echo
echo "Done. What was printed here is also in /var/log/releve-install.log."
