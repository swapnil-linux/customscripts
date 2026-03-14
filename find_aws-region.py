#!/usr/bin/env python3
"""Find the AWS region and service for a given IP address (IPv4 or IPv6)."""

from ipaddress import ip_network, ip_address
import json, sys, os, urllib.request

RANGES_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ip-ranges.json')
RANGES_URL = 'https://ip-ranges.amazonaws.com/ip-ranges.json'


def update_ranges():
    print(f"Downloading ip-ranges.json from {RANGES_URL} ...")
    urllib.request.urlretrieve(RANGES_URL, RANGES_FILE)
    print("Done.")


def find_aws_region(ip):
    if not os.path.exists(RANGES_FILE):
        print(f"Error: {RANGES_FILE} not found. Run with --update to download it.", file=sys.stderr)
        sys.exit(1)

    try:
        my_ip = ip_address(ip)
    except ValueError:
        print(f"Error: '{ip}' is not a valid IP address.", file=sys.stderr)
        sys.exit(1)

    with open(RANGES_FILE) as f:
        ip_json = json.load(f)

    if my_ip.version == 6:
        prefixes = ip_json.get('ipv6_prefixes', [])
        prefix_key = 'ipv6_prefix'
    else:
        prefixes = ip_json.get('prefixes', [])
        prefix_key = 'ip_prefix'

    matches = []
    for prefix in prefixes:
        if my_ip in ip_network(prefix[prefix_key]):
            matches.append((prefix['region'], prefix['service']))

    return matches


def usage():
    print(f"Usage: {os.path.basename(sys.argv[0])} <IP> [--update]")
    print(f"       {os.path.basename(sys.argv[0])} --update")
    print()
    print("  <IP>       IPv4 or IPv6 address to look up")
    print("  --update   Download latest ip-ranges.json from AWS")
    sys.exit(1)


args = sys.argv[1:]

if not args:
    usage()

do_update = '--update' in args
ip_args = [a for a in args if a != '--update']

if do_update:
    update_ranges()
    if not ip_args:
        sys.exit(0)

if not ip_args:
    usage()

ip_arg = ip_args[0]
matches = find_aws_region(ip_arg)

if not matches:
    print(f"{ip_arg} does not belong to any known AWS IP range.")
else:
    print(f"IP: {ip_arg}")
    for region, service in matches:
        print(f"  Region: {region}  |  Service: {service}")
