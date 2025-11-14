# Complete Signal Flow: Telegram → App → EA

## Overview

This document explains the complete flow of how trade signals move from Telegram to your Expert Advisor (EA).

## Flow Diagram

```
Telegram Channel/Bot
        ↓
   [Telegram Service]
   (Listens for messages)
        ↓
   [Signal Service]
   (Processes & stores)
        ↓
   [Server Manager]
   (Broadcasts to EA)
        ↓
   Expert Advisor (EA)
```

## Step-by-Step Process

### 1. Telegram → App

**What happens:**
- You configure Telegram bot in the app (Telegram tab)
- Enter your bot token from @BotFather
- Optionally specify channel username to monitor
- App starts polling Telegram API every 2 seconds

**Telegram Service:**
- Listens for new messages in your channel/chat
- Parses messages (supports JSON or text format)
- Converts to TradeSignal format

**Message Formats Supported:**
- **JSON**: `{"symbol":"GBPUSD","direction":"SELL",...}`
- **Text**: 
  ```
  Symbol: GBPUSD
  Direction: SELL
  TP: 28
  SL: 0
  Lot: 0.2
  ```

### 2. App Processing

**Signal Service:**
- Receives parsed signal from Telegram
- Validates all required fields
- Generates unique trade ID
- Stores signal locally (for viewing in app)
- Emits signal to UI stream (updates display)

### 3. App → EA

**Server Manager:**
- If server is running, signal is sent to server
- Server broadcasts to connected EAs
- Uses configured connection type (REST/WebSocket/TCP)

**Signal Client:**
- Sends signal to server endpoint
- Server processes and forwards to EA
- EA receives signal in real-time

## Configuration Steps

### Step 1: Set Up Telegram Bot

1. Open Telegram, search for `@BotFather`
2. Send `/newbot` command
3. Follow instructions to create bot
4. Copy the bot token (e.g., `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)
5. Add bot to your channel as admin

### Step 2: Configure in App

1. Open app → **Telegram** tab
2. Enter bot token
3. (Optional) Enter channel username (e.g., `@mysignals`)
4. Click **Start Telegram Bot**
5. Status should show "Telegram Active"

### Step 3: Start Server

1. Go to **Server** tab
2. Choose connection type (REST recommended)
3. Set port (default: 8080)
4. Click **Start Server**

### Step 4: Connect EA

1. Share integration guide with EA builder
2. EA connects to your server
3. EA receives signals automatically

## How It Works Together

### When Signal Arrives from Telegram:

1. **Telegram Service** receives message
2. Parses message into TradeSignal
3. **Signal Service** processes it:
   - Validates data
   - Stores locally
   - Updates UI
4. **Signal Client** sends to server (if running)
5. **Server** broadcasts to connected EA
6. **EA** receives and executes trade

### Manual Signal Creation:

You can also create signals manually:
1. Go to **Signals** tab
2. Click **Create Signal**
3. Fill in parameters
4. Select accounts
5. Click **Send Now**
6. Signal goes directly to EA (same flow as Telegram)

## Message Parsing

The Telegram service can parse signals in multiple formats:

### Format 1: JSON
```json
{
  "symbol": "GBPUSD",
  "direction": "SELL",
  "entryTime": "2025-11-15 09:55:00",
  "tp": 28,
  "sl": 0,
  "lot": 0.20,
  "isDaily": false,
  "accountName": "Main EA",
  "brand": "MY FOREX TRADE"
}
```

### Format 2: Text (Key-Value)
```
Symbol: GBPUSD
Direction: SELL
TP: 28
SL: 0
Lot: 0.2
TP Condition 1: 21:10
TP Condition 2: 09:40
New TP: 14
Daily: false
```

### Format 3: Simple Text
```
GBPUSD SELL 28 0 0.2
```

## Troubleshooting

### Telegram Not Receiving Messages
- ✅ Check bot token is correct
- ✅ Verify bot is added to channel as admin
- ✅ Check channel username matches (if specified)
- ✅ Ensure Telegram service is running (green status)

### Signals Not Reaching EA
- ✅ Verify server is running
- ✅ Check EA is connected to server
- ✅ Verify port number matches
- ✅ Check network connectivity
- ✅ Review server logs in app

### Parsing Errors
- ✅ Check message format matches supported formats
- ✅ Ensure all required fields are present
- ✅ Verify JSON is valid (if using JSON format)
- ✅ Check signal appears in Signals tab (means parsing worked)

## Testing

### Test Telegram Connection:
1. Send a test message to your channel
2. Check if it appears in Signals tab
3. Verify all fields are parsed correctly

### Test EA Connection:
1. Create a test signal manually
2. Check EA receives it
3. Verify signal format matches EA expectations

## Summary

**Complete Flow:**
```
Telegram Message
    ↓
Telegram Service (parses)
    ↓
Signal Service (validates & stores)
    ↓
Signal Client (sends to server)
    ↓
Server (broadcasts)
    ↓
EA (receives & executes)
```

**Key Components:**
- **Telegram Service**: Listens to Telegram, parses messages
- **Signal Service**: Processes and stores signals
- **Server Manager**: Runs API server for EA
- **Signal Client**: Sends signals to server
- **UI**: Displays signals, allows manual creation

Everything is automated once configured! Just make sure:
1. Telegram bot is running
2. Server is running
3. EA is connected

Then signals flow automatically from Telegram → App → EA! 🚀

