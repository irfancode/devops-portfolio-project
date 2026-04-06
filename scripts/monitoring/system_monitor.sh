#!/bin/bash
#
# System Resource Monitor
# Monitors CPU, memory, disk, and network usage
# Sends alerts when thresholds are exceeded
# Interview talking point: Linux administration, monitoring, alerting
#

set -euo pipefail

# Configuration
THRESHOLD_CPU=80
THRESHOLD_MEMORY=85
THRESHOLD_DISK=90
LOG_FILE="/var/log/system-monitor.log"
ALERT_EMAIL="admin@example.com"
CHECK_INTERVAL=60

# Colors for terminal output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

alert() {
    local level="$1"
    local message="$2"
    log "ALERT [$level]: $message"

    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "System Alert: $level" "$ALERT_EMAIL"
    fi

    case "$level" in
        CRITICAL) echo -e "${RED}[CRITICAL] $message${NC}" ;;
        WARNING)  echo -e "${YELLOW}[WARNING] $message${NC}" ;;
        OK)       echo -e "${GREEN}[OK] $message${NC}" ;;
    esac
}

check_cpu() {
    local cpu_idle
    cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'.' -f1 2>/dev/null || echo "100")
    local cpu_usage=$((100 - ${cpu_idle:-100}))

    if [ "$cpu_usage" -ge "$THRESHOLD_CPU" ]; then
        alert "CRITICAL" "CPU usage is at ${cpu_usage}% (threshold: ${THRESHOLD_CPU}%)"

        log "Top 5 CPU processes:"
        ps aux --sort=-%cpu | head -6 | while read -r line; do
            log "  $line"
        done
    else
        alert "OK" "CPU usage is at ${cpu_usage}%"
    fi

    echo "$cpu_usage"
}

check_memory() {
    local mem_info
    mem_info=$(free -m | grep Mem)
    local total=$(echo "$mem_info" | awk '{print $2}')
    local used=$(echo "$mem_info" | awk '{print $3}')
    local available=$(echo "$mem_info" | awk '{print $7}')
    local usage_percent=$((used * 100 / total))

    if [ "$usage_percent" -ge "$THRESHOLD_MEMORY" ]; then
        alert "CRITICAL" "Memory usage is at ${usage_percent}% (${used}MB/${total}MB)"

        log "Top 5 memory processes:"
        ps aux --sort=-%mem | head -6 | while read -r line; do
            log "  $line"
        done
    else
        alert "OK" "Memory usage is at ${usage_percent}% (${available}MB available)"
    fi

    echo "$usage_percent"
}

check_disk() {
    local alert_triggered=false

    df -h | grep -E '^/dev/' | while read -r filesystem size used avail use_pct mount; do
        local usage=${use_pct%\%}

        if [ "$usage" -ge "$THRESHOLD_DISK" ]; then
            alert "CRITICAL" "Disk usage on $mount is at ${use_pct} (${used}/${size})"
            alert_triggered=true

            log "Large files on $mount:"
            find "$mount" -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -5 | while read -r line; do
                log "  $line"
            done
        else
            alert "OK" "Disk usage on $mount is at ${use_pct}"
        fi
    done
}

check_load_average() {
    local load_avg
    load_avg=$(cat /proc/loadavg)
    local load_1=$(echo "$load_avg" | awk '{print $1}')
    local load_5=$(echo "$load_avg" | awk '{print $2}')
    local load_15=$(echo "$load_avg" | awk '{print $3}')
    local num_cores=$(nproc)

    local load_threshold=$(echo "$num_cores * 2" | bc)

    log "Load Average: $load_1 (1m), $load_5 (5m), $load_15 (15m) [Cores: $num_cores]"

    if (( $(echo "$load_1 > $load_threshold" | bc -l) )); then
        alert "WARNING" "High load average: $load_1 (threshold: $load_threshold for $num_cores cores)"
    fi
}

check_network() {
    local rx_bytes tx_bytes
    rx_bytes=$(cat /proc/net/dev | grep -E 'eth0|ens|enp' | head -1 | awk '{print $2}')
    tx_bytes=$(cat /proc/net/dev | grep -E 'eth0|ens|enp' | head -1 | awk '{print $10}')

    if [ -n "$rx_bytes" ]; then
        local rx_mb=$((rx_bytes / 1024 / 1024))
        local tx_mb=$((tx_bytes / 1024 / 1024))
        log "Network I/O - RX: ${rx_mb}MB, TX: ${tx_mb}MB"
    fi
}

check_docker() {
    if command -v docker &> /dev/null; then
        local running_containers
        running_containers=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
        local exited_containers
        exited_containers=$(docker ps -f status=exited --format '{{.Names}}' 2>/dev/null | wc -l)

        log "Docker: $running_containers running, $exited_containers exited"

        if [ "$exited_containers" -gt 5 ]; then
            alert "WARNING" "$exited_containers exited containers found. Consider cleanup."
        fi

        local image_size
        image_size=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1)
        log "Docker disk usage: $image_size"
    fi
}

generate_report() {
    log "=========================================="
    log "SYSTEM MONITORING REPORT"
    log "Hostname: $(hostname)"
    log "Uptime: $(uptime -p 2>/dev/null || uptime)"
    log "Kernel: $(uname -r)"
    log "=========================================="

    check_cpu > /dev/null
    check_memory > /dev/null
    check_disk
    check_load_average
    check_network
    check_docker

    log "=========================================="
    log "Report complete"
    log "=========================================="
}

cleanup_docker() {
    log "Running Docker cleanup..."
    docker system prune -f --volumes 2>/dev/null || true
    log "Docker cleanup complete"
}

main() {
    case "${1:-report}" in
        report)
            generate_report
            ;;
        watch)
            log "Starting continuous monitoring (interval: ${CHECK_INTERVAL}s)"
            while true; do
                generate_report
                sleep "$CHECK_INTERVAL"
            done
            ;;
        cleanup)
            cleanup_docker
            ;;
        *)
            echo "Usage: $0 {report|watch|cleanup}"
            exit 1
            ;;
    esac
}

main "$@"
