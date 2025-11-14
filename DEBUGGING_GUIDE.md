# Debugging Guide - Server Connection Issues

## Problem: Browser/Phone can't connect to ngrok URL

If the ngrok URL keeps loading or times out, follow these steps:

---

## Step 1: Verify Server is Running Locally

### Test 1: Check if server starts
1. Open Flutter app on laptop
2. Go to **Server** tab
3. Click **Start Server**
4. **Check the console/terminal** - you should see:
   ```
   ✅ REST API server running on port 8080
      Local: http://localhost:8080
      Health check: http://localhost:8080/
   ```
5. If you see an error, note it down

### Test 2: Test local connection
1. After starting server, the app will automatically test it
2. You should see: **"✅ Server started and responding!"**
3. If you see **"⚠️ Server started but not responding"**, the server isn't working

### Test 3: Test in browser (on laptop)
1. Open browser on **the same laptop** where server is running
2. Go to: `http://localhost:8080/`
3. You should see:
   ```json
   {"status":"success","message":"Trade Signal API is running","version":"1.0.0"}
   ```
4. If this doesn't work, **the server isn't running properly**

---

## Step 2: Check ngrok

### Test 1: Verify ngrok is running
1. Check terminal where you ran `ngrok http 8080`
2. Should show:
   ```
   Forwarding   https://abc123.ngrok.io -> http://localhost:8080
   ```
3. If ngrok shows errors, restart it

### Test 2: Test ngrok URL from laptop browser
1. On **the same laptop**, open browser
2. Go to: `https://your-ngrok-url.ngrok-free.dev:8080/`
3. **First time:** You might see ngrok warning page - click "Visit Site"
4. Should see the same JSON response as localhost test
5. If this doesn't work, ngrok isn't forwarding correctly

---

## Step 3: Common Issues & Fixes

### Issue 1: Port Already in Use
**Error:** `Port 8080 is already in use`

**Fix:**
1. Find what's using port 8080:
   - Windows: `netstat -ano | findstr :8080`
   - Mac/Linux: `lsof -i :8080`
2. Kill the process or use different port (e.g., 8081)
3. Update ngrok: `ngrok http 8081`

### Issue 2: Server Starts But Doesn't Respond
**Symptom:** Server shows "running" but browser/phone can't connect

**Possible causes:**
1. Firewall blocking port 8080
2. Server binding issue
3. Flutter/Dart networking issue

**Fix:**
1. Check Windows Firewall (allow port 8080)
2. Try different port (8081, 8082)
3. Restart Flutter app
4. Check console for errors

### Issue 3: ngrok Shows 502 Bad Gateway
**Symptom:** ngrok terminal shows `502 Bad Gateway` errors

**Cause:** Server isn't running or not responding

**Fix:**
1. Make sure server is started in app
2. Test `http://localhost:8080/` in browser first
3. If localhost works but ngrok doesn't, restart ngrok

### Issue 4: Browser Keeps Loading
**Symptom:** Browser shows loading spinner forever

**Possible causes:**
1. Server not running
2. ngrok not forwarding
3. Network/firewall issue

**Fix:**
1. Test `http://localhost:8080/` first
2. If localhost works, check ngrok
3. If localhost doesn't work, server issue

---

## Step 4: Debugging Checklist

Before testing from phone, verify:

- [ ] **Server starts** (no errors in console)
- [ ] **Local test works** (`http://localhost:8080/` in browser)
- [ ] **ngrok is running** (terminal shows forwarding)
- [ ] **ngrok URL works** (from laptop browser)
- [ ] **No firewall blocking** (Windows/Mac firewall)
- [ ] **Port not in use** (check with netstat/lsof)

---

## Step 5: Test from Phone

**Only after all laptop tests pass:**

1. Phone Settings → Enter ngrok URL: `https://your-url.ngrok-free.dev:8080`
2. Click "Test Connection"
3. Should see "Connection successful!"

If phone test fails but laptop browser works:
- Check phone internet connection
- Try different network (mobile data vs WiFi)
- Verify URL is correct (no typos)

---

## Quick Test Commands

### Test local server:
```bash
curl http://localhost:8080/
```

### Test ngrok (from laptop):
```bash
curl https://your-url.ngrok-free.dev:8080/
```

### Check if port is in use (Windows):
```bash
netstat -ano | findstr :8080
```

### Check if port is in use (Mac/Linux):
```bash
lsof -i :8080
```

---

## Still Not Working?

1. **Check Flutter console** for any errors
2. **Check ngrok terminal** for connection errors
3. **Try different port** (8081, 8082, etc.)
4. **Restart everything:**
   - Stop server in app
   - Stop ngrok (Ctrl+C)
   - Restart server
   - Restart ngrok
5. **Check Windows Firewall** - allow port 8080

---

## Expected Behavior

✅ **Working:**
- Server starts → Console shows "✅ REST API server running"
- Local test → Browser shows JSON response
- ngrok test → Browser shows JSON response (after clicking "Visit Site")
- Phone test → "Connection successful!"

❌ **Not Working:**
- Server starts but no console message
- Local test → Browser shows error/timeout
- ngrok test → Browser keeps loading
- Phone test → Timeout error

---

**Remember:** Always test `http://localhost:8080/` on the laptop first. If that doesn't work, the server isn't running properly, and ngrok won't help.

