#!/usr/bin/env python3
"""
Test Client for Trade Signal API
Use this to test the connection before implementing in EA
"""

import json
import sys
import requests
import socket
import asyncio
import websockets
from datetime import datetime

# Configuration - UPDATE THESE
SERVER_HOST = "localhost"  # Change to your IP address (e.g., "192.168.1.100")
SERVER_PORT = 8080
CONNECTION_TYPE = "REST"  # Options: "REST", "WebSocket", "TCP"
API_KEY = None  # Optional: Set if authentication is enabled

def create_test_signal():
    """Create a test trade signal"""
    return {
        "symbol": "EURUSD",
        "direction": "BUY",
        "entryTime": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "tp": 30,
        "sl": 10,
        "tpCondition1": "21:10",
        "tpCondition2": "09:40",
        "newTP": 15,
        "lot": 0.10,
        "isDaily": False,
        "dailyTP": 20,
        "dailyLot": 0.01,
        "accountName": "Test EA",
        "brand": "TEST BRAND"
    }

def test_rest_api(signal):
    """Test REST API connection"""
    print("Testing REST API...")
    url = f"http://{SERVER_HOST}:{SERVER_PORT}/"
    
    headers = {
        "Content-Type": "application/json"
    }
    
    if API_KEY:
        headers["Authorization"] = f"Bearer {API_KEY}"
    
    try:
        response = requests.post(url, json=signal, headers=headers, timeout=5)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except requests.exceptions.ConnectionError:
        print("ERROR: Could not connect to server. Is it running?")
        return False
    except Exception as e:
        print(f"ERROR: {e}")
        return False

async def test_websocket(signal):
    """Test WebSocket connection"""
    print("Testing WebSocket...")
    uri = f"ws://{SERVER_HOST}:{SERVER_PORT}/"
    
    try:
        async with websockets.connect(uri) as websocket:
            # Send signal
            await websocket.send(json.dumps(signal))
            print("Signal sent, waiting for response...")
            
            # Receive response
            response = await websocket.recv()
            print(f"Response: {json.dumps(json.loads(response), indent=2)}")
            return True
    except Exception as e:
        print(f"ERROR: {e}")
        return False

def test_tcp_socket(signal):
    """Test TCP Socket connection"""
    print("Testing TCP Socket...")
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect((SERVER_HOST, SERVER_PORT))
        
        # Send signal
        message = json.dumps(signal) + '\n'
        sock.sendall(message.encode('utf-8'))
        print("Signal sent, waiting for response...")
        
        # Receive response
        response = sock.recv(1024).decode('utf-8')
        print(f"Response: {json.dumps(json.loads(response.strip()), indent=2)}")
        
        sock.close()
        return True
    except socket.timeout:
        print("ERROR: Connection timeout")
        return False
    except ConnectionRefusedError:
        print("ERROR: Connection refused. Is server running?")
        return False
    except Exception as e:
        print(f"ERROR: {e}")
        return False

def main():
    print("=" * 50)
    print("Trade Signal API Test Client")
    print("=" * 50)
    print(f"Server: {SERVER_HOST}:{SERVER_PORT}")
    print(f"Connection Type: {CONNECTION_TYPE}")
    print("=" * 50)
    print()
    
    signal = create_test_signal()
    print("Test Signal:")
    print(json.dumps(signal, indent=2))
    print()
    
    success = False
    
    if CONNECTION_TYPE == "REST":
        success = test_rest_api(signal)
    elif CONNECTION_TYPE == "WebSocket":
        success = asyncio.run(test_websocket(signal))
    elif CONNECTION_TYPE == "TCP":
        success = test_tcp_socket(signal)
    else:
        print(f"ERROR: Unknown connection type: {CONNECTION_TYPE}")
        return
    
    print()
    print("=" * 50)
    if success:
        print("✓ Test PASSED - Connection successful!")
    else:
        print("✗ Test FAILED - Check server and connection")
    print("=" * 50)

if __name__ == "__main__":
    # Check if custom host/port provided
    if len(sys.argv) >= 2:
        SERVER_HOST = sys.argv[1]
    if len(sys.argv) >= 3:
        SERVER_PORT = int(sys.argv[2])
    if len(sys.argv) >= 4:
        CONNECTION_TYPE = sys.argv[3]
    
    main()

