# CircleCI Setup Guide for iOS Builds

This guide will help you set up CircleCI to automatically build your Flutter iOS app.

## Step 1: Create CircleCI Account

1. Go to [circleci.com](https://circleci.com)
2. Sign up with your GitHub account (or create a new account)
3. Authorize CircleCI to access your GitHub repositories

## Step 2: Add Project to CircleCI

1. Go to CircleCI Dashboard
2. Click "Add Projects"
3. Find your repository: `Crypto1181/Forex-Dynamic` (or your repo name)
4. Click "Set Up Project"
5. Select "Use existing config" (we already created `.circleci/config.yml`)

## Step 3: Free Tier Limits

CircleCI Free Tier includes:
- **6,000 build minutes per month**
- **1 concurrent job**
- **macOS builds available** (but consume more minutes)

**Note:** iOS builds require macOS, which uses more build minutes than Linux.

## Step 4: Understanding the Build Config

The `.circleci/config.yml` file includes two build options:

### Option A: Unsigned Build (for testing)
- Job: `build-ios`
- No code signing required
- Good for testing builds
- Cannot be installed on real devices or App Store

### Option B: Signed Build (for App Store)
- Job: `build-ios-signed`
- Requires Apple certificates and provisioning profiles
- Can be distributed via TestFlight or App Store
- Requires additional setup (see below)

## Step 5: For App Store Distribution (Optional)

If you want to build signed iOS apps for App Store/TestFlight:

### 5.1 Get Apple Certificates

1. **Apple Developer Account** ($99/year) - Required
2. **Create Distribution Certificate:**
   - Go to [Apple Developer Portal](https://developer.apple.com)
   - Certificates, Identifiers & Profiles
   - Create a Distribution Certificate
   - Download and install on your Mac
   - Export as `.p12` file

3. **Create Provisioning Profile:**
   - Create an App ID for your app
   - Create a Distribution Provisioning Profile
   - Download the `.mobileprovision` file

### 5.2 Add Secrets to CircleCI

1. Go to your project in CircleCI
2. Click "Project Settings" → "Environment Variables"
3. Add these variables:

   ```
   APPLE_CERTIFICATE_BASE64
   ```
   - Value: Base64 encoded `.p12` certificate
   - To encode: `base64 -i certificate.p12 | pbcopy` (on Mac)

   ```
   APPLE_CERTIFICATE_PASSWORD
   ```
   - Value: Password you used when exporting the certificate

   ```
   APPLE_PROVISIONING_PROFILE_BASE64
   ```
   - Value: Base64 encoded `.mobileprovision` file
   - To encode: `base64 -i profile.mobileprovision | pbcopy` (on Mac)

### 5.3 Enable Signed Builds

Edit `.circleci/config.yml` and uncomment the signed build job:

```yaml
workflows:
  version: 2
  build-workflow:
    jobs:
      - build-ios-signed  # Use this instead of build-ios
```

## Step 6: Trigger Builds

### Automatic Builds
- Every push to your repository triggers a build
- Every pull request triggers a build

### Manual Builds
1. Go to CircleCI Dashboard
2. Select your project
3. Click "Trigger Pipeline"
4. Select branch and click "Trigger"

## Step 7: Download Build Artifacts

After a successful build:

1. Go to the build page in CircleCI
2. Click "Artifacts" tab
3. Download:
   - `ios-build/Runner.app` - The unsigned app
   - `ios-archive/Runner.xcarchive` - The archive (for signed builds)

## Step 8: Install on Device (Unsigned Build)

For unsigned builds, you can only install on:
- iOS Simulator (via Xcode)
- Jailbroken devices

## Step 9: Install via TestFlight (Signed Build)

For signed builds:
1. Use Xcode to export the `.xcarchive` as `.ipa`
2. Upload to App Store Connect
3. Distribute via TestFlight

## Troubleshooting

### Build Fails: "Flutter not found"
- The config installs Flutter automatically
- Check the "Install Flutter" step logs

### Build Fails: "CocoaPods error"
- Check the "Install Pods" step
- May need to update `ios/Podfile`

### Build Fails: "Code signing error"
- Make sure certificates are correctly encoded
- Check that provisioning profile matches your App ID
- Verify certificate password is correct

### Build Takes Too Long
- macOS builds use more minutes
- Consider using Linux for Android builds
- Optimize by caching Flutter and dependencies

## Cost Estimation

**Free Tier:**
- 6,000 minutes/month
- iOS build: ~20-30 minutes each
- You can do ~200-300 iOS builds/month for free

**Paid Plans:**
- Performance Plan: $15/month (25,000 minutes)
- Scale Plan: $200/month (unlimited)

## Next Steps

1. Push the `.circleci/config.yml` to your repository
2. Set up CircleCI account and connect your repo
3. Run your first build
4. (Optional) Set up code signing for App Store builds

## Support

- [CircleCI Docs](https://circleci.com/docs/)
- [Flutter CI/CD Guide](https://docs.flutter.dev/deployment/cd)
- [CircleCI Community](https://discuss.circleci.com/)

