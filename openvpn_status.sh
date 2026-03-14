#!/bin/bash
# Display connected OpenVPN users from the status log.
# Override log path with: OPENVPN_STATUS_LOG=/path/to/status.log

LOG_FILE="${OPENVPN_STATUS_LOG:-/var/log/openvpn/status.log}"
BORDER="============================================================"

if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Log file not found: $LOG_FILE" >&2
    echo "Set OPENVPN_STATUS_LOG to override the path." >&2
    exit 1
fi

echo "$BORDER"
echo " Connected VPN Users"
echo "$BORDER"
printf " %-20s %-22s %-16s %s\n" "USERNAME" "REAL ADDRESS" "VPN ADDRESS" "CONNECTED SINCE"
echo "$BORDER"

CLIENTS=$(grep '^CLIENT_LIST' "$LOG_FILE" | awk -F, '{printf " %-20s %-22s %-16s %s\n", $2, $3, $4, $8}')

if [ -z "$CLIENTS" ]; then
    echo " No clients currently connected."
else
    echo "$CLIENTS"
    COUNT=$(grep -c '^CLIENT_LIST' "$LOG_FILE")
    echo "$BORDER"
    echo " Total connected: $COUNT"
fi

echo "$BORDER"
