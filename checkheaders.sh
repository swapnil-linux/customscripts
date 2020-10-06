#!/bin/bash
RED='\033[0;31m'
NC='\033[0m' # No Color
echo -e "${RED}Testing $1 ......... ${NC}"

nmap -p443 --script http-waf-detect --script-args="http-waf-detect.aggro,http-waf-detect.detectBodyChanges" $1
nmap --script http-headers -p 443 $1
nmap --script http-security-headers -p 443 $1
nmap --script ssl-enum-ciphers -p 443 $1
wafw00f https://$1
