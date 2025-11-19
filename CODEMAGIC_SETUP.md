# Codemagic Setup Guide for iOS Builds

This guide will help you set up Codemagic to build your Flutter iOS app.

## Prerequisites
- ✅ GitHub repository: `Crypto1181/Forex-Dynamic`
- ✅ Apple ID: `oladayoapple@gmail.com`
- ✅ Apple Developer Team ID: `X258ZS94H6`
- ✅ Free Apple Developer Account (no paid account needed!)

## Step 1: Sign Up for Codemagic

1. Go to **https://codemagic.io**
2. Click **"Get started"** or **"Sign up"**
3. Choose **"Sign up with GitHub"** (recommended since your repo is on GitHub)
4. Authorize Codemagic to access your GitHub account
5. You'll get **500 free build minutes per month** on the free tier

## Step 2: Connect Your Repository

1. After signing in, click **"Add application"**
2. Select **GitHub** as your source
3. Find and select **`Crypto1181/Forex-Dynamic`**
4. Click **"Add application"**

## Step 3: Configure iOS Code Signing

Codemagic can automatically generate certificates for you! Here's how:

### Option A: Automatic Certificate Generation (Easiest)

1. In your Codemagic app settings, go to **"Code signing"**
2. Click **"Add credentials"** → **"iOS"**
3. Choose **"Automatic"** code signing
4. Enter your Apple ID credentials:
   - **Apple ID**: `oladayoapple@gmail.com`
   - **Password**: (your Apple ID password)
   - **Team ID**: `X258ZS94H6`
5. Codemagic will automatically:
   - Generate certificates
   - Create provisioning profiles
   - Register your device (if needed)

### Option B: Manual Certificate Upload (If you have existing certificates)

If you prefer to use your existing certificate from the Mac mini:

1. Go to **"Code signing"** → **"Add credentials"** → **"iOS"**
2. Choose **"Manual"** code signing
3. Upload your certificate and provisioning profile

## Step 4: Configure Build Settings

1. In your Codemagic app, go to **"Settings"** → **"Workflow settings"**
2. The `codemagic.yaml` file is already in your repo, so Codemagic will detect it automatically
3. Verify the workflow settings:
   - **Instance type**: `mac_mini_m1` (already configured)
   - **Flutter version**: `stable` (already configured)
   - **Xcode version**: `latest` (already configured)

## Step 5: Add Your Device UDID (For Free Developer Account)

Since you have a **free Apple Developer account**, you need to register your device:

1. In Codemagic, go to **"Code signing"** → **"iOS"**
2. Find **"Registered devices"** section
3. Click **"Add device"**
4. Enter:
   - **Device name**: `My iPhone`
   - **UDID**: `00008120-001158262EC2201E`
5. Save

## Step 6: Start Your First Build

1. In Codemagic, go to your app dashboard
2. Click **"Start new build"**
3. Select **"ios-workflow"** (from your codemagic.yaml)
4. Choose your branch: **`main`**
5. Click **"Start build"**

## Step 7: Download Your IPA

1. Once the build completes, you'll receive an email at `oladayoapple@gmail.com`
2. In Codemagic, go to **"Builds"**
3. Click on your completed build
4. Download the **`.ipa`** file from the artifacts section

## Troubleshooting

### Build fails with "No provisioning profile"
- Make sure your device UDID is registered (Step 5)
- Check that your Apple ID credentials are correct

### Build fails with "CocoaPods error"
- The `codemagic.yaml` already includes CocoaPods configuration
- Codemagic handles this automatically

### Build takes too long
- Free tier has a 120-minute limit per build (already configured)
- Consider upgrading if you need longer builds

## Your Codemagic Configuration

The `codemagic.yaml` file in your repo includes:
- ✅ Flutter stable version
- ✅ Latest Xcode
- ✅ iOS IPA build
- ✅ Email notifications to `oladayoapple@gmail.com`
- ✅ 120-minute build timeout

## Next Steps

1. **Sign up** at https://codemagic.io
2. **Connect** your GitHub repo
3. **Configure** code signing (automatic is easiest)
4. **Add** your device UDID
5. **Start** your first build!

## Support

- Codemagic Docs: https://docs.codemagic.io
- Codemagic Community: https://codemagicio.slack.com
- Your project: https://github.com/Crypto1181/Forex-Dynamic

---

**Note**: Your free Apple Developer account works perfectly with Codemagic! No need for a paid ($99/year) account.

