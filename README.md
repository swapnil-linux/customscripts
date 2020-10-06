# My Custom Scripts for Everyone ;)
I am lazy when it comes to doing the same again and again, and this encourages me to create these teeny-tiny scripts. :)

## checkheaders.sh  
- I use this to check HTTP headers, SSL Ciphers and detect WAF
- Usage: `./checkheaders.sh <FQDN|IP>`
- Example: `./checkheaders.sh google.com`

## find_aws-region.py
- I use this to find the AWS region a IP belongs to
- Usage: `python3 find_aws-region.py <IP>`
- update ip-rages.json from https://ip-ranges.amazonaws.com/ip-ranges.json before use
