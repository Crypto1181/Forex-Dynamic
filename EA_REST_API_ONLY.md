# EA Integration - REST API Only

## Quick Start Guide

**Server URL:** `https://nonstabile-renee-snippily.ngrok.io:8080`  
**Connection Type:** REST API (HTTP GET)

---

## How It Works

1. **EA polls the server** every 5-10 seconds
2. **EA calls:** `GET https://nonstabile-renee-snippily.ngrok.io:8080/signals`
3. **Server responds** with latest signal (or null if no signal)
4. **EA processes** the signal and executes trade

---

## API Endpoints

### 1. Get Latest Signal (Main Endpoint)
```
GET https://nonstabile-renee-snippily.ngrok.io:8080/signals
```

**Response (Signal Available):**
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
    "tpCondition1": "21:10",
    "tpCondition2": "09:40",
    "newTP": 14,
    "lot": 0.20,
    "isDaily": false,
    "dailyTP": 20,
    "dailyLot": 0.01,
    "accountName": "Main EA",
    "brand": "MY FOREX TRADE",
    "tradeId": "550e8400-e29b-41d4-a716-446655440000",
    "receivedAt": "2025-11-15T09:55:00.000Z"
  }
}
```

**Response (No Signal):**
```json
{
  "status": "success",
  "message": "No signals available",
  "signal": null
}
```

### 2. Health Check
```
GET https://nonstabile-renee-snippily.ngrok.io:8080/
```

**Response:**
```json
{
  "status": "success",
  "message": "Trade Signal API is running",
  "version": "1.0.0"
}
```

---

## Implementation Steps

### Step 1: Test Connection
```bash
curl https://nonstabile-renee-snippily.ngrok.io:8080/
```
Should return: `{"status":"success","message":"Trade Signal API is running"}`

### Step 2: Test Get Signals
```bash
curl https://nonstabile-renee-snippily.ngrok.io:8080/signals
```

### Step 3: Implement in EA

**MQL4/MQL5:**
```mql4
string GetLatestSignal() {
    string url = "https://nonstabile-renee-snippily.ngrok-free.dev:8080/signals";
    char result[];
    string headers = "Content-Type: application/json\r\n";
    
    int res = WebRequest("GET", url, "", headers, 10000, NULL, result, headers);
    
    if(res == 200) {
        return CharArrayToString(result);
    }
    return "Error: " + IntegerToString(res);
}

void OnTimer() {
    string response = GetLatestSignal();
    // Parse JSON and check if signal exists
    // Execute trade if signal available
}
```

**Python:**
```python
import requests
import time

url = "https://nonstabile-renee-snippily.ngrok-free.dev:8080/signals"

while True:
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            data = response.json()
            if data.get('signal') is not None:
                signal = data['signal']
                # Process signal and execute trade
                print(f"Signal: {signal['symbol']} {signal['direction']}")
    except Exception as e:
        print(f"Error: {e}")
    
    time.sleep(5)  # Poll every 5 seconds
```

---

## Signal Fields

| Field | Type | Description |
|-------|------|-------------|
| `symbol` | string | Currency pair (e.g., "GBPUSD") |
| `direction` | string | "BUY" or "SELL" |
| `entryTime` | string | "YYYY-MM-DD HH:MM:SS" |
| `tp` | number | Take Profit (pips) |
| `sl` | number | Stop Loss (pips) |
| `lot` | number | Lot size |
| `tpCondition1` | string | Time condition "HH:MM" (optional) |
| `tpCondition2` | string | Time condition "HH:MM" (optional) |
| `newTP` | number | New TP value (optional) |
| `isDaily` | boolean | Daily trade flag |
| `dailyTP` | number | Daily TP (optional) |
| `dailyLot` | number | Daily lot (optional) |
| `accountName` | string | Account name |
| `brand` | string | Brand identifier |
| `tradeId` | string | Unique trade ID |

---

## Best Practices

1. **Poll every 5-10 seconds** - Not too frequent, not too slow
2. **Check `signal` field** - If `null`, no signal available
3. **Track `tradeId`** - Avoid processing same signal twice
4. **Handle timeouts** - Set 10 second timeout
5. **Error handling** - Check HTTP status codes
6. **Log everything** - For debugging

---

## Testing

**Quick Test:**
```bash
# Health check
curl https://nonstabile-renee-snippily.ngrok-free.dev:8080/

# Get signals
curl https://nonstabile-renee-snippily.ngrok-free.dev:8080/signals
```

---

## Notes

- Server URL may change if ngrok restarts (free tier)
- Always check `signal` is not `null` before processing
- Use `tradeId` to prevent duplicate processing
- Polling interval: 5-10 seconds recommended

---

That's it! Simple REST API polling. No WebSocket, no TCP - just HTTP GET requests. 🚀

