# EA Integration Guide - For EA Builder

This document provides all the information needed to connect an Expert Advisor (EA) to the Trade Signal API.

## Overview

The Trade Signal API is a server that receives trade signals and makes them available to connected EAs via multiple connection protocols.

## Connection Options

The EA builder can choose from 3 connection types:

### Option 1: REST API (HTTP GET/POST) - **RECOMMENDED FOR STARTING**
- **Protocol**: HTTP/HTTPS
- **Method**: GET (to poll for signals) or POST (to send signals)
- **Endpoint**: `https://YOUR_NGROK_URL:8080/` (e.g., `https://abc123.ngrok.io:8080/`)
- **Best for**: Simple integration, easy to test
- **How it works**: 
  - **GET /signals** - EA polls for latest signal
  - **GET /** - Health check endpoint
  - **POST /** - Send signal to server

### Option 2: WebSocket Server - **BEST FOR REAL-TIME**
- **Protocol**: WebSocket (WS/WSS)
- **Endpoint**: `ws://YOUR_IP:PORT/` (e.g., `ws://192.168.1.100:8080/`)
- **Best for**: Real-time trading, low latency, persistent connection
- **How it works**: EA maintains persistent connection, receives signals in real-time

### Option 3: TCP Socket Server - **BEST FOR MQL4/MQL5**
- **Protocol**: Raw TCP Socket
- **Endpoint**: `YOUR_IP:PORT` (e.g., `192.168.1.100:8080`)
- **Best for**: MQL4/MQL5 EAs, maximum performance
- **How it works**: EA connects via TCP socket, sends/receives JSON messages

---

## Signal Format (JSON)

All connection types use the same JSON format:

```json
{
  "symbol": "GBPUSD",
  "direction": "SELL",
  "entryTime": "2025-11-15 09:55:00",
  "tp": 28,
  "sl": 0,
  "tpCondition1": "21:10",
  "tpCondition2": "09:40",
  "newTP": 14,
  "lot": 0.20,
  "isDaily": false,
  "dailyTP": 20,
  "dailyLot": 0.01,
  "accountName": "Main EA",
  "brand": "MY FOREX TRADE"
}
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `symbol` | string | Yes | Currency pair (e.g., "GBPUSD", "EURUSD") |
| `direction` | string | Yes | "BUY" or "SELL" |
| `entryTime` | string | Yes | Date and time in format "YYYY-MM-DD HH:MM:SS" |
| `tp` | number | Yes | Take Profit in pips |
| `sl` | number | Yes | Stop Loss in pips |
| `tpCondition1` | string | No | Optional time condition (format "HH:MM") |
| `tpCondition2` | string | No | Optional time condition (format "HH:MM") |
| `newTP` | number | No | Optional new TP value |
| `lot` | number | Yes | Lot size |
| `isDaily` | boolean | Yes | Boolean indicating if this is a daily trade |
| `dailyTP` | number | No | Daily TP value if applicable |
| `dailyLot` | number | No | Daily lot size if applicable |
| `accountName` | string | Yes | Name of the account/EA |
| `brand` | string | Yes | Trade brand identifier |

---

## Response Format

### Success Response
```json
{
  "status": "success",
  "message": "Trade signal received",
  "tradeId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### Error Response
```json
{
  "status": "error",
  "message": "Error description",
  "code": "ERROR_CODE"
}
```

---

## Connection Details for EA Builder

### Default Configurationimple integration, easy to te
- **Port**: 8080 (configurable)
- **Host**: localhost (for same machine) or YOUR_IP (for network)
- **Protocol**: HTTP/HTTPS (REST), WS/WSS (WebSocket), or TCP (Socket)
- **Authentication**: Optional (API key in header or query parameter)

### Finding Your IP Address
- **Windows**: Run `ipconfig` in CMD, look for "IPv4 Address"
- **Mac/Linux**: Run `ifconfig` or `ip addr`, look for inet address
- **Example**: `192.168.1.100` or `10.0.0.5`

---

## Implementation Examples

### Option 1: REST API (Polling for Signals)

**How EA Gets Signals:**
The EA should poll the `/signals` endpoint every 5-10 seconds to check for new signals.

#### GET /signals - Get Latest Signal
```
GET https://abc123.ngrok.io:8080/signals
```

**Response:**
```json
{
  "status": "success",
  "message": "Signal retrieved",
  "signal": {
    "symbol": "GBPUSD",
    "direction": "SELL",
    "entryTime": "2025-11-15 09:55:00",
    "tp": 28,
    "sl": 0,
    "lot": 0.20,
    "isDaily": false,
    "accountName": "Main EA",
    "brand": "MY FOREX TRADE",
    "tradeId": "550e8400-e29b-41d4-a716-446655440000",
    "receivedAt": "2025-11-15T09:55:00.000Z"
  }
}
```

**If no signals:**
```json
{
  "status": "success",
  "message": "No signals available",
  "signal": null
}
```

#### GET / - Health Check
```
GET https://abc123.ngrok.io:8080/
```

**Response:**
```json
{
  "status": "success",
  "message": "Trade Signal API is running",
  "version": "1.0.0"
}
```

### Option 1: REST API (HTTP POST - Send Signal)

#### MQL4/MQL5 Example - Polling for Signals
```mql4
// MQL4/MQL5 HTTP GET Example - Poll for signals
string GetLatestSignal() {
    string url = "https://abc123.ngrok.io:8080/signals";
    char result[];
    string headers = "Content-Type: application/json\r\n";
    
    int res = WebRequest("GET", url, "", headers, 5000, NULL, result, headers);
    
    if(res == 200) {
        string response = CharArrayToString(result);
        // Parse JSON response to extract signal data
        // Use signal data to execute trade
        return response;
    }
    return "Error: " + IntegerToString(res);
}

// Call this in OnTimer() or every few seconds
void OnTimer() {
    string response = GetLatestSignal();
    if(StringFind(response, "\"signal\":null") == -1) {
        // Signal available, parse and execute trade
        Print("New signal received: ", response);
        // Parse signal JSON and execute trade
    }
}
```

#### MQL4/MQL5 Example - Send Signal (if needed)
```mql4
// MQL4/MQL5 HTTP POST Example - Send signal to server
string SendSignal(string jsonData) {
    string url = "https://abc123.ngrok.io:8080/";
    char post[];
    char result[];
    string headers = "Content-Type: application/json\r\n";
    
    StringToCharArray(jsonData, post, 0, StringLen(jsonData));
    
    int res = WebRequest("POST", url, "", headers, 5000, post, result, headers);
    
    if(res == 200) {
        return CharArrayToString(result);
    }
    return "Error: " + IntegerToString(res);
}
```

#### Python Example - Polling for Signals
```python
import requests
import time

url = "https://abc123.ngrok.io:8080/signals"

# Poll for signals every 5 seconds
while True:
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            data = response.json()
            if data.get('signal') is not None:
                signal = data['signal']
                print(f"New signal: {signal['symbol']} {signal['direction']}")
                # Process signal and execute trade
            else:
                print("No signals available")
        else:
            print(f"Error: {response.status_code}")
    except Exception as e:
        print(f"Connection error: {e}")
    
    time.sleep(5)  # Wait 5 seconds before next poll
```

#### Python Example - Send Signal (for testing)
```python
import requests
import json

url = "https://abc123.ngrok.io:8080/"
signal = {
    "symbol": "GBPUSD",
    "direction": "SELL",
    "entryTime": "2025-11-15 09:55:00",
    "tp": 28,
    "sl": 0,
    "lot": 0.20,
    "isDaily": False,
    "accountName": "My EA",
    "brand": "MY FOREX TRADE"
}

response = requests.post(url, json=signal)
print(response.json())
```

### Option 2: WebSocket Server

#### Python Example
```python
import asyncio
import websockets
import json

async def connect_websocket():
    uri = "ws://192.168.1.100:8080/"
    async with websockets.connect(uri) as websocket:
        # Send signal
        signal = {
            "symbol": "GBPUSD",
            "direction": "SELL",
            "entryTime": "2025-11-15 09:55:00",
            "tp": 28,
            "sl": 0,
            "lot": 0.20,
            "isDaily": False,
            "accountName": "My EA",
            "brand": "MY FOREX TRADE"
        }
        await websocket.send(json.dumps(signal))
        
        # Receive response
        response = await websocket.recv()
        print(json.loads(response))

asyncio.run(connect_websocket())
```

### Option 3: TCP Socket Server

#### Python Example
```python
import socket
import json

def send_tcp_signal(host, port, signal):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.connect((host, port))
        message = json.dumps(signal) + '\n'
        sock.sendall(message.encode('utf-8'))
        
        # Receive response
        response = sock.recv(1024).decode('utf-8')
        return json.loads(response)
    finally:
        sock.close()

signal = {
    "symbol": "GBPUSD",
    "direction": "SELL",
    "entryTime": "2025-11-15 09:55:00",
    "tp": 28,
    "sl": 0,
    "lot": 0.20,
    "isDaily": False,
    "accountName": "My EA",
    "brand": "MY FOREX TRADE"
}

response = send_tcp_signal("192.168.1.100", 8080, signal)
print(response)
```

---

## Authentication (Optional)

If API key authentication is enabled:

### REST API
- **Header**: `Authorization: Bearer YOUR_API_KEY`
- **OR Query Parameter**: `?apiKey=YOUR_API_KEY`

### WebSocket/TCP
- Include API key in initial handshake or first message
- Format: `{"apiKey": "YOUR_API_KEY", ...signal data...}`

---imple integration, easy to te
### Using curl (Command Line)
```bash
curl -X POST http://192.168.1.100:8080/ \
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
```

### Expected Response
```json
{
  "status": "success",
  "message": "Trade signal received",
  "tradeId": "some-unique-id"
}
```

---

## Error Codes

| Code | Description |
|------|-------------|
| `VALIDATION_ERROR` | Signal data validation failed |
| `PROCESSING_ERROR` | Error processing the signal |
| `INVALID_JSON` | Invalid JSON format |
| `UNAUTHORIZED` | Authentication failed (if API key required) |
| `METHOD_NOT_ALLOWED` | Wrong HTTP method used |
| `NETWORK_ERROR` | Network connection error |

---

## Recommendations for EA Builder

1. **Start with REST API** - Easiest to implement and test
2. **Add error handling** - Check response status and handle errors
3. **Validate signal data** - Ensure all required fields are present
4. **Handle network timeouts** - Set appropriate timeout values
5. **Log all signals** - Keep a log of received signals for debugging
6. **Test connection first** - Use curl or Postman before implementing in EA

---

## Support

For questions or issues:
- Check server logs in the Flutter app
- Verify server is running and port is correct
- Test with curl/Postman first
- Check network connectivity (firewall, IP address)

---

## Quick Start Checklist

- [ ] Get server IP address and port from app owner
- [ ] Choose connection type (REST recommended for first try)
- [ ] Test connection with curl/Postman
- [ ] Implement signal receiver in EA
- [ ] Test with sample signal
- [ ] Handle errors and edge cases
- [ ] Deploy to production

