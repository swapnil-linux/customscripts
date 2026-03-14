#!/bin/bash
# Check your public IP address and geolocation info

get_public_ip() {
    local ip
    ip=$(curl -s --max-time 5 checkip.amazonaws.com 2>/dev/null) && [ -n "$ip" ] && echo "$ip" && return
    ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null) && [ -n "$ip" ] && echo "$ip" && return
    ip=$(curl -s --max-time 5 api.ipify.org 2>/dev/null) && [ -n "$ip" ] && echo "$ip" && return
    echo ""
}

MYIP=$(get_public_ip)

if [ -z "$MYIP" ]; then
    echo "Error: Could not determine public IP address." >&2
    exit 1
fi

# Use ip-api.com for geolocation (free, no key required)
GEO=$(curl -s --max-time 5 "http://ip-api.com/json/${MYIP}?fields=country,countryCode,regionName,city,isp,as" 2>/dev/null)

if [ -n "$GEO" ] && command -v python3 &>/dev/null; then
    parse() { python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$1','Unknown'))" <<< "$GEO" 2>/dev/null; }
    COUNTRY=$(parse country)
    REGION=$(parse regionName)
    CITY=$(parse city)
    ISP=$(parse isp)
    ASN=$(parse as)
    printf "%-10s %s\n" "IP:"      "$MYIP"
    printf "%-10s %s\n" "Country:" "$COUNTRY"
    printf "%-10s %s\n" "Region:"  "$REGION"
    printf "%-10s %s\n" "City:"    "$CITY"
    printf "%-10s %s\n" "ISP:"     "$ISP"
    printf "%-10s %s\n" "ASN:"     "$ASN"
else
    # Fallback to whois if python3 or ip-api.com unavailable
    MYCOUNTRY=$(whois "$MYIP" 2>/dev/null | grep -i "^country:" | head -1 | awk '{print $2}')
    echo "IP: $MYIP  Country: ${MYCOUNTRY:-Unknown}"
fi
