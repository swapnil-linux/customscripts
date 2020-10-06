#!/bin/bash
kinit admin

comm --output-delimiter=',' -2 <(ipa user-find --disabled=false|grep 'User login' |awk '{print $3}'|sort) <(ipa otptoken-find |grep Owner|awk '{print $2}'|sort) | awk -F, '{print $1}'|sort -r

kdestroy
