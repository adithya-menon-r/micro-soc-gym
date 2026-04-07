#!/bin/bash
# Easy: Attacker 10.0.0.1 repeatedly requests for 404 paths while normal users browse normal pages
echo "Starting easy attack (noisy scanner + normal traffic)..."

# Normal user IPs as decoys
NORMAL_IPS=("10.0.0.50" "10.0.0.51" "10.0.0.52" "10.0.0.53")
NORMAL_PATHS=("/" "/index.html" "/about" "/contact" "/products" "/favicon.ico")
COUNTER=0

while true; do
    # Attacker does rapid scan of suspicious paths
    curl -s -H "X-Forwarded-For: 10.0.0.1" http://localhost/admin > /dev/null
    curl -s -H "X-Forwarded-For: 10.0.0.1" http://localhost/.env > /dev/null
    curl -s -H "X-Forwarded-For: 10.0.0.1" http://localhost/wp-login.php > /dev/null
    curl -s -H "X-Forwarded-For: 10.0.0.1" http://localhost/phpmyadmin > /dev/null
    curl -s -H "X-Forwarded-For: 10.0.0.1" http://localhost/.git/config > /dev/null

    COUNTER=$((COUNTER + 1))

    # Every other cycle, 1-2 normal user requests to mix in normal traffic
    if [ $((COUNTER % 2)) -eq 0 ]; then
        IP=${NORMAL_IPS[$((RANDOM % ${#NORMAL_IPS[@]}))]}
        PATH_=${NORMAL_PATHS[$((RANDOM % ${#NORMAL_PATHS[@]}))]}
        curl -s -H "X-Forwarded-For: $IP" "http://localhost${PATH_}" > /dev/null
        sleep 0.1
        IP2=${NORMAL_IPS[$((RANDOM % ${#NORMAL_IPS[@]}))]}
        PATH2=${NORMAL_PATHS[$((RANDOM % ${#NORMAL_PATHS[@]}))]}
        curl -s -H "X-Forwarded-For: $IP2" "http://localhost${PATH2}" > /dev/null
    fi

    sleep 0.3
done
