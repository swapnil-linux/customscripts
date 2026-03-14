#!/bin/bash
# List active FreeIPA/RedHat IDM users who do not have an OTP token configured.

for tool in ipa kinit kdestroy comm; do
    if ! command -v "$tool" &>/dev/null; then
        echo "Error: '$tool' not found. Is the FreeIPA client installed?" >&2
        exit 1
    fi
done

echo "Authenticating with Kerberos..."
if ! kinit admin; then
    echo "Error: Kerberos authentication failed." >&2
    exit 1
fi

echo ""
echo "Active users WITHOUT OTP token:"
echo "--------------------------------"

BAD_USERS=$(comm --output-delimiter=',' -2 \
    <(ipa user-find --disabled=false | grep 'User login' | awk '{print $3}' | sort) \
    <(ipa otptoken-find | grep Owner | awk '{print $2}' | sort) \
    | awk -F, '{print $1}' | grep -v '^$' | sort)

if [ -z "$BAD_USERS" ]; then
    echo "All active users have OTP tokens configured."
else
    echo "$BAD_USERS"
    COUNT=$(echo "$BAD_USERS" | wc -l | tr -d ' ')
    echo "--------------------------------"
    echo "Total: $COUNT user(s) without OTP token"
fi

kdestroy
