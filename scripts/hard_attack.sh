#!/bin/bash

echo "Starting hard attack..."
while true; do
    echo "Simulating hard attack against local nginx..."
    curl -s http://localhost/hard_attack > /dev/null
    sleep 1
done
