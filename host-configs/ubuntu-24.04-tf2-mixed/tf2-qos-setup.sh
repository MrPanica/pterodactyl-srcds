#!/usr/bin/env bash
set -euo pipefail

IFACE="${IFACE:-$(ip route get 1.1.1.1 | awk '/dev/ {for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')}"
WAN_RATE="${WAN_RATE:-950mbit}"
TF2_PORTS="${TF2_PORTS:-27015:27030}"
WEB_PORTS="${WEB_PORTS:-80,443}"
CTRL_PORTS="${CTRL_PORTS:-22,8080,2022}"

echo "[*] Applying TF2 QoS on ${IFACE} with WAN_RATE=${WAN_RATE}"

modprobe sch_htb 2>/dev/null || true
modprobe cls_fw 2>/dev/null || true

tc qdisc replace dev "${IFACE}" root handle 1: htb default 30
tc class replace dev "${IFACE}" parent 1: classid 1:1 htb rate "${WAN_RATE}" ceil "${WAN_RATE}"

# High priority: TF2 gameplay traffic
tc class replace dev "${IFACE}" parent 1:1 classid 1:10 htb rate 20mbit ceil "${WAN_RATE}" prio 0
tc qdisc replace dev "${IFACE}" parent 1:10 handle 110: fq_codel quantum 1514

# Medium priority: SSH, Wings, panel control traffic
tc class replace dev "${IFACE}" parent 1:1 classid 1:20 htb rate 5mbit ceil "${WAN_RATE}" prio 1
tc qdisc replace dev "${IFACE}" parent 1:20 handle 120: fq_codel quantum 1514

# Default / lower priority: web + FastDL + everything else
tc class replace dev "${IFACE}" parent 1:1 classid 1:30 htb rate 10mbit ceil "${WAN_RATE}" prio 2
tc qdisc replace dev "${IFACE}" parent 1:30 handle 130: fq_codel quantum 1514

tc filter replace dev "${IFACE}" parent 1: protocol ip handle 10 fw flowid 1:10
tc filter replace dev "${IFACE}" parent 1: protocol ip handle 20 fw flowid 1:20
tc filter replace dev "${IFACE}" parent 1: protocol ip handle 30 fw flowid 1:30

iptables -t mangle -N TF2_QOS_EGRESS 2>/dev/null || true
iptables -t mangle -F TF2_QOS_EGRESS

iptables -t mangle -A TF2_QOS_EGRESS -p udp --sport "${TF2_PORTS}" -j MARK --set-mark 10
iptables -t mangle -A TF2_QOS_EGRESS -p tcp --sport "${TF2_PORTS}" -j MARK --set-mark 10
iptables -t mangle -A TF2_QOS_EGRESS -p tcp -m multiport --sport "${CTRL_PORTS}" -j MARK --set-mark 20
iptables -t mangle -A TF2_QOS_EGRESS -p tcp -m multiport --sport "${WEB_PORTS}" -j MARK --set-mark 30

for CHAIN in OUTPUT FORWARD; do
    iptables -t mangle -D "${CHAIN}" -o "${IFACE}" -j TF2_QOS_EGRESS 2>/dev/null || true
    iptables -t mangle -A "${CHAIN}" -o "${IFACE}" -j TF2_QOS_EGRESS
done

echo
echo "[*] tc qdisc:"
tc -s qdisc show dev "${IFACE}"
echo
echo "[*] tc class:"
tc -s class show dev "${IFACE}"
echo
echo "[*] iptables chain:"
iptables -t mangle -S TF2_QOS_EGRESS
