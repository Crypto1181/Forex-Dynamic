# Check Server Status - Step by Step

## The Problem
- localhost:8080 not working in Chrome
- ngrok URL timing out
- **Root cause: Server is NOT running**

---

## Step 1: Check if Server is Running

### In Flutter App:
1. Open your Flutter app
2. Go to **Server** tab
3. Look at the status:
   - ✅ **"Server Running"** (green) = Server is running
   - ❌ **"Server Stopped"** (red) = Server is NOT running

### In Terminal/Console:
When you start the server, you should see:
```
✅ REST API server running on port 8080
   Local: http://localhost:8080
```

**If you DON'T see this message, the server didn't start!**

---

## Step 2: Start the Server

1. In Flutter app, go to **Server** tab
2. Make sure **Port** is set to `8080`
3. **Connection Type** should be `REST API`
4. Click **"Start Server"** button
5. **Watch the console/terminal** for messages

### What to Look For:

✅ **Success:**
```
🔄 Starting REST server on port 8080...
✅ REST API server running on port 8080
   Local: http://localhost:8080
```

❌ **Error - Port in use:**
```
❌ Failed to start REST server: ...
Port 8080 is already in use
```
**Fix:** Use different port (8081) or stop other service

❌ **Error - Permission denied:**
```
Permission denied
```
**Fix:** Use port 8080 or higher (not 80, 443, etc.)

❌ **Other error:**
```
❌ Failed to start REST server: [error message]
```
**Share this error message!**

---

## Step 3: Test After Starting

### Test 1: Check Console Message
After clicking "Start Server", check:
- Does console show "✅ REST API server running"?
- Does app show "✅ Server started and responding!"?

### Test 2: Test in Browser
1. Open Chrome on **the same computer**
2. Go to: `http://localhost:8080/`
3. Should see: `{"status":"success","message":"Trade Signal API is running"}`

### Test 3: Use Test Script
```bash
python3 test_server.py
```

---

## Step 4: If Server Won't Start

### Check Console for Errors
Look for error messages like:
- `Port already in use`
- `Permission denied`
- `Address already in use`
- Any other error message

### Common Issues:

**Issue 1: Port Already in Use**
- Another app is using port 8080
- **Fix:** Change port to 8081 in app, update ngrok: `ngrok http 8081`

**Issue 2: No Error Message**
- Server button clicked but nothing happens
- **Check:** Is Flutter app actually running? Check console for any messages

**Issue 3: App Crashes**
- App closes when starting server
- **Check:** Console for crash logs, share error

---

## Step 5: Verify Server is Actually Listening

### Check Port (Linux):
```bash
ss -tuln | grep 8080
# or
sudo lsof -i :8080
```

**Should show:** Something listening on port 8080
**If empty:** Server is NOT running

### Test Connection:
```bash
curl http://localhost:8080/
```

**Should return:** JSON response
**If error:** Server not running

---

## What to Share if Still Not Working

1. **Console output** when clicking "Start Server"
2. **Error message** (if any)
3. **App status** (Server Running or Stopped?)
4. **Port check result** (`ss -tuln | grep 8080`)
5. **curl test result** (`curl http://localhost:8080/`)

---

## Quick Checklist

Before testing ngrok:
- [ ] Flutter app is running
- [ ] Clicked "Start Server" button
- [ ] Console shows "✅ REST API server running"
- [ ] App shows "Server Running" (green)
- [ ] `http://localhost:8080/` works in browser
- [ ] `curl http://localhost:8080/` returns JSON

**If ANY of these fail, the server isn't running properly!**

