#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
#
# egress - the robot reaches the web from another country than the one it is served from.
#
# The service stays where it is. A second, small machine in the chosen country is the
# robot's only way out: everything the service's user sends leaves through it, pages,
# what they load, robots.txt, the names they look up. A site that asks consent by
# country then shows the robot what it shows a visitor from that country.
#
# Visitors never reach that machine. It holds no data and no key but its own, keeps no
# log, and answers no one but the service's machine.
#
#   sudo bash serve/egress.sh key                         each machine: its public key
#   sudo bash serve/egress.sh exit   ORIGIN_IP ORIGIN_KEY on the way out
#   sudo bash serve/egress.sh origin EXIT_IP   EXIT_KEY   on the service's machine
#   sudo bash serve/egress.sh check  EXIT_IP              on the service's machine
#
# Then the records say where the robot stands: sudo bash serve/install.sh ... --from FR
#
# If the tunnel is down, what the robot sends goes nowhere. It is never sent from the
# service's machine instead.
set -euo pipefail

port=51820 table=51820
exit_addr=10.80.0.1 origin_addr=10.80.0.2
# Names are looked up through the tunnel, at a resolver that keeps no record of who asks.
resolvers=(9.9.9.9 149.112.112.112)
denied="0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4"
key=/etc/wireguard/egress.key

usage() { sed -n '15,18p' "$0" | sed 's/^# //' >&2; exit 2; }
fail() { echo "egress: $*" >&2; exit 1; }
address() { [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || fail "$1 is not an IPv4 address"; }
public_key() { [[ $1 =~ ^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=$ ]] || fail "$1 is not a WireGuard public key"; }
[ "$(id -u)" = 0 ] || fail "to be run as root"

tools() {
    export DEBIAN_FRONTEND=noninteractive
    command -v wg >/dev/null && command -v nft >/dev/null && return
    apt-get update -qq
    apt-get install -y -qq wireguard-tools nftables >/dev/null
}

own_key() {
    tools
    install -d -m 0700 /etc/wireguard
    [ -s $key ] || (umask 077 && wg genkey > $key)
    wg pubkey < $key
}

way_out() {
    local origin=${1:?} peer=${2:?} wan
    address "$origin"; public_key "$peer"
    own_key >/dev/null
    apt-get update -qq
    apt-get install -y -qq unattended-upgrades >/dev/null
    wan=$(ip -4 route show default | awk '{for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit }}')
    [ -n "$wan" ] || fail "no IPv4 default route: this machine needs a public IPv4 address"

    echo "No log: the journal is kept nowhere, and nothing is passed on to a syslog."
    install -d /etc/systemd/journald.conf.d
    printf '[Journal]\nStorage=none\nForwardToSyslog=no\nForwardToWall=no\n' > /etc/systemd/journald.conf.d/egress.conf
    systemctl restart systemd-journald
    journalctl --rotate -q 2>/dev/null || true
    journalctl --vacuum-time=1s -q 2>/dev/null || true
    for s in rsyslog syslog-ng; do systemctl disable --now -q "$s" 2>/dev/null || true; done

    echo "Forwarding, for the service's machine only."
    printf 'net.ipv4.ip_forward=1\n' > /etc/sysctl.d/90-egress.conf
    sysctl -q -p /etc/sysctl.d/90-egress.conf

    cat > /etc/nftables.conf <<RULES
#!/usr/sbin/nft -f
# Written by relevé's serve/egress.sh. Nothing here logs.
flush ruleset
table inet egress {
	chain input {
		type filter hook input priority 0; policy drop;
		iif lo accept
		ct state established,related accept
		# Only the service's machine is answered: the tunnel, and SSH from it.
		ip saddr $origin udp dport $port accept
		ip saddr $origin tcp dport 22 accept
	}
	chain forward {
		type filter hook forward priority 0; policy drop;
		# Segments sized to the tunnel, for sites whose path MTU discovery is broken.
		tcp flags syn / syn,rst tcp option maxseg size set rt mtu
		ct state established,related accept
		# The second lock on private addresses: the robot reaches the open web only.
		iifname "wg0" ip daddr { ${denied// /, } } drop
		iifname "wg0" ip saddr $origin_addr oifname "$wan" accept
	}
}
table ip egress_nat {
	chain postrouting {
		type nat hook postrouting priority 100;
		ip saddr $origin_addr oifname "$wan" masquerade
	}
}
RULES
    cat > /etc/wireguard/wg0.conf <<CONF
# Written by relevé's serve/egress.sh: the way out.
[Interface]
Address = $exit_addr/30
ListenPort = $port
PostUp = wg set %i private-key $key

[Peer]
PublicKey = $peer
AllowedIPs = $origin_addr/32
CONF
    chmod 0600 /etc/wireguard/wg0.conf
    echo "From here on this machine answers $origin only. Reach it through that machine,"
    echo "as ssh -J <you>@$origin root@<this machine>, or through the provider's console."
    systemctl enable -q --now nftables
    nft -f /etc/nftables.conf
    systemctl enable -q wg-quick@wg0
    systemctl restart wg-quick@wg0
    echo
    echo "The way out is ready on $(ip -4 -o addr show dev "$wan" | awk '{print $4}' | cut -d/ -f1):$port."
    echo "This machine's key, for the service's machine: $(wg pubkey < $key)"
}

service_side() {
    local exit_ip=${1:?} peer=${2:?} uid
    address "$exit_ip"; public_key "$peer"
    uid=$(id -u releve 2>/dev/null) || fail "no user releve: install the service first (serve/install.sh)"
    own_key >/dev/null

    echo "The lock: what the user releve sends leaves through the tunnel, or not at all."
    cat > /usr/local/sbin/releve-egress-lock <<LOCK
#!/bin/sh
# Written by relevé's serve/egress.sh. Without the tunnel, the robot's packets meet a blackhole.
set -e
for v in -4 -6; do
	# A machine without IPv6 has no IPv6 way around the tunnel.
	[ "\$v" = -6 ] && [ ! -e /proc/net/if_inet6 ] && continue
	ip \$v rule del uidrange $uid-$uid lookup $table 2>/dev/null || true
	ip \$v rule add uidrange $uid-$uid lookup $table priority 100
	ip \$v route replace blackhole default table $table metric 4096
done
LOCK
    chmod 0755 /usr/local/sbin/releve-egress-lock
    cat > /etc/systemd/system/releve-egress-lock.service <<UNIT
[Unit]
Description=relevé's robot leaves through the egress tunnel, or not at all
DefaultDependencies=no
Before=network-pre.target wg-quick@wg0.service releve.service
Wants=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/releve-egress-lock

[Install]
WantedBy=multi-user.target
UNIT
    # A drop-in: serve/install.sh rewrites the service's unit, never this.
    install -d /etc/systemd/system/releve.service.d /etc/releve-egress
    { echo "# Written by relevé's serve/egress.sh."; printf 'nameserver %s\n' "${resolvers[@]}"; } > /etc/releve-egress/resolv.conf
    { echo "# Written by relevé's serve/egress.sh: names from files, then the resolvers above, nothing else."; echo "hosts: files dns"; grep -v '^hosts:' /etc/nsswitch.conf; } > /etc/releve-egress/nsswitch.conf
    cat > /etc/systemd/system/releve.service.d/egress.conf <<DROP
# Written by relevé's serve/egress.sh.
[Unit]
Requires=releve-egress-lock.service
After=releve-egress-lock.service wg-quick@wg0.service
Wants=wg-quick@wg0.service

[Service]
# The robot asks its names of the resolvers above, from its own sockets, through the tunnel
# like the rest. The local resolver (systemd-resolved) would ask them from this machine's
# address instead: its stub address is refused, and its socket is not there to be found.
BindReadOnlyPaths=/etc/releve-egress/resolv.conf:/etc/resolv.conf /etc/releve-egress/nsswitch.conf:/etc/nsswitch.conf
InaccessiblePaths=-/run/systemd/resolve
IPAddressDeny=127.0.0.53/32 127.0.0.54/32
DROP
    cat > /etc/wireguard/wg0.conf <<CONF
# Written by relevé's serve/egress.sh: the service's side.
[Interface]
Address = $origin_addr/30
Table = off
PostUp = wg set %i private-key $key
PostUp = ip -4 route replace default dev %i table $table metric 1
PreDown = ip -4 route del default dev %i table $table metric 1 || true

[Peer]
PublicKey = $peer
Endpoint = $exit_ip:$port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CONF
    chmod 0600 /etc/wireguard/wg0.conf
    systemctl daemon-reload
    systemctl enable -q --now releve-egress-lock
    systemctl restart releve-egress-lock
    systemctl enable -q wg-quick@wg0
    systemctl restart wg-quick@wg0
    ! systemctl is-active -q releve || systemctl restart releve
    echo
    echo "This machine's key, for the way out: $(wg pubkey < $key)"
    echo "Then: sudo bash serve/egress.sh check $exit_ip"
}

check() {
    local exit_ip=${1:?} here seen country v6 n=0
    address "$exit_ip"
    id releve >/dev/null 2>&1 || fail "no user releve"
    # As the service's user, with the service's resolver and its lock on private addresses.
    as_robot() {
        systemd-run --wait --pipe --quiet --collect -p User=releve \
            -p BindReadOnlyPaths="/etc/releve-egress/resolv.conf:/etc/resolv.conf /etc/releve-egress/nsswitch.conf:/etc/nsswitch.conf" \
            -p InaccessiblePaths=-/run/systemd/resolve \
            -p IPAddressDeny="$denied" -- "$@"
    }
    verdict() { if [ "$1" = yes ]; then echo "ok    $2"; else echo "FAIL  $2"; n=$((n + 1)); fi; }

    here=$(curl -4 -s -m 10 https://api.ipify.org || echo none)
    seen=$(as_robot curl -4 -s -m 20 https://api.ipify.org || echo none)
    country=$(as_robot curl -4 -s -m 20 https://ifconfig.co/country-iso || echo none)
    echo "This machine reaches the web as $here. The robot reaches it as $seen, in $country."
    verdict "$([ "$seen" = "$exit_ip" ] && echo yes)" "the robot leaves through $exit_ip"
    verdict "$([ "$seen" != "$here" ] && echo yes)" "the robot does not leave from this machine's address"
    verdict "$(as_robot getent ahostsv4 example.org >/dev/null && echo yes)" "the robot's names are looked up, through the tunnel"
    v6=$(as_robot curl -6 -s -m 8 https://api64.ipify.org 2>/dev/null || true)
    verdict "$([ -z "$v6" ] && echo yes)" "the robot has no IPv6 way around the tunnel"
    echo "The tunnel is taken down for a moment: nothing must get through."
    systemctl stop wg-quick@wg0
    seen=$(as_robot curl -4 -s -m 8 https://api.ipify.org 2>/dev/null || true)
    verdict "$([ -z "$seen" ] && echo yes)" "without the tunnel, no page is reached"
    verdict "$(as_robot getent ahostsv4 example.org >/dev/null 2>&1 || echo yes)" "without the tunnel, no name is looked up"
    systemctl start wg-quick@wg0
    sleep 3
    seen=$(as_robot curl -4 -s -m 20 https://api.ipify.org || echo none)
    verdict "$([ "$seen" = "$exit_ip" ] && echo yes)" "with the tunnel back, the robot leaves through $exit_ip again"
    [ "$n" = 0 ] || fail "$n checks did not pass"
    echo "All checks passed."
}

case ${1:-} in
    key) own_key ;;
    exit) way_out "${@:2}" ;;
    origin) service_side "${@:2}" ;;
    check) check "${@:2}" ;;
    *) usage ;;
esac
