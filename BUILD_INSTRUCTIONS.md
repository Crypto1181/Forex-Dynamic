# Build Windows App - Instructions

## Option 1: GitHub Actions (Recommended - Automatic)

1. Push your code to GitHub
2. Go to Actions tab in your repository
3. Click "Build Windows App" workflow
4. Click "Run workflow"
5. Wait for build to complete
6. Download the artifact (ZIP file)
7. Send ZIP to client

## Option 2: Use Windows Machine

If you have access to a Windows machine:

```bash
flutter build windows --release
```

The built app will be in: `build/windows/x64/runner/Release/`

Zip the entire `Release` folder and send to client.

## Option 3: Ask Client to Build

Send client the source code and ask them to:
1. Install Flutter on their Windows laptop
2. Run: `flutter build windows --release`
3. Run the app from `build/windows/x64/runner/Release/`

## What to Send Client

**Option A: Built app (if you build it)**
- ZIP file containing the Release folder
- Instructions to extract and run `forex_dynamic.exe`

**Option B: Source code (if client builds)**
- Entire project folder
- Instructions to build

## Client Installation Instructions

1. Extract the ZIP file
2. Open the `Release` folder
3. Double-click `forex_dynamic.exe` to run
4. Go to Server tab
5. Click "Start Server"
6. Run ngrok: `ngrok http 8080`
7. Share ngrok URL

