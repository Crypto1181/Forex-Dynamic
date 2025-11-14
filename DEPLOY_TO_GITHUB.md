# Deploy Flutter Web App to GitHub Pages

## Step 1: Create GitHub Repository

1. Go to GitHub.com
2. Click "New repository"
3. Name it: `forex-signal-app` (or any name)
4. Make it **Public** (required for free GitHub Pages)
5. Don't initialize with README
6. Click "Create repository"

## Step 2: Initialize Git (if not already)

```bash
cd "/home/programmer/Documents/my flutter project/forex_dynamic"
git init
git add .
git commit -m "Initial commit"
```

## Step 3: Add GitHub Remote

```bash
git remote add origin https://github.com/YOUR_USERNAME/forex-signal-app.git
git branch -M main
git push -u origin main
```

## Step 4: Deploy to GitHub Pages

### Option A: Using gh-pages branch (Recommended)

```bash
# Install gh-pages tool (if not installed)
npm install -g gh-pages

# Deploy
cd build/web
git init
git add .
git commit -m "Deploy web app"
git branch -M gh-pages
git remote add origin https://github.com/YOUR_USERNAME/forex-signal-app.git
git push -u origin gh-pages
```

### Option B: Using GitHub Actions (Automatic)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy Flutter Web

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      - run: flutter pub get
      - run: flutter build web --release
      - uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./build/web
```

## Step 5: Enable GitHub Pages

1. Go to repository Settings
2. Scroll to "Pages"
3. Source: Select "gh-pages" branch
4. Click "Save"

## Step 6: Access Your App

Your app will be available at:
`https://YOUR_USERNAME.github.io/forex-signal-app/`

---

## ⚠️ IMPORTANT: Server Limitation

**The web app will work for the UI, but the SERVER part won't work in browser.**

**Why:** Browsers can't run servers due to security restrictions.

**Solution:**
- Client uses web app on iPhone (for UI/managing signals)
- Client still needs native app on laptop (for server)
- OR: You host the server separately (not in browser)

**Tell client:**
"The web app works on your iPhone for managing signals, but you still need to run the server on your laptop. The server can't run in a browser."

