# Deploy to Render.com - Step by Step

## Step 1: Create Render Account
1. Go to: https://render.com
2. Sign up (free account)
3. Verify email

## Step 2: Connect GitHub
1. In Render dashboard, click "New" → "Web Service"
2. Connect your GitHub account
3. Select repository: `Crypto1181/Forex-Dynamic`
4. Click "Connect"

## Step 3: Configure Service
1. **Name:** `forex-signal-server` (or any name)
2. **Region:** Choose closest to you
3. **Branch:** `main`
4. **Root Directory:** Leave empty (or `/`)
5. **Runtime:** `Docker`
6. **Build Command:** Leave empty (Docker handles it)
7. **Start Command:** `dart run bin/server.dart`
8. **Plan:** `Free`

## Step 4: Environment Variables
Add this environment variable:
- **Key:** `PORT`
- **Value:** `8080` (Render will override this, but set it anyway)

## Step 5: Deploy
1. Click "Create Web Service"
2. Wait 5-10 minutes for build and deploy
3. You'll get a URL like: `https://forex-signal-server.onrender.com`

## Step 6: Test
1. Visit your Render URL: `https://your-app.onrender.com/`
2. Should see: `{"status":"success","message":"Trade Signal API is running"}`

## Step 7: Share with Client
Give client this URL:
- **Server URL:** `https://your-app.onrender.com`
- **For EA:** `https://your-app.onrender.com/signals`

## Important Notes
- **Free tier sleeps after 15 minutes of inactivity**
- First request after sleep takes ~30 seconds (wake up time)
- For always-on, upgrade to paid plan ($7/month)
- Or use a service like UptimeRobot to ping every 5 minutes (keeps it awake)

## Keep Server Awake (Free)
Use UptimeRobot (free):
1. Sign up: https://uptimerobot.com
2. Add monitor
3. URL: `https://your-app.onrender.com/`
4. Interval: 5 minutes
5. This keeps server awake (free tier)

---

That's it! Your server will be live and accessible from anywhere.

