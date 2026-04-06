#!/bin/bash

echo "Starting medium attack..."
while true; do
    echo "Simulating medium attack against local nginx..."
    curl -s http://localhost/medium_attack > /dev/null
    sleep 3
done
