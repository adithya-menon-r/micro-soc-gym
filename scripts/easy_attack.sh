#!/bin/bash

echo "Starting easy attack..."
while true; do
    echo "Simulating easy attack against local nginx..."
    curl -s http://localhost/easy_attack > /dev/null
    sleep 5
done
