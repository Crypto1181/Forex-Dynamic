# How Trade Signals Are Sent to EA

## Architecture Overview

This app works as a **Signal Hub** that can both:
1. **Receive** signals from external sources (other apps, APIs)
2. **Send** signals to connected EAs (Expert Advisors)

## How Signals Flow to EA

### Step-by-Step Process:

1. **Start the Server**
   - Go to the "Server" tab in the app
   - Choose connection type: REST, WebSocket, or TCP
   - Set port (default: 8080)
   - Click "Start Server"

2. **EA Connects to Server**
   - Your EA (Expert Advisor) connects to the server using one of the supported protocols:
     - **REST API**: EA sends HTTP POST requests to receive signals
     - **WebSocket**: EA maintains a persistent connection
     - **TCP Socket**: EA connects via raw TCP socket

3. **Create Signal in App**
   - Go to "Signals" tab
   - Click "Create Signal" button
   - Fill in all trade parameters
   - Select accounts to send to
   - Click "Send Now"

4. **Signal is Sent**
   - App sends signal to the server via `SignalClient`
   - Server receives and processes the signal
   - Server stores it locally (for display in app)
   - **Server broadcasts signal to all connected EAs**

5. **EA Receives Signal**
   - EA receives the JSON signal
   - EA processes and executes the trade

## Connection Types

### Option A: REST API (HTTP POST)
- **EA connects by**: Sending HTTP POST requests to `http://localhost:8080/`
- **How EA receives**: EA polls the server or server pushes via webhook
- **Best for**: Simple integrations, one-time requests

### Option B: WebSocket Server
- **EA connects by**: Opening WebSocket connection to `ws://localhost:8080/`
- **How EA receives**: Real-time push notifications
- **Best for**: Real-time trading, low latency

### Option C: TCP Socket Server
- **EA connects by**: Opening TCP socket to `localhost:8080`
- **How EA receives**: Direct socket communication
- **Best for**: MQL4/MQL5 EAs, maximum performance

## Signal Format

When you create a signal, it's sent as JSON:

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

## Important Notes

1. **Server Must Be Running**: Before sending signals, make sure the server is started
2. **EA Must Be Connected**: The EA needs to be connected to receive signals
3. **Multiple Accounts**: You can send the same signal to multiple accounts
4. **Local Storage**: Signals are also stored locally in the app for viewing history

## Testing

To test if signals are being sent:

1. Start the server
2. Use a tool like Postman or curl to connect:
   ```bash
   curl -X POST http://localhost:8080/ \
     -H "Content-Type: application/json" \
     -d '{"symbol":"EURUSD","direction":"BUY",...}'
   ```
3. Check the "Signals" tab to see if it appears
4. Your EA should receive the same signal

## Troubleshooting

- **"Server is not running"**: Start the server first in the Server tab
- **EA not receiving signals**: Check EA connection, verify port number
- **Connection refused**: Make sure server is running and port is correct
- **Authentication errors**: If API key is set, EA must include it in requests

