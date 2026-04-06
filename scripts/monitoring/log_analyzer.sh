#!/bin/bash
#
# Log Analyzer Script
# Parses application and system logs for errors, patterns, and anomalies
# Interview talking point: Log management, troubleshooting, text processing
#

set -euo pipefail

LOG_FILE="${1:-/var/log/syslog}"
OUTPUT_DIR="/tmp/log-analysis"
mkdir -p "$OUTPUT_DIR"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ ! -f "$LOG_FILE" ]; then
    echo -e "${RED}Error: Log file not found: $LOG_FILE${NC}"
    echo "Usage: $0 [log_file_path]"
    exit 1
fi

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}LOG ANALYSIS REPORT${NC}"
echo -e "${CYAN}File: $LOG_FILE${NC}"
echo -e "${CYAN}Date: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}========================================${NC}"

echo -e "\n${YELLOW}[1] Error Summary${NC}"
echo "---"
ERROR_COUNT=$(grep -ci "error\|fail\|critical\|fatal" "$LOG_FILE" 2>/dev/null || echo "0")
echo "Total error-level entries: $ERROR_COUNT"

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "\nTop error patterns:"
    grep -i "error\|fail\|critical\|fatal" "$LOG_FILE" 2>/dev/null | \
        sed 's/^[0-9-]* [0-9:]* //' | \
        sort | uniq -c | sort -rn | head -10 | \
        while read -r count msg; do
            printf "  %5d  %s\n" "$count" "$msg"
        done
fi

echo -e "\n${YELLOW}[2] Warning Summary${NC}"
echo "---"
WARN_COUNT=$(grep -ci "warn" "$LOG_FILE" 2>/dev/null || echo "0")
echo "Total warning entries: $WARN_COUNT"

echo -e "\n${YELLOW}[3] HTTP Status Codes (if applicable)${NC}"
echo "---"
HTTP_CODES=$(grep -oP 'HTTP/\d\.\d" \K\d{3}' "$LOG_FILE" 2>/dev/null || true)
if [ -n "$HTTP_CODES" ]; then
    echo "$HTTP_CODES" | sort | uniq -c | sort -rn | \
        while read -r count code; do
            case "$code" in
                2*) color="$GREEN" ;;
                3*) color="$CYAN" ;;
                4*) color="$YELLOW" ;;
                5*) color="$RED" ;;
                *)  color="$NC" ;;
            esac
            printf "  ${color}%5d  %s${NC}\n" "$count" "$code"
        done
else
    echo "No HTTP status codes found in log"
fi

echo -e "\n${YELLOW}[4] Top IP Addresses${NC}"
echo "---"
IPS=$(grep -oP '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$LOG_FILE" 2>/dev/null || true)
if [ -n "$IPS" ]; then
    echo "$IPS" | sort | uniq -c | sort -rn | head -10 | \
        while read -r count ip; do
            printf "  %5d  %s\n" "$count" "$ip"
        done
else
    echo "No IP addresses found"
fi

echo -e "\n${YELLOW}[5] Time Distribution (errors per hour)${NC}"
echo "---"
grep -i "error\|fail\|critical" "$LOG_FILE" 2>/dev/null | \
    grep -oP '\d{2}:\d{2}' | cut -d: -f1 | sort | uniq -c | \
    while read -r count hour; do
        bar=$(printf '%*s' "$((count / 2))" '' | tr ' ' '#')
        printf "  %02d:00  %5d  %s\n" "$hour" "$count" "$bar"
    done

echo -e "\n${YELLOW}[6] Recent Critical Events (last 20)${NC}"
echo "---"
grep -i "critical\|fatal\|panic\|oom" "$LOG_FILE" 2>/dev/null | tail -20 | \
    while read -r line; do
        echo -e "  ${RED}$line${NC}"
    done || echo "No critical events found"

echo -e "\n${YELLOW}[7] Log File Statistics${NC}"
echo "---"
TOTAL_LINES=$(wc -l < "$LOG_FILE")
FILE_SIZE=$(du -h "$LOG_FILE" | cut -f1)
DATE_RANGE=$(head -1 "$LOG_FILE" | grep -oP '^\S+ \S+' 2>/dev/null || echo "N/A")
echo "Total lines: $TOTAL_LINES"
echo "File size: $FILE_SIZE"
echo "First entry: $DATE_RANGE"

echo -e "\n${CYAN}========================================${NC}"
echo -e "${CYAN}Analysis complete. Report saved to: $OUTPUT_DIR${NC}"
echo -e "${CYAN}========================================${NC}"
