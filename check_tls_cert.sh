#!/bin/bash
# Check TLS certificate details: expiry, chain, SANs, algorithms, and deprecated protocol support.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <FQDN> [port]"
    echo "  Default port: 443"
    echo "  Example: $0 google.com"
    echo "           $0 example.com 8443"
    exit 1
}

[ -z "$1" ] && usage

if ! command -v openssl &>/dev/null; then
    echo "Error: openssl is required." >&2; exit 1
fi

HOST="$1"
PORT="${2:-443}"

echo -e "${RED}Checking TLS certificate for $HOST:$PORT ...${NC}\n"

RAW=$(echo | openssl s_client -connect "$HOST:$PORT" -servername "$HOST" 2>/dev/null)
if [ -z "$RAW" ]; then
    echo "Error: Could not connect to $HOST:$PORT" >&2; exit 1
fi

CERT=$(echo "$RAW" | openssl x509 2>/dev/null)
if [ -z "$CERT" ]; then
    echo "Error: Could not parse certificate." >&2; exit 1
fi

# ── Certificate Info ──────────────────────────────────────────────────────────
echo -e "${CYAN}[*] Certificate Info${NC}"
SUBJECT=$(echo "$CERT" | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//')
ISSUER=$(echo  "$CERT" | openssl x509 -noout -issuer  2>/dev/null | sed 's/issuer=//')
printf "  %-16s %s\n" "Subject:"  "$SUBJECT"
printf "  %-16s %s\n" "Issuer:"   "$ISSUER"
[ "$SUBJECT" = "$ISSUER" ] && echo -e "  ${RED}[!] Self-signed certificate${NC}"

# ── Expiry ────────────────────────────────────────────────────────────────────
echo -e "\n${CYAN}[*] Validity${NC}"
NOT_BEFORE=$(echo "$CERT" | openssl x509 -noout -startdate 2>/dev/null | cut -d= -f2)
NOT_AFTER=$( echo "$CERT" | openssl x509 -noout -enddate  2>/dev/null | cut -d= -f2)
printf "  %-16s %s\n" "Valid From:"  "$NOT_BEFORE"
printf "  %-16s %s\n" "Valid Until:" "$NOT_AFTER"

# Days until expiry — use python3 for cross-platform date math
DAYS_LEFT=$(python3 -c "
from datetime import datetime
import sys
try:
    exp = datetime.strptime('$NOT_AFTER', '%b %d %H:%M:%S %Y %Z')
    print((exp - datetime.utcnow()).days)
except Exception as e:
    print('?')
" 2>/dev/null)

if [ "$DAYS_LEFT" = "?" ]; then
    echo -e "  ${YELLOW}[!] Could not calculate expiry days${NC}"
elif [ "$DAYS_LEFT" -lt 0 ] 2>/dev/null; then
    echo -e "  ${RED}[!] EXPIRED $(( DAYS_LEFT * -1 )) day(s) ago${NC}"
elif [ "$DAYS_LEFT" -lt 30 ] 2>/dev/null; then
    echo -e "  ${YELLOW}[!] Expires in $DAYS_LEFT day(s) — renew soon!${NC}"
else
    echo -e "  ${GREEN}[+] Expires in $DAYS_LEFT day(s)${NC}"
fi

# ── Subject Alternative Names ─────────────────────────────────────────────────
echo -e "\n${CYAN}[*] Subject Alternative Names${NC}"
SANS=$(echo "$CERT" | openssl x509 -noout -ext subjectAltName 2>/dev/null \
    | grep -v 'Subject Alternative' | tr ',' '\n' | sed 's/DNS://g; s/ //g; /^$/d')
if [ -n "$SANS" ]; then
    echo "$SANS" | while read -r san; do printf "  %s\n" "$san"; done
else
    echo "  None found."
fi

# ── Signature Algorithm & Key ─────────────────────────────────────────────────
echo -e "\n${CYAN}[*] Cryptography${NC}"
SIG_ALG=$(echo "$CERT" | openssl x509 -noout -text 2>/dev/null \
    | grep 'Signature Algorithm' | head -1 | awk '{print $3}')
printf "  %-20s " "Signature Algorithm:"
if echo "$SIG_ALG" | grep -qi "md5\|sha1WithRSA"; then
    echo -e "$SIG_ALG ${RED}[!] Weak — should be SHA-256 or better${NC}"
else
    echo -e "$SIG_ALG ${GREEN}[+]${NC}"
fi

KEY_BITS=$(echo "$CERT" | openssl x509 -noout -text 2>/dev/null \
    | grep 'Public-Key' | grep -o '[0-9]\+')
KEY_ALGO=$(echo "$CERT" | openssl x509 -noout -text 2>/dev/null \
    | grep 'Public Key Algorithm' | awk '{print $4}')
printf "  %-20s %s %s bits" "Public Key:" "$KEY_ALGO" "${KEY_BITS:-?}"
if [ -n "$KEY_BITS" ] && [ "$KEY_ALGO" = "rsaEncryption" ] && [ "$KEY_BITS" -lt 2048 ] 2>/dev/null; then
    echo -e " ${RED}[!] Weak key size${NC}"
else
    echo -e " ${GREEN}[+]${NC}"
fi

# ── Deprecated Protocol Support ───────────────────────────────────────────────
echo -e "\n${CYAN}[*] Protocol Support${NC}"
for proto in tls1 tls1_1 tls1_2 tls1_3; do
    result=$(echo | openssl s_client -connect "$HOST:$PORT" -"$proto" -servername "$HOST" 2>&1)
    if echo "$result" | grep -q 'Cipher is\|Protocol.*TLS'; then
        case "$proto" in
            tls1|tls1_1) printf "  %-10s ${RED}ENABLED (deprecated)${NC}\n" "$proto:" ;;
            *)            printf "  %-10s ${GREEN}Supported${NC}\n" "$proto:" ;;
        esac
    else
        case "$proto" in
            tls1|tls1_1) printf "  %-10s ${GREEN}Disabled${NC}\n" "$proto:" ;;
            *)            printf "  %-10s Not supported\n" "$proto:" ;;
        esac
    fi
done

# ── Chain Completeness ────────────────────────────────────────────────────────
echo -e "\n${CYAN}[*] Certificate Chain${NC}"
CHAIN_COUNT=$(echo "$RAW" | grep -c 'BEGIN CERTIFICATE')
printf "  Certificates in chain: %s" "$CHAIN_COUNT"
if [ "$CHAIN_COUNT" -lt 2 ]; then
    echo -e "  ${YELLOW}[!] Possibly incomplete (no intermediates sent)${NC}"
else
    echo -e "  ${GREEN}[+]${NC}"
fi
echo ""
