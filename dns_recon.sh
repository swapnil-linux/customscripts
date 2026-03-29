#!/bin/bash
# DNS reconnaissance: records enumeration, SPF/DMARC/DKIM, DNSSEC, zone transfer attempt.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <domain>"
    echo "  Example: $0 example.com"
    exit 1
}

[ -z "$1" ] && usage

if ! command -v dig &>/dev/null; then
    echo "Error: dig is required (install bind-utils / dnsutils)." >&2; exit 1
fi

DOMAIN="$1"
echo -e "${RED}DNS Recon for $DOMAIN${NC}\n"

section() { echo -e "${CYAN}[*] $1${NC}"; }
ok()   { echo -e "  ${GREEN}[+]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[!]${NC} $1"; }
bad()  { echo -e "  ${RED}[!]${NC} $1"; }
info() { echo "      $1"; }

# ── A / AAAA Records ──────────────────────────────────────────────────────────
section "A / AAAA Records"
A_RECORDS=$(dig +short A "$DOMAIN" 2>/dev/null)
AAAA_RECORDS=$(dig +short AAAA "$DOMAIN" 2>/dev/null)
if [ -n "$A_RECORDS" ]; then
    echo "$A_RECORDS" | while read -r r; do info "A     $r"; done
else
    warn "No A records found."
fi
[ -n "$AAAA_RECORDS" ] && echo "$AAAA_RECORDS" | while read -r r; do info "AAAA  $r"; done

# ── NS Records ────────────────────────────────────────────────────────────────
section "Nameservers"
NS_RECORDS=$(dig +short NS "$DOMAIN" 2>/dev/null)
if [ -n "$NS_RECORDS" ]; then
    echo "$NS_RECORDS" | while read -r r; do info "NS  $r"; done
else
    warn "No NS records found."
fi

# ── MX Records ────────────────────────────────────────────────────────────────
section "MX Records"
MX_RECORDS=$(dig +short MX "$DOMAIN" 2>/dev/null)
if [ -n "$MX_RECORDS" ]; then
    echo "$MX_RECORDS" | sort -n | while read -r r; do info "$r"; done
else
    warn "No MX records found."
fi

# ── TXT Records ───────────────────────────────────────────────────────────────
section "TXT Records"
TXT_RECORDS=$(dig +short TXT "$DOMAIN" 2>/dev/null)
if [ -n "$TXT_RECORDS" ]; then
    echo "$TXT_RECORDS" | while read -r r; do info "$r"; done
else
    warn "No TXT records found."
fi

# ── SPF ───────────────────────────────────────────────────────────────────────
section "SPF"
SPF=$(dig +short TXT "$DOMAIN" 2>/dev/null | grep -i 'v=spf1')
if [ -n "$SPF" ]; then
    ok "SPF record found:"
    info "$SPF"
    if echo "$SPF" | grep -q '+all'; then
        bad "SPF uses '+all' — allows any sender (very permissive!)"
    elif echo "$SPF" | grep -q '~all'; then
        warn "SPF uses '~all' (softfail) — consider using '-all'"
    elif echo "$SPF" | grep -q '-all'; then
        ok "SPF uses '-all' (hardfail)"
    fi
else
    bad "No SPF record found — domain is vulnerable to email spoofing."
fi

# ── DMARC ─────────────────────────────────────────────────────────────────────
section "DMARC"
DMARC=$(dig +short TXT "_dmarc.$DOMAIN" 2>/dev/null | grep -i 'v=DMARC1')
if [ -n "$DMARC" ]; then
    ok "DMARC record found:"
    info "$DMARC"
    if echo "$DMARC" | grep -qi 'p=none'; then
        warn "DMARC policy is 'none' — monitoring only, no enforcement."
    elif echo "$DMARC" | grep -qi 'p=quarantine'; then
        ok "DMARC policy is 'quarantine'."
    elif echo "$DMARC" | grep -qi 'p=reject'; then
        ok "DMARC policy is 'reject' (strongest)."
    fi
else
    bad "No DMARC record found (_dmarc.$DOMAIN)."
fi

# ── DKIM (common selectors) ───────────────────────────────────────────────────
section "DKIM (common selectors)"
DKIM_FOUND=0
for selector in default google amazon selector1 selector2 k1 dkim mail; do
    DKIM=$(dig +short TXT "${selector}._domainkey.$DOMAIN" 2>/dev/null | grep -i 'v=DKIM1\|k=rsa\|p=')
    if [ -n "$DKIM" ]; then
        ok "DKIM found — selector: $selector"
        DKIM_FOUND=1
    fi
done
[ "$DKIM_FOUND" -eq 0 ] && warn "No DKIM records found for common selectors."

# ── DNSSEC ────────────────────────────────────────────────────────────────────
section "DNSSEC"
DS=$(dig +short DS "$DOMAIN" 2>/dev/null)
DNSKEY=$(dig +short DNSKEY "$DOMAIN" 2>/dev/null)
if [ -n "$DS" ] || [ -n "$DNSKEY" ]; then
    ok "DNSSEC appears to be enabled."
    [ -n "$DS" ]     && info "DS record present"
    [ -n "$DNSKEY" ] && info "DNSKEY record present"
else
    warn "DNSSEC does not appear to be configured."
fi

# ── Zone Transfer Attempt ─────────────────────────────────────────────────────
section "Zone Transfer (AXFR)"
ZONE_XFER_VULN=0
echo "$NS_RECORDS" | while read -r ns; do
    [ -z "$ns" ] && continue
    AXFR=$(dig AXFR "$DOMAIN" "@$ns" 2>/dev/null)
    if echo "$AXFR" | grep -q 'Transfer failed\|connection refused\|communications error\|REFUSED'; then
        info "$(printf '%-40s' "$ns") Refused (good)"
    elif echo "$AXFR" | grep -qE 'IN\s+SOA|IN\s+A'; then
        echo -e "  ${RED}[!] Zone transfer SUCCEEDED on $ns — fix this!${NC}"
    else
        info "$(printf '%-40s' "$ns") No response / inconclusive"
    fi
done

# ── SOA Record ────────────────────────────────────────────────────────────────
section "SOA Record"
SOA=$(dig +short SOA "$DOMAIN" 2>/dev/null)
[ -n "$SOA" ] && info "$SOA" || warn "No SOA record found."

echo ""
