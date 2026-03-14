#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <FQDN|IP> [port]"
    echo "  Default port: 443"
    echo "  Example: $0 google.com"
    echo "           $0 example.com 8443"
    exit 1
}

check_tool() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "${RED}[!] '$1' not found — skipping related checks.${NC}"
        return 1
    fi
    return 0
}

[ -z "$1" ] && usage

TARGET="$1"
PORT="${2:-443}"
SCHEME="https"
[ "$PORT" = "80" ] && SCHEME="http"

echo -e "${RED}Testing $TARGET on port $PORT ...${NC}"

if check_tool nmap; then
    echo -e "\n${GREEN}[*] WAF Detection${NC}"
    nmap -p"$PORT" --script http-waf-detect \
        --script-args="http-waf-detect.aggro,http-waf-detect.detectBodyChanges" "$TARGET"

    echo -e "\n${GREEN}[*] HTTP Headers${NC}"
    nmap --script http-headers -p "$PORT" "$TARGET"

    echo -e "\n${GREEN}[*] Security Headers${NC}"
    nmap --script http-security-headers -p "$PORT" "$TARGET"

    echo -e "\n${GREEN}[*] SSL/TLS Ciphers${NC}"
    nmap --script ssl-enum-ciphers -p "$PORT" "$TARGET"
fi

if check_tool wafw00f; then
    echo -e "\n${GREEN}[*] WAF Fingerprinting (wafw00f)${NC}"
    wafw00f "${SCHEME}://${TARGET}"
fi
