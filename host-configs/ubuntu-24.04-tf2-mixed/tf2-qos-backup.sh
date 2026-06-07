#!/usr/bin/env bash
set -euo pipefail

STAMP="$(date +%F-%H%M%S)"
OUT_DIR="${1:-/root/network-backups}"
OUT_FILE="${OUT_DIR}/tf2-network-backup-${STAMP}.txt"

mkdir -p "${OUT_DIR}"

{
    echo "# TF2 mixed-host network backup"
    echo "# Generated at: $(date --iso-8601=seconds)"
    echo

    echo "## Routing"
    ip route show
    echo

    echo "## Interfaces"
    ip -br a
    echo

    echo "## Relevant sysctl"
    sysctl \
        vm.swappiness \
        vm.vfs_cache_pressure \
        net.core.default_qdisc \
        net.core.rmem_default \
        net.core.wmem_default \
        net.core.rmem_max \
        net.core.wmem_max \
        net.core.netdev_max_backlog \
        net.ipv4.udp_rmem_min \
        net.ipv4.udp_wmem_min \
        net.ipv4.tcp_congestion_control \
        net.ipv4.tcp_fastopen \
        net.ipv4.tcp_slow_start_after_idle \
        net.ipv4.tcp_tw_reuse \
        net.ipv4.tcp_fin_timeout \
        net.ipv4.ip_local_port_range \
        net.netfilter.nf_conntrack_max \
        fs.file-max
    echo

    echo "## tc qdisc"
    tc -s qdisc show || true
    echo

    echo "## tc class"
    tc -s class show || true
    echo

    echo "## tc filter"
    tc -s filter show dev "$(ip route get 1.1.1.1 | awk '/dev/ {for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')" || true
    echo

    echo "## iptables mangle"
    iptables-save -t mangle || true
    echo

    echo "## nft ruleset"
    nft list ruleset || true
    echo

    echo "## Docker info"
    docker info 2>/dev/null | egrep "Server Version|Logging Driver|Cgroup Driver|Cgroup Version|CPUs|Total Memory" || true
    echo

    echo "## Docker container ports"
    docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Ports}}\t{{.Names}}" || true
    echo
} > "${OUT_FILE}"

echo "Backup saved to ${OUT_FILE}"
