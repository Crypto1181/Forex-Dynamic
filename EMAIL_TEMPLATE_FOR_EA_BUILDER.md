# Email Template for EA Builder

Copy and customize this email to send to your EA builder:

---

**Subject:** Trade Signal API - Connection Details & Integration Guide

---

Hi [EA Builder Name],

I need to integrate my Trade Signal API with your EA. Here are all the details you need:

## Connection Information

**Server URL:** `https://abc123-def456.ngrok.io:8080`  
**Connection Type:** REST API  
**Port:** 8080  
**Protocol:** HTTPS

## How to Connect (REST API Only)

**EA Polling Approach:**
The EA should poll the `/signals` endpoint every 5-10 seconds to get the latest signal.

**Main Endpoint:** `GET https://abc123-def456.ngrok.io:8080/signals`

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
    ...
  }
}
```

**If no signal available:**
```json
{
  "status": "success",
  "message": "No signals available",
  "signal": null
}
```

**Health Check Endpoint:**
`GET https://abc123-def456.ngrok.io:8080/` - Returns server status (use this to verify connection)

### Example - Get Latest Signal:
```
GET https://abc123-def456.ngrok.io:8080/signals
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

**Response (No Signal Available):**
```json
{
  "status": "success",
  "message": "No signals available",
  "signal": null
}
```

## Signal Format Details

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `symbol` | string | Yes | Currency pair (e.g., "GBPUSD", "EURUSD") |
| `direction` | string | Yes | "BUY" or "SELL" |
| `entryTime` | string | Yes | Date and time "YYYY-MM-DD HH:MM:SS" |
| `tp` | number | Yes | Take Profit in pips |
| `sl` | number | Yes | Stop Loss in pips |
| `tpCondition1` | string | No | Time condition "HH:MM" |
| `tpCondition2` | string | No | Time condition "HH:MM" |
| `newTP` | number | No | New TP value |
| `lot` | number | Yes | Lot size |
| `isDaily` | boolean | Yes | Daily trade flag |
| `dailyTP` | number | No | Daily TP if applicable |
| `dailyLot` | number | No | Daily lot if applicable |
| `accountName` | string | Yes | Account/EA name |
| `brand` | string | Yes | Trade brand identifier |

## Testing

**1. Test Health Check (Verify Server is Running):**
```bash
curl https://abc123-def456.ngrok.io:8080/
```

Expected response:
```json
{
  "status": "success",
  "message": "Trade Signal API is running",
  "version": "1.0.0"
}
```

**2. Test Get Signals (Main Endpoint):**
```bash
curl https://abc123-def456.ngrok.io:8080/signals
```

This will return the latest signal or `{"signal": null}` if no signals available.

I've attached a Python test client (`test_client.py`) that you can use to test the connection.

## Implementation Notes (REST API)

1. **Polling Frequency** - Call `GET /signals` every 5-10 seconds
2. **Handle responses** - Check if `signal` is `null` (no signal) or contains data
3. **Error handling** - Check HTTP status code (200 = success)
4. **Network timeouts** - Set timeout to 10 seconds
5. **Parse JSON** - Extract signal data from `response.signal` object
6. **Avoid duplicates** - Track `tradeId` to avoid processing same signal twice
7. **Log everything** - Keep logs for debugging

## MQL4/MQL5 Example (REST API - Polling)

```mql4
// Poll for signals every 5 seconds
string GetLatestSignal() {
    string url = "https://abc123-def456.ngrok.io:8080/signals";
    char result[];
    string headers = "Content-Type: application/json\r\n";
    
    int res = WebRequest("GET", url, "", headers, 10000, NULL, result, headers);
    
    if(res == 200) {
        string response = CharArrayToString(result);
        // Check if signal exists
        if(StringFind(response, "\"signal\":null") == -1) {
            // Signal available - parse and execute trade
            Print("New signal received: ", response);
            // TODO: Parse JSON and extract signal data
            // TODO: Execute trade based on signal
        }
        return response;
    }
    return "Error: " + IntegerToString(res);
}

// Call this in OnTimer() every 5 seconds
void OnTimer() {
    GetLatestSignal();
}
```

## Important Notes

- The server URL uses ngrok tunnel, so it's accessible from anywhere
- URL may change if I restart ngrok (free tier limitation)
- I'll notify you if the URL changes
- Server runs 24/7 on my laptop
- Multiple EAs can connect to the same server

## Attachments

1. **EA_INTEGRATION_GUIDE.md** - Complete API specification with all details
2. **test_client.py** - Python test client for testing connection

## Questions?

If you have any questions or need clarification, please let me know. I'm happy to help with the integration.

Please let me know:
- When you can start implementation
- If you prefer a different connection type (WebSocket/TCP)
- Any questions about the signal format

Thanks!

[Your Name]

---

## Quick Start for EA Builder

1. Test connection using `test_client.py` or curl
2. Implement signal receiver in EA
3. Test with sample signal
4. Deploy to production
5. Notify me when ready for live signals

---

**Note:** Remember to replace `https://abc123-def456.ngrok.io:8080` with your actual ngrok URL!

