# Complete Setup Guide - For You

This guide walks you through setting up everything and what to send to your EA builder.

---

## Step 1: Set Up Laptop Server

### 1.1 Install ngrok

**Windows:**
1. Go to: https://ngrok.com/download
2. Download ngrok for Windows
3. Extract the zip file
4. Place `ngrok.exe` in a folder (e.g., `C:\ngrok\`)

**Mac:**
```bash
brew install ngrok
```

**Linux:**
1. Go to: https://ngrok.com/download
2. Download for Linux
3. Extract and place in `/usr/local/bin/` or your preferred location

### 1.2 Create ngrok Account (Free)

1. Go to: https://dashboard.ngrok.com/signup
2. Sign up for free account
3. Get your authtoken from dashboard
4. Run: `ngrok config add-authtoken YOUR_AUTH_TOKEN`

### 1.3 Start Your Flutter App on Laptop

1. Open your Flutter project
2. Run: `flutter run` (or use your IDE)
3. Wait for app to start

### 1.4 Start Server in App

1. In the app, go to **Server** tab
2. Set port: `8080` (default)
3. Choose connection type: **REST API** (recommended)
4. Click **Start Server**
5. You should see "Server Running" status

### 1.5 Start ngrok Tunnel

1. Open terminal/command prompt
2. Navigate to where ngrok is installed
3. Run: `ngrok http 8080`
4. You'll see output like:
   ```
   Forwarding   https://abc123-def456.ngrok.io -> http://localhost:8080
   ```
5. **Copy the HTTPS URL** (e.g., `https://abc123-def456.ngrok.io`)

**Important:** Keep this terminal window open! If you close it, the tunnel stops.

---

## Step 2: Configure Phone App

### 2.1 Install App on Phone

1. Build and install Flutter app on your phone
2. Or use `flutter run` with phone connected

### 2.2 Configure Remote Server

1. Open app on phone
2. Go to **Settings** tab
3. Enter Server URL: `https://abc123-def456.ngrok.io:8080`
   - Use the URL from ngrok (add `:8080` at the end)
4. Connection Type: **REST API**
5. Click **Test Connection** (optional, to verify)
6. Click **Save**

---

## Step 3: Test Everything

### 3.1 Test from Phone

1. On phone, go to **Signals** tab
2. Click **Create Signal**
3. Fill in signal details
4. Select accountsSETUP_GUIDE
5. Click **Send Now**
6. Should see "Successfully sent signal(s) to EA"

### 3.2 Verify Server is Receiving

1. Check laptop app - signal should appear in Signals tab
2. Check ngrok terminal - you should see HTTP requests

---

## Step 4: What to Send to EA Builder

### 4.1 Information to Share

Send this to your EA builder:

```
Subject: Trade Signal API - Connection Details

Hi [EA Builder Name],

Here are the connection details for the Trade Signal API:

SERVER INFORMATION:
- Server URL: https://abc123-def456.ngrok.io:8080
- Connection Type: REST API (recommended)
- Port: 8080
- Protocol: HTTPS

SIGNAL FORMAT (JSON):
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

HOW TO CONNECT:
1. Send HTTP POST request to: https://abc123-def456.ngrok.io:8080/
2. Content-Type: application/json
3. Body: Signal JSON (see above)

RESPONSE FORMAT:
Success: {"status":"success","message":"Trade signal received","tradeId":"..."}
Error: {"status":"error","message":"Error description","code":"ERROR_CODE"}

Please let me know when you're ready to test the connection.

Thanks!
```

### 4.2 Files to Attach

Attach these files (from your project folder):
1. `EA_INTEGRATION_GUIDE.md` - Complete API specification
2. `test_client.py` - Python test client (for testing)

---

## Step 5: Keep Everything Running

### Daily Setup Checklist

**Every time you want to use the system:**

1. ✅ Start laptop (if not already on)
2. ✅ Start Flutter app on laptop
3. ✅ Start server in app (Server tab → Start Server)
4. ✅ Start ngrok: `ngrok http 8080`
5. ✅ Copy ngrok URL
6. ✅ Update phone app Settings if URL changed (ngrok URLs change on free tier)
7. ✅ Ready to create signals from phone!

**Note:** On ngrok free tier, the URL changes each time you restart ngrok. You'll need to:
- Update phone app Settings with new URL
- Send new URL to EA builder if it changed

---

## Step 6: Optional - Permanent ngrok URL (Paid)

If you want a permanent URL that doesn't change:

1. Upgrade to ngrok paid plan ($8/month)
2. Reserve a domain: `ngrok config add-domain yourname.ngrok.io`
3. Use: `ngrok http --domain=yourname.ngrok.io 8080`
4. URL stays the same: `https://yourname.ngrok.io:8080`

---

## Troubleshooting

### Server Not Starting
- Check if port 8080 is already in use
- Try different port (e.g., 8081)
- Update ngrok: `ngrok http 8081`

### ngrok URL Not Working
- Make sure ngrok is running
- Check ngrok terminal for errors
- Verify server is running in app
- Test with: `curl https://your-ngrok-url.ngrok.io:8080/`

### Phone Can't Connect
- Check Settings → Server URL is correct
- Verify ngrok is running
- Test connection button in Settings
- Check phone internet connection

### EA Can't Connect
- Verify ngrok URL is correct
- Check server is running
- Test with test_client.py
- Verify EA is using correct URL and port

---

## Quick Reference

### ngrok Commands
```bash
# Start tunnel
ngrok http 8080

# With custom domain (paid)
ngrok http --domain=yourname.ngrok.io 8080

# Check status
ngrok http 8080 --log=stdout
```

### Server URLs
- **Local (same network)**: `http://192.168.1.100:8080`
- **ngrok (remote)**: `https://abc123.ngrok.io:8080`
- **For EA**: Use ngrok URL

### Connection Types
- **REST API**: `https://abc123.ngrok.io:8080/` (HTTP POST)
- **WebSocket**: `wss://abc123.ngrok.io:8080/` (persistent)
- **TCP**: May need paid ngrok or alternative

---

## Summary Checklist

Before sending to EA builder:

- [ ] Laptop server running (app + server started)
- [ ] ngrok tunnel active
- [ ] ngrok URL copied
- [ ] Phone app configured with ngrok URL
- [ ] Tested creating signal from phone
- [ ] Verified signal received on laptop
- [ ] Prepared email with connection details
- [ ] Attached EA_INTEGRATION_GUIDE.md
- [ ] Attached test_client.py

---

## What EA Builder Needs

**Minimum:**
- Server URL: `https://abc123.ngrok.io:8080`
- Connection Type: REST API
- Signal JSON format

**Helpful:**
- EA_INTEGRATION_GUIDE.md (full documentation)
- test_client.py (for testing)
- Example signal JSON

That's it! Once set up, you can create signals from your phone, and EAs will receive them automatically. 🚀

