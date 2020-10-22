#!/bin/bash
MYIP=`curl checkip.amazonaws.com 2> /dev/null`
MYCOUNTRY=`whois $MYIP | grep country |awk '{print $2}'`
echo IP: $MYIP FROM: $MYCOUNTRY
