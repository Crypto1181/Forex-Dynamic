# API Information for EA Builder

## Quick Summary

**API Endpoint**: `GET https://forex-dynamic.onrender.com/signals`

Returns **all signals** with **creation time in GMT** and **message IDs** in a single JSON response.

---

## API Details

### Endpoint
```
GET https://forex-dynamic.onrender.com/signals
```

### Server URL
**Base URL**: `https://forex-dynamic.onrender.com`

### Authentication (if configured)
Include API key in header:
```
Authorization: Bearer YOUR_API_KEY
```

Or as query parameter:
```
GET https://forex-dynamic.onrender.com/signals?apiKey=YOUR_API_KEY
```

---

## Response Format

```json
{
  "status": "success",
  "message": "Signals retrieved",
  "signals": [
    {
      "messageId": "550e8400-e29b-41d4-a716-446655440000",
      "creationTimeGMT": "2025-01-13T13:23:00.000Z",
      "symbol": "AUDUSD",
      "direction": "BUY",
      "entryTime": "2025.10.13 13:23",
      "entryPrice": 0.0,
      "tp": 19,
      "sl": 0,
      "tpCondition1": "22:25",
      "tpCondition2": "13:23",
      "newTP": 9,
      "lot": 0.03,
      "isDaily": true,
      "dailyTP": 20,
      "dailyLot": 0.02,
      "accountName": "Account1",
      "brand": "Brand1"
    }
  ],
  "count": 1
}
```

---

## Key Fields for EA

| Field | Description |
|-------|-------------|
| `messageId` | **Unique ID (UUID)** - Use to track which signals have been processed |
| `creationTimeGMT` | **Creation time in GMT/UTC** (ISO 8601: `2025-01-13T13:23:00.000Z`) |
| `symbol` | Currency pair (e.g., "AUDUSD") |
| `direction` | "BUY" or "SELL" |
| `entryTime` | Entry time: "YYYY.MM.DD HH:MM" |
| `entryPrice` | Entry price (0.0 if not set) |
| `tp` | Take Profit in pips |
| `sl` | Stop Loss in pips |
| `tpCondition1` | First TP condition time: "HH:MM" |
| `tpCondition2` | Second TP condition time: "HH:MM" |
| `newTP` | New TP value when conditions met |
| `lot` | Lot size |
| `isDaily` | true/false - Is this a daily trade? |
| `dailyTP` | Daily TP (if isDaily is true) |
| `dailyLot` | Daily lot (if isDaily is true) |

---

## How EA Should Use This

1. **Poll the endpoint** periodically (every 30 seconds to 5 minutes)
2. **Get all signals** in one request
3. **Track `messageId`** to avoid processing the same signal twice
4. **Use `creationTimeGMT`** for time-based logic
5. **Process each signal** and execute trades accordingly

---

## Example Code (Python)

```python
import requests

# Get all signals
response = requests.get("https://forex-dynamic.onrender.com/signals")
data = response.json()

signals = data.get('signals', [])

for signal in signals:
    message_id = signal['messageId']
    creation_time = signal['creationTimeGMT']  # GMT time
    symbol = signal['symbol']
    direction = signal['direction']
    tp = signal['tp']
    sl = signal['sl']
    lot = signal['lot']
    
    # Process signal...
```

---

## Full Documentation

See `EA_API_DOCUMENTATION.md` for complete API documentation with MQL4/MQL5, Python, and C# examples.

---

**Server URL**: `https://forex-dynamic.onrender.com`

**Test the API**: Open `https://forex-dynamic.onrender.com/` in your browser to verify the server is running.

