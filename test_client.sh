#!/bin/bash
# Linux/Mac bash script to test REST API connection
# Usage: ./test_client.sh [host] [port]

HOST=${1:-localhost}
PORT=${2:-8080}

echo "Testing Trade Signal API Connection..."
echo "Server: $HOST:$PORT"
echo ""

curl -X POST http://$HOST:$PORT/ \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "EURUSD",
    "direction": "BUY",
    "entryTime": "2025-11-15 10:00:00",
    "tp": 30,
    "sl": 10,
    "lot": 0.10,
    "isDaily": false,
    "accountName": "Test EA",
    "brand": "TEST BRAND"
  }'

echo ""
echo "Test complete!"

