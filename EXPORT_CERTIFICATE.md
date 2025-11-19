# Export Certificate for Codemagic

## Quick Steps

### Method 1: Using Keychain Access (Recommended - Via VNC)

1. **Connect to Mac via VNC** (if not already connected)

2. **Open Keychain Access**
   - Press `Cmd + Space` to open Spotlight
   - Type "Keychain Access" and press Enter
   - Or: Applications → Utilities → Keychain Access

3. **Find Your Certificate**
   - In the left sidebar, select **"login"** keychain
   - In the search box (top right), type: `Apple Development`
   - Find: **"Apple Development: oladayoapple@gmail.com (X258ZS94H6)"**

4. **Export the Certificate**
   - Right-click on the certificate
   - Select **"Export 'Apple Development: oladayoapple@gmail.com (X258ZS94H6)'..."**
   - Choose location: **Desktop**
   - File Format: **Personal Information Exchange (.p12)**
   - Click **"Save"**
   - Enter a password (or leave blank) - **Remember this password!**
   - You may be prompted for your Mac password - enter it

5. **Download to Your Linux Machine**
   ```bash
   scp m1@62.210.150.84:~/Desktop/certificate.p12 ~/Downloads/
   ```
   (Replace `certificate.p12` with the actual filename you saved)

### Method 2: Using Terminal (If GUI doesn't work)

1. **Connect via SSH or VNC Terminal**

2. **Run the export command:**
   ```bash
   security export -t identities -f pkcs12 -P "" -o ~/certificate.p12 951652E1C3BC5DC05A73D5A8841D8CB61AC48EDA
   ```
   (You may be prompted for your Mac password)

3. **Download to Your Linux Machine:**
   ```bash
   scp m1@62.210.150.84:~/certificate.p12 ~/Downloads/
   ```

## Certificate Information

- **Certificate Name**: Apple Development: oladayoapple@gmail.com (X258ZS94H6)
- **Certificate Hash**: 951652E1C3BC5DC05A73D5A8841D8CB61AC48EDA
- **Team ID**: X258ZS94H6
- **Apple ID**: oladayoapple@gmail.com

## Upload to Codemagic

1. Go to Codemagic → **Teams** → **Code signing identities**
2. Click **"Upload a certificate file"**
3. Drag and drop your `.p12` file
4. Enter the password (if you set one during export)
5. Click **"Save"**

## Next Steps

After uploading the certificate:
1. You'll also need to upload a **provisioning profile** (`.mobileprovision` file)
2. Or configure automatic provisioning in Codemagic
3. Add your device UDID: `00008120-001158262EC2201E`

---

**Note**: The `.p12` file contains both your certificate AND private key, which is what Codemagic needs for code signing.

