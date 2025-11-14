#!/usr/bin/env python3
# Run with: python3 test_server.py
"""
Simple script to test if the server is running on localhost:8080
Run this on the laptop where the Flutter app is running
"""

import requests
import sys

def test_local_server():
    """Test if server is running on localhost:8080"""
    print("Testing local server on http://localhost:8080/")
    print("-" * 50)
    
    try:
        response = requests.get('http://localhost:8080/', timeout=5)
        print(f"✅ SUCCESS! Server is running")
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        return True
    except requests.exceptions.ConnectionError as e:
        if "Connection refused" in str(e) or "111" in str(e):
            print("❌ FAILED: Connection refused")
            print("   → Server is NOT running on port 8080")
            print("   → Start the server in the Flutter app (Server tab → Start Server)")
            return False
        else:
            print(f"❌ FAILED: Connection error: {e}")
            return False
    except requests.exceptions.Timeout:
        print("❌ FAILED: Connection timeout")
        print("   → Server might be starting or blocked")
        return False
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False

def test_ngrok(ngrok_url):
    """Test ngrok URL"""
    if not ngrok_url:
        print("\nSkipping ngrok test (no URL provided)")
        return
    
    print(f"\nTesting ngrok URL: {ngrok_url}")
    print("-" * 50)
    
    try:
        response = requests.get(ngrok_url, timeout=10)
        print(f"✅ SUCCESS! ngrok is working")
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
    except requests.exceptions.Timeout:
        print("❌ FAILED: ngrok timeout")
        print("   → ngrok is running but can't reach your server")
        print("   → Make sure server is running on localhost:8080")
    except Exception as e:
        print(f"❌ FAILED: {e}")

if __name__ == '__main__':
    print("=" * 50)
    print("Server Connection Test")
    print("=" * 50)
    
    # Test local server
    local_ok = test_local_server()
    
    # Test ngrok if URL provided
    if len(sys.argv) > 1:
        ngrok_url = sys.argv[1]
        if not ngrok_url.startswith('http'):
            ngrok_url = f'https://{ngrok_url}'
        test_ngrok(ngrok_url)
    else:
        print("\nTo test ngrok, run:")
        print("  python test_server.py https://your-url.ngrok-free.dev:8080")
    
    print("\n" + "=" * 50)
    if local_ok:
        print("✅ Local server is working!")
        print("   If ngrok still fails, check:")
        print("   1. ngrok is pointing to correct port (8080)")
        print("   2. Firewall isn't blocking")
    else:
        print("❌ Local server is NOT working")
        print("   Fix this first before testing ngrok")

