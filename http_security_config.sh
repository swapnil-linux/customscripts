#!/bin/bash
# Check HTTP security misconfigurations: methods, headers, CORS, server banner, cookies, redirects.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <FQDN|IP> [port]"
    echo "  Default port: 443 (uses https). Port 80 uses http."
    echo "  Example: $0 example.com"
    echo "           $0 example.com 8080"
    exit 1
}

[ -z "$1" ] && usage

if ! command -v curl &>/dev/null; then
    echo "Error: curl is required." >&2; exit 1
fi

HOST="$1"
PORT="${2:-443}"
SCHEME="https"
[ "$PORT" = "80" ] && SCHEME="http"
URL="${SCHEME}://${HOST}"
[ "$PORT" != "443" ] && [ "$PORT" != "80" ] && URL="${SCHEME}://${HOST}:${PORT}"

echo -e "${RED}HTTP Security Config Check: $URL${NC}\n"

section() { echo -e "${CYAN}[*] $1${NC}"; }
ok()   { echo -e "  ${GREEN}[+]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[!]${NC} $1"; }
bad()  { echo -e "  ${RED}[!]${NC} $1"; }

# Fetch headers once for reuse
HEADERS=$(curl -sk -I --max-time 10 "$URL" 2>/dev/null)
if [ -z "$HEADERS" ]; then
    echo "Error: Could not reach $URL" >&2; exit 1
fi

get_header() { echo "$HEADERS" | grep -i "^$1:" | head -1 | cut -d: -f2- | sed 's/^ *//;s/\r//'; }

# ── HTTP → HTTPS Redirect ─────────────────────────────────────────────────────
if [ "$SCHEME" = "https" ]; then
    section "HTTP → HTTPS Redirect"
    HTTP_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 10 "http://$HOST" 2>/dev/null)
    LOCATION=$(curl -sk -I --max-time 10 "http://$HOST" 2>/dev/null | grep -i '^location:' | head -1 | tr -d '\r\n' | cut -d: -f2-)
    if echo "$HTTP_STATUS" | grep -q '^30'; then
        if echo "$LOCATION" | grep -qi 'https'; then
            ok "Redirects HTTP → HTTPS (status $HTTP_STATUS)"
        else
            warn "Redirects but not to HTTPS: $LOCATION"
        fi
    else
        bad "No HTTP → HTTPS redirect (status $HTTP_STATUS)"
    fi
fi

# ── Server Banner Leakage ─────────────────────────────────────────────────────
section "Server Banner Leakage"
SERVER=$(get_header "Server")
X_POWERED=$(get_header "X-Powered-By")
X_ASPNET=$(get_header "X-AspNet-Version")
X_ASPNETMVC=$(get_header "X-AspNetMvc-Version")
X_GENERATOR=$(get_header "X-Generator")

[ -n "$SERVER" ]      && warn "Server: $SERVER" || ok "Server header not present"
[ -n "$X_POWERED" ]   && warn "X-Powered-By: $X_POWERED" || ok "X-Powered-By not present"
[ -n "$X_ASPNET" ]    && warn "X-AspNet-Version: $X_ASPNET"
[ -n "$X_ASPNETMVC" ] && warn "X-AspNetMvc-Version: $X_ASPNETMVC"
[ -n "$X_GENERATOR" ] && warn "X-Generator: $X_GENERATOR"

# ── Security Headers ──────────────────────────────────────────────────────────
section "Security Headers"

check_header() {
    local name="$1" header="$2"
    local val
    val=$(get_header "$header")
    if [ -n "$val" ]; then
        ok "$name: $val"
    else
        bad "$name header missing"
    fi
}

check_header "HSTS"                   "Strict-Transport-Security"
check_header "X-Content-Type-Options" "X-Content-Type-Options"
check_header "X-Frame-Options"        "X-Frame-Options"
check_header "Content-Security-Policy" "Content-Security-Policy"
check_header "Referrer-Policy"        "Referrer-Policy"
check_header "Permissions-Policy"     "Permissions-Policy"

# X-XSS-Protection is deprecated but still informational
XSS_PROT=$(get_header "X-XSS-Protection")
[ -n "$XSS_PROT" ] && echo "  X-XSS-Protection: $XSS_PROT (deprecated but present)"

# ── HTTP Methods ──────────────────────────────────────────────────────────────
section "Allowed HTTP Methods"
OPTIONS_RESP=$(curl -sk -X OPTIONS --max-time 10 -I "$URL" 2>/dev/null)
ALLOW=$(echo "$OPTIONS_RESP" | grep -i '^Allow:' | cut -d: -f2- | sed 's/^ *//;s/\r//')
if [ -n "$ALLOW" ]; then
    echo "  Allow: $ALLOW"
    for dangerous in TRACE PUT DELETE CONNECT PATCH; do
        if echo "$ALLOW" | grep -qi "$dangerous"; then
            warn "$dangerous method is allowed — review if intentional."
        fi
    done
else
    echo "  Allow header not returned by OPTIONS request."
fi

# Check TRACE explicitly
TRACE_STATUS=$(curl -sk -X TRACE --max-time 10 -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null)
if [ "$TRACE_STATUS" = "200" ]; then
    bad "TRACE method returns 200 — HTTP TRACE enabled (XST risk)."
else
    ok "TRACE method not allowed (status $TRACE_STATUS)."
fi

# ── CORS ──────────────────────────────────────────────────────────────────────
section "CORS Configuration"
ACAO=$(curl -sk --max-time 10 -H "Origin: https://evil.com" -I "$URL" 2>/dev/null \
    | grep -i '^Access-Control-Allow-Origin:' | cut -d: -f2- | sed 's/^ *//;s/\r//')
ACAC=$(curl -sk --max-time 10 -H "Origin: https://evil.com" -I "$URL" 2>/dev/null \
    | grep -i '^Access-Control-Allow-Credentials:' | cut -d: -f2- | sed 's/^ *//;s/\r//')

if [ -z "$ACAO" ]; then
    ok "No CORS headers returned."
else
    echo "  Access-Control-Allow-Origin: $ACAO"
    echo "  Access-Control-Allow-Credentials: ${ACAC:-not set}"
    if echo "$ACAO" | grep -q '^\*$'; then
        warn "Wildcard ACAO (*) — credentials cannot be used with wildcard."
    fi
    if echo "$ACAO" | grep -qi 'evil.com\|null'; then
        bad "ACAO reflects arbitrary origin — potential CORS misconfiguration!"
    fi
    if echo "$ACAO" | grep -qi 'evil.com' && echo "$ACAC" | grep -qi 'true'; then
        bad "ACAO reflects origin AND credentials allowed — critical CORS misconfiguration!"
    fi
fi

# ── Cookie Flags ──────────────────────────────────────────────────────────────
section "Cookie Security Flags"
COOKIES=$(curl -sk --max-time 10 -c /dev/null -I "$URL" 2>/dev/null | grep -i '^Set-Cookie:')
if [ -z "$COOKIES" ]; then
    echo "  No cookies set on root request."
else
    echo "$COOKIES" | while IFS= read -r cookie; do
        NAME=$(echo "$cookie" | sed 's/Set-Cookie://i;s/^ *//' | cut -d= -f1)
        echo "  Cookie: $NAME"
        echo "$cookie" | grep -qi 'HttpOnly'  && echo -e "    ${GREEN}[+]${NC} HttpOnly"  || echo -e "    ${RED}[!]${NC} Missing HttpOnly"
        echo "$cookie" | grep -qi 'Secure'    && echo -e "    ${GREEN}[+]${NC} Secure"    || echo -e "    ${RED}[!]${NC} Missing Secure flag"
        echo "$cookie" | grep -qi 'SameSite'  && echo -e "    ${GREEN}[+]${NC} SameSite"  || echo -e "    ${YELLOW}[!]${NC} Missing SameSite"
    done
fi

echo ""
