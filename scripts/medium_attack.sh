#!/bin/bash
# Medium: Brute force attack attempt by Attacker IP: 10.0.0.2 (Note: Whitelisted admin IP: 10.0.0.100)
echo "Starting medium attack (brute force)..."

USERS=("root" "admin" "ubuntu" "pi" "user" "deploy" "git")
PORTS=(51234 52891 53007 54321 55102 56777 57438)
COUNTER=0

while true; do
    # Burst of 5-8 failed attempts per cycle
    BURST=$((RANDOM % 4 + 5))
    for i in $(seq 1 $BURST); do
        USER=${USERS[$((RANDOM % ${#USERS[@]}))]}
        PORT=${PORTS[$((RANDOM % ${#PORTS[@]}))]}
        echo "$(date '+%b %d %H:%M:%S') myhost sshd[$((RANDOM % 9000 + 1000))]: Failed password for $USER from 10.0.0.2 port $PORT ssh2" >> /var/log/auth.log
        sleep 0.2
    done

    COUNTER=$((COUNTER + 1))

    # Every 3 cycles add an admin login from the whitelisted IP
    if [ $((COUNTER % 3)) -eq 0 ]; then
        echo "$(date '+%b %d %H:%M:%S') myhost sshd[2200]: Accepted password for admin from 10.0.0.100 port 22 ssh2" >> /var/log/auth.log
    fi

    sleep 3
done