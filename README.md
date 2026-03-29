# My Custom Scripts for Everyone ;)
I am lazy when it comes to doing the same again and again, and it encourages me to create these teeny-tiny scripts. :) don't expect it to be immaculate, clean or excellent. It does what it is meant to do.

## checkheaders.sh
- Check HTTP headers, SSL/TLS ciphers, and detect WAF on a target
- Usage: `./checkheaders.sh <FQDN|IP> [port]`
- Default port is 443; pass a second argument to override
- Example: `./checkheaders.sh google.com`
- Example: `./checkheaders.sh example.com 8443`
- Requires: `nmap`, `wafw00f` (skipped with a warning if not found)

## find_aws-region.py
- Find the AWS region and service for a given IPv4 or IPv6 address
- Usage: `python3 find_aws-region.py <IP>`
- Update ip-ranges.json: `python3 find_aws-region.py --update`
- Combined: `python3 find_aws-region.py --update <IP>`
- ip-ranges.json is fetched from https://ip-ranges.amazonaws.com/ip-ranges.json

## openvpn_status.sh
- Display connected OpenVPN users with column-formatted output
- Usage: `./openvpn_status.sh`
- Default log path: `/var/log/openvpn/status.log`
- Override: `OPENVPN_STATUS_LOG=/custom/path ./openvpn_status.sh`

## bad_freeipa_users.sh
- Print a list of active FreeIPA/RedHat IDM users who do not have an OTP token configured
- Usage: `./bad_freeipa_users.sh`
- Requires: `ipa`, `kinit`, `kdestroy`, `comm`

## checkip_country.sh
- Print your public Internet IP with geolocation info (country, region, city, ISP, ASN)
- Usage: `./checkip_country.sh`
- Falls back to `whois` if ip-api.com is unreachable or python3 is unavailable

## check_tls_cert.sh
- Inspect a TLS certificate: expiry, SANs, signature algorithm, key size, chain completeness
- Checks for deprecated protocol support (TLS 1.0/1.1), self-signed certs, and weak crypto
- Usage: `./check_tls_cert.sh <FQDN> [port]`
- Default port: 443
- Example: `./check_tls_cert.sh google.com`
- Requires: `openssl`, `python3`

## dns_recon.sh
- DNS reconnaissance: A/AAAA/MX/NS/TXT/SOA records, SPF/DMARC/DKIM checks, DNSSEC, zone transfer attempt
- Usage: `./dns_recon.sh <domain>`
- Example: `./dns_recon.sh example.com`
- Requires: `dig`

## http_security_config.sh
- HTTP security misconfiguration checks: dangerous methods, missing security headers,
  CORS misconfiguration, server banner leakage, cookie security flags, HTTP→HTTPS redirect
- Usage: `./http_security_config.sh <FQDN|IP> [port]`
- Default port: 443 (https). Port 80 uses http.
- Example: `./http_security_config.sh example.com`
- Requires: `curl`
