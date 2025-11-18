# CircleCI Quick Start for iOS Builds

## 🚀 Quick Setup (5 minutes)

### 1. Sign up for CircleCI
- Go to [circleci.com](https://circleci.com)
- Sign up with GitHub
- It's **FREE** (6,000 build minutes/month)

### 2. Connect Your Repository
- Click "Add Projects" in CircleCI
- Find `Forex-Dynamic` (or your repo name)
- Click "Set Up Project"
- Select "Use existing config" ✅

### 3. Push the Config
```bash
git add .circleci/config.yml
git commit -m "Add CircleCI config for iOS builds"
git push
```

### 4. Your First Build
- CircleCI automatically starts building when you push
- Watch it in real-time on CircleCI dashboard
- Build takes ~20-30 minutes

### 5. Download Your Build
- After build completes, go to "Artifacts" tab
- Download `ios-build/Runner.app`

## 📱 What You Get

✅ **Automatic builds** on every push  
✅ **Free tier**: 200-300 iOS builds/month  
✅ **No Mac needed** - builds in the cloud  
✅ **Build artifacts** ready to download  

## ⚠️ Important Notes

- **Unsigned builds** (default) can only run on simulator
- For **real devices/App Store**, you need signed builds
- See `CIRCLECI_SETUP.md` for signed build setup

## 💰 Cost

**FREE** for:
- 6,000 build minutes/month
- ~200-300 iOS builds/month

**Paid** (if needed):
- $15/month for 25,000 minutes
- $200/month for unlimited

## 🆘 Need Help?

See `CIRCLECI_SETUP.md` for detailed instructions.

