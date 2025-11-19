# Deploy Flutter Web App for iPhone Testing

This guide will help you deploy your Flutter app as a web app so iPhone users can test it in Safari.

## Quick Start

### Option 1: GitHub Pages (Recommended - Free)

1. **Enable GitHub Pages in your repository:**
   - Go to: https://github.com/Crypto1181/Forex-Dynamic/settings/pages
   - Under "Source", select: **"GitHub Actions"**
   - Click **"Save"**

2. **Push the workflow file:**
   ```bash
   git add .github/workflows/deploy-web.yml
   git commit -m "Add web deployment workflow"
   git push origin main
   ```

3. **Wait for deployment:**
   - Go to: https://github.com/Crypto1181/Forex-Dynamic/actions
   - Wait for the "Deploy Flutter Web to GitHub Pages" workflow to complete
   - Your app will be available at: `https://crypto1181.github.io/Forex-Dynamic/`

4. **Share with iPhone users:**
   - Send them the link: `https://crypto1181.github.io/Forex-Dynamic/`
   - They can open it in Safari on their iPhone
   - They can "Add to Home Screen" for app-like experience

### Option 2: Test Locally First

1. **Build the web app:**
   ```bash
   flutter build web --release
   ```

2. **Test locally:**
   ```bash
   cd build/web
   python3 -m http.server 8000
   ```
   Then open: `http://localhost:8000` in your browser

3. **Test on iPhone:**
   - Find your computer's IP address: `ip addr show` or `ifconfig`
   - On iPhone, open Safari and go to: `http://YOUR_IP:8000`
   - Make sure your iPhone and computer are on the same WiFi network

## Features for iPhone Users

✅ **Works in Safari** - No App Store needed
✅ **Add to Home Screen** - Users can add it like an app
✅ **Offline Support** - Basic offline functionality
✅ **Responsive Design** - Works on all iPhone sizes

## Customization

### Change the App Name

Edit `web/index.html`:
```html
<meta name="apple-mobile-web-app-title" content="Forex Dynamic">
<title>Forex Dynamic</title>
```

### Update Icons

Replace icons in `web/icons/`:
- `Icon-192.png` (192x192)
- `Icon-512.png` (512x512)

## Troubleshooting

### Build fails
- Make sure Flutter is up to date: `flutter upgrade`
- Check dependencies: `flutter pub get`

### GitHub Pages not working
- Check repository settings → Pages → Source = "GitHub Actions"
- Check Actions tab for errors

### App not loading on iPhone
- Make sure you're using HTTPS (GitHub Pages provides this)
- Check browser console for errors
- Try clearing Safari cache

## Next Steps

1. ✅ Enable GitHub Pages
2. ✅ Push the workflow file
3. ✅ Wait for deployment
4. ✅ Share the link with testers!

---

**Your app URL will be:** `https://crypto1181.github.io/Forex-Dynamic/`

