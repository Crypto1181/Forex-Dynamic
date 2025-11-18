# EA API Documentation - Forex Dynamic Signal API

## Overview

This API provides trade signals to Expert Advisors (EAs). The EA can poll the API to retrieve all available signals with their creation times in GMT and unique message IDs.

---

## API Endpoint

**Base URL**: `https://forex-dynamic.onrender.com`  
**Full Endpoint**: `https://forex-dynamic.onrender.com/signals`  
**Method**: `GET`  
**Protocol**: HTTP/HTTPS (REST API)

### Server Information:
- **Production Server**: `https://forex-dynamic.onrender.com`
- **Health Check**: `https://forex-dynamic.onrender.com/` (returns server status)
- **Signals Endpoint**: `https://forex-dynamic.onrender.com/signals`

---

## Authentication (Optional)

If an API key is configured, include it in one of these ways:

### Option 1: Authorization Header (Recommended)
```
Authorization: Bearer YOUR_API_KEY
```

### Option 2: Query Parameter
```
https://forex-dynamic.onrender.com/signals?apiKey=YOUR_API_KEY
```

---

## Request

### GET /signals

Retrieves all available trade signals in a single request.

**No request body required.**

**Headers:**
```
Content-Type: application/json
Authorization: Bearer YOUR_API_KEY (if API key is set)
```

---

## Response Format

### Success Response (200 OK)

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
      "brand": "Brand1",
      "tradeId": "550e8400-e29b-41d4-a716-446655440000",
      "receivedAt": "2025-01-13T13:23:00.000Z",
      "isDraft": false
    },
    {
      "messageId": "660e8400-e29b-41d4-a716-446655440001",
      "creationTimeGMT": "2025-01-13T14:30:00.000Z",
      "symbol": "EURUSD",
      "direction": "SELL",
      "entryTime": "2025.10.13 14:30",
      "entryPrice": 1.0850,
      "tp": 25,
      "sl": 15,
      "lot": 0.05,
      "isDaily": false,
      "accountName": "Account2",
      "brand": "Brand2",
      "tradeId": "660e8400-e29b-41d4-a716-446655440001",
      "receivedAt": "2025-01-13T14:30:00.000Z",
      "isDraft": false
    }
  ],
  "count": 2
}
```

### Empty Response (No Signals)

```json
{
  "status": "success",
  "message": "No signals available",
  "signals": [],
  "count": 0
}
```

### Error Response (401 Unauthorized)

```json
{
  "status": "error",
  "message": "Unauthorized",
  "code": "UNAUTHORIZED"
}
```

---

## Response Fields

### Root Object
| Field | Type | Description |
|-------|------|-------------|
| `status` | string | `"success"` or `"error"` |
| `message` | string | Human-readable message |
| `signals` | array | Array of signal objects (empty if no signals) |
| `count` | number | Total number of signals returned |

### Signal Object
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `messageId` | string | Yes | **Unique message identifier (UUID)** - Use this to track which signals have been processed |
| `creationTimeGMT` | string | Yes | **Signal creation time in GMT/UTC** (ISO 8601 format: `YYYY-MM-DDTHH:mm:ss.sssZ`) |
| `symbol` | string | Yes | Currency pair (e.g., "AUDUSD", "EURUSD", "GBPUSD") |
| `direction` | string | Yes | Trade direction: `"BUY"` or `"SELL"` |
| `entryTime` | string | Yes | Entry time in format: `"YYYY.MM.DD HH:MM"` |
| `entryPrice` | number | No | Entry price (0.0 if not specified) |
| `tp` | number | Yes | Take Profit in pips |
| `sl` | number | Yes | Stop Loss in pips (0 if not set) |
| `tpCondition1` | string | No | First TP condition time in format: `"HH:MM"` |
| `tpCondition2` | string | No | Second TP condition time in format: `"HH:MM"` |
| `newTP` | number | No | New TP value to use when conditions are met |
| `lot` | number | Yes | Lot size for the trade |
| `isDaily` | boolean | Yes | `true` if this is a daily trade, `false` otherwise |
| `dailyTP` | number | No | Daily TP value (only if `isDaily` is `true`) |
| `dailyLot` | number | No | Daily lot size (only if `isDaily` is `true`) |
| `accountName` | string | Yes | Name of the account/EA this signal is for |
| `brand` | string | Yes | Trade brand identifier |
| `tradeId` | string | Yes | Unique trade ID (same as `messageId`) |
| `receivedAt` | string | Yes | When signal was received (ISO 8601 format) |
| `isDraft` | boolean | Yes | `false` for sent signals, `true` for saved drafts |

---

## Key Features for EA

1. **All Signals in One Request**: The EA calls `/signals` once and receives all available signals
2. **GMT Creation Time**: Each signal includes `creationTimeGMT` in UTC timezone for accurate time-based processing
3. **Message IDs**: Each signal has a unique `messageId` (UUID) that the EA can use to:
   - Track which signals have already been processed
   - Avoid duplicate processing
   - Maintain state between API calls
4. **Signal Ordering**: Signals are returned with newest first (most recent signal is first in the array)

---

## Implementation Examples

### MQL4/MQL5 Example

```mql4
// Function to get all signals from API
string GetSignals(string apiUrl, string apiKey = "") {
    string headers = "Content-Type: application/json\r\n";
    
    if(apiKey != "") {
        headers = headers + "Authorization: Bearer " + apiKey + "\r\n";
    }
    
    char post[];
    char result[];
    string response = "";
    
    int res = WebRequest("GET", apiUrl + "/signals", "", headers, 5000, post, result, headers);
    
    if(res == 200) {
        response = CharArrayToString(result);
        return response;
    }
    
    Print("Error getting signals: ", res);
    return "";
}

// Parse and process signals
void ProcessSignals(string jsonResponse) {
    // Parse JSON response
    // Extract signals array
    // For each signal:
    //   1. Check messageId - have we processed this before?
    //   2. Check creationTimeGMT - is this signal still valid?
    //   3. Execute trade based on signal data
    //   4. Store messageId to avoid reprocessing
}
```

### Python Example

```python
import requests
import json
from datetime import datetime

def get_signals(api_url, api_key=None):
    """Get all signals from the API"""
    headers = {"Content-Type": "application/json"}
    
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    
    try:
        response = requests.get(f"{api_url}/signals", headers=headers, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            return data.get('signals', [])
        else:
            print(f"Error: {response.status_code} - {response.text}")
            return []
    except Exception as e:
        print(f"Connection error: {e}")
        return []

def process_signals(signals, processed_ids):
    """Process signals and track which ones have been handled"""
    for signal in signals:
        message_id = signal.get('messageId')
        
        # Skip if already processed
        if message_id in processed_ids:
            continue
        
        # Check creation time (GMT)
        creation_time = datetime.fromisoformat(
            signal['creationTimeGMT'].replace('Z', '+00:00')
        )
        
        # Process signal
        symbol = signal['symbol']
        direction = signal['direction']
        tp = signal['tp']
        sl = signal['sl']
        lot = signal['lot']
        
        print(f"Processing signal {message_id}: {symbol} {direction}")
        print(f"  Created at: {creation_time}")
        print(f"  TP: {tp}, SL: {sl}, Lot: {lot}")
        
        # Execute trade logic here
        # ...
        
        # Mark as processed
        processed_ids.add(message_id)

# Usage
api_url = "https://forex-dynamic.onrender.com"
api_key = "your-api-key"  # Optional (if API key is configured)
processed_message_ids = set()

# Poll for signals every 30 seconds
while True:
    signals = get_signals(api_url, api_key)
    if signals:
        process_signals(signals, processed_message_ids)
    time.sleep(30)
```

### C# Example (for .NET EAs)

```csharp
using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;

public class SignalApiClient
{
    private readonly string _apiUrl;
    private readonly string _apiKey;
    private readonly HttpClient _httpClient;
    private readonly HashSet<string> _processedMessageIds = new HashSet<string>();

    public SignalApiClient(string apiUrl, string apiKey = null)
    {
        _apiUrl = apiUrl.TrimEnd('/');
        _apiKey = apiKey;
        _httpClient = new HttpClient();
        
        if (!string.IsNullOrEmpty(_apiKey))
        {
            _httpClient.DefaultRequestHeaders.Add("Authorization", $"Bearer {_apiKey}");
        }
    }

    public async Task<List<Signal>> GetSignalsAsync()
    {
        try
        {
            var response = await _httpClient.GetAsync($"{_apiUrl}/signals");
            
            if (response.IsSuccessStatusCode)
            {
                var json = await response.Content.ReadAsStringAsync();
                var result = JsonConvert.DeserializeObject<ApiResponse>(json);
                return result.Signals ?? new List<Signal>();
            }
            
            return new List<Signal>();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error getting signals: {ex.Message}");
            return new List<Signal>();
        }
    }

    public void ProcessSignals(List<Signal> signals)
    {
        foreach (var signal in signals)
        {
            // Skip if already processed
            if (_processedMessageIds.Contains(signal.MessageId))
                continue;

            // Process signal
            Console.WriteLine($"Processing signal {signal.MessageId}: {signal.Symbol} {signal.Direction}");
            Console.WriteLine($"  Created at: {signal.CreationTimeGMT}");
            
            // Execute trade logic here
            // ...
            
            // Mark as processed
            _processedMessageIds.Add(signal.MessageId);
        }
    }
}

public class ApiResponse
{
    [JsonProperty("status")]
    public string Status { get; set; }
    
    [JsonProperty("message")]
    public string Message { get; set; }
    
    [JsonProperty("signals")]
    public List<Signal> Signals { get; set; }
    
    [JsonProperty("count")]
    public int Count { get; set; }
}

public class Signal
{
    [JsonProperty("messageId")]
    public string MessageId { get; set; }
    
    [JsonProperty("creationTimeGMT")]
    public DateTime CreationTimeGMT { get; set; }
    
    [JsonProperty("symbol")]
    public string Symbol { get; set; }
    
    [JsonProperty("direction")]
    public string Direction { get; set; }
    
    [JsonProperty("entryTime")]
    public string EntryTime { get; set; }
    
    [JsonProperty("entryPrice")]
    public double EntryPrice { get; set; }
    
    [JsonProperty("tp")]
    public double TP { get; set; }
    
    [JsonProperty("sl")]
    public double SL { get; set; }
    
    [JsonProperty("lot")]
    public double Lot { get; set; }
    
    [JsonProperty("isDaily")]
    public bool IsDaily { get; set; }
    
    // ... other fields
}
```

---

## Polling Strategy

The EA should poll the `/signals` endpoint periodically (e.g., every 30 seconds to 5 minutes). Recommended approach:

1. **Initial Poll**: Get all signals on EA startup
2. **Track Processed IDs**: Maintain a list/set of `messageId` values that have been processed
3. **Filter New Signals**: Only process signals whose `messageId` is not in the processed list
4. **Time-based Filtering**: Optionally filter signals by `creationTimeGMT` to only process recent signals
5. **Periodic Polling**: Continue polling at regular intervals to get new signals

---

## Error Handling

- **401 Unauthorized**: Check if API key is correct
- **404 Not Found**: Verify the endpoint URL is correct
- **500 Internal Server Error**: Server issue, retry after a delay
- **Timeout**: Network issue, retry with exponential backoff
- **Empty Signals Array**: No signals available yet, continue polling

---

## Testing

### Test with cURL

```bash
# Without API key
curl -X GET "https://forex-dynamic.onrender.com/signals" \
  -H "Content-Type: application/json"

# With API key in header
curl -X GET "https://forex-dynamic.onrender.com/signals" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY"

# With API key in query parameter
curl -X GET "https://forex-dynamic.onrender.com/signals?apiKey=YOUR_API_KEY" \
  -H "Content-Type: application/json"
```

### Test with Browser

Simply open: `https://forex-dynamic.onrender.com/signals` in your browser to see the JSON response.

Or test the health check: `https://forex-dynamic.onrender.com/`

---

## Support

For questions or issues, contact the API provider.

---

**Last Updated**: January 2025  
**API Version**: 1.0.0

