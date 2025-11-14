# What to Share with EA Builder

## Quick Summary

Share this document with your EA builder. It contains everything they need to connect the EA to your Trade Signal API.

---

## 1. Connection Information

**Server Details:**
- **IP Address**: `YOUR_IP_ADDRESS` (e.g., `192.168.1.100` or `192.168.0.5`)
- **Port**: `8080` (default, can be changed in app)
- **Connection Types Available**: REST API, WebSocket, or TCP Socket

**How to find your IP:**
- **Windows**: Open CMD, type `ipconfig`, look for "IPv4 Address"
- **Mac/Linux**: Open Terminal, type `ifconfig` or `ip addr`

---

## 2. Integration Guide

Share the file: **`EA_INTEGRATION_GUIDE.md`**

This contains:
- Complete API specification
- Signal format (JSON)
- Code examples for MQL4/MQL5, Python
- All three connection types explained
- Error handling
- Testing instructions

---

## 3. Test Client

Share the test files so EA builder can verify connection:

- **`test_client.py`** - Python test client (works on all platforms)
- **`test_client.sh`** - Linux/Mac bash script
- **`test_client.bat`** - Windows batch script

**How to use test client:**
```bash
# Python (requires: pip install requests websockets)
python test_client.py [HOST] [PORT] [CONNECTION_TYPE]

# Examples:
python test_client.py localhost 8080 REST
python test_client.py 192.168.1.100 8080 WebSocket
python test_client.py 192.168.1.100 8080 TCP
```

---

## 4. Signal Format Example

**Share this JSON example:**

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

---

## 5. Quick Start for EA Builder

**Recommended approach:**

1. **Start with REST API** (easiest)
   - Endpoint: `http://YOUR_IP:8080/`
   - Method: POST
   - Content-Type: application/json
   - Body: Signal JSON

2. **Test with curl first:**
   ```bash
   curl -X POST http://YOUR_IP:8080/ \
     -H "Content-Type: application/json" \
     -d '{"symbol":"EURUSD","direction":"BUY",...}'
   ```

3. **Implement in EA:**
   - Use MQL4/MQL5 WebRequest() function
   - Or use HTTP library for your language
   - Handle response and errors

4. **For real-time (optional):**
   - Switch to WebSocket or TCP Socket
   - Maintain persistent connection
   - Receive signals in real-time

---

## 6. What EA Builder Needs to Know

### Required Information:
- ✅ Server IP address
- ✅ Port number (default: 8080)
- ✅ Connection type preference (REST/WebSocket/TCP)
- ✅ Whether API key authentication is enabled

### Optional Information:
- API key (if authentication enabled)
- Custom port (if changed from default)

### EA Builder Should Provide:
- How they want to receive signals (polling vs push)
- Preferred connection type
- Any special requirements

---

## 7. Testing Checklist

Before EA builder starts coding, they should:

- [ ] Test connection with curl/Postman
- [ ] Verify server is accessible from their network
- [ ] Test with sample signal
- [ ] Confirm response format
- [ ] Check error handling

---

## 8. Support

**If EA builder has questions:**

1. Check `EA_INTEGRATION_GUIDE.md` first
2. Test with provided test clients
3. Verify server is running in your app
4. Check network connectivity
5. Review error codes in integration guide

---

## 9. Recommended Connection Type

**For most EAs, I recommend:**

1. **REST API** - Start here, easiest to implement
2. **WebSocket** - If real-time is critical
3. **TCP Socket** - For MQL4/MQL5, maximum performance

---

## Files to Share

1. ✅ `EA_INTEGRATION_GUIDE.md` - Complete specification
2. ✅ `test_client.py` - Python test client
3. ✅ `test_client.sh` - Linux/Mac test script
4. ✅ `test_client.bat` - Windows test script
5. ✅ This document (`WHAT_TO_SHARE_WITH_EA_BUILDER.md`)

---

## Example Email to EA Builder

```
Subject: Trade Signal API Integration - Connection Details

Hi [EA Builder Name],

I need to integrate my Trade Signal API with your EA. Here are the details:

Server Information:
- IP Address: 192.168.1.100
- Port: 8080
- Connection Type: REST API (recommended to start)

I've attached:
1. EA_INTEGRATION_GUIDE.md - Complete API specification
2. Test clients for testing the connection

Please review the integration guide and let me know:
- Which connection type you prefer (REST/WebSocket/TCP)
- Any questions about the signal format
- When you can start implementation

You can test the connection using the provided test_client.py script.

Thanks!
```

---

## Next Steps

1. **You (App Owner):**
   - Find your IP address
   - Start the server in the app
   - Share connection details with EA builder
   - Share the integration guide and test clients

2. **EA Builder:**
   - Review integration guide
   - Test connection with test clients
   - Implement signal receiver in EA
   - Test with real signals

3. **Together:**
   - Test end-to-end flow
   - Verify signals are received correctly
   - Handle any edge cases
   - Deploy to production

