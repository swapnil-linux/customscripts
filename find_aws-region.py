from ipaddress import ip_network, ip_address
import json, sys

def find_aws_region(ip):
  ip_json = json.load(open('ip-ranges.json'))
  prefixes = ip_json['prefixes']
  my_ip = ip_address(ip)
  region = 'Unknown'
  for prefix in prefixes:
    if my_ip in ip_network(prefix['ip_prefix']):
      region = prefix['region']
      break
  return region

result = find_aws_region(sys.argv[1])
print("AWS Region is",result)
