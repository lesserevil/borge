# Android Remote Development - Quick Setup Guide

Use your local Android device with remote Flutter development.

## 🚀 Quick Setup (3 Steps)

### Step 1: Check Local Machine (where Android device is)

Copy and run the local diagnostic script:

```bash
# Copy this script to your local machine
scp your-remote:/home/shedwards/src/borge/scripts/check-android-local.sh ~/

# Make it executable
chmod +x ~/check-android-local.sh

# Run it
~/check-android-local.sh
```

**Expected output:** "✅ Local Android setup is complete!"

If you see errors, follow the on-screen troubleshooting steps.

### Step 2: Set Up VS Code Port Forwarding

**In VS Code** (while connected to remote via SSH):

**Option A - GUI (Easiest):**
1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
2. Type: `Forward a Port`
3. Enter: `5037`
4. Click on the port in the PORTS tab
5. Make sure it says "Remote" (not "Local")

**Option B - SSH Config (Permanent):**

On your **local machine**, edit `~/.ssh/config`:

```ssh
Host my-dev-server
    HostName your-server.example.com
    User shedwards
    RemoteForward 5037 localhost:5037
```

Then reconnect VS Code.

### Step 3: Verify on Remote

In your VS Code terminal (connected to remote):

```bash
# Check devices
~/src/borge/scripts/check-android-connection.sh
```

**Expected output:** "✅ All checks passed! Ready to deploy."

## 🎯 Deploy Your App

Once setup is complete:

```bash
# Deploy to Android device
make flutter-run-remote
```

## 📊 Diagnostic Scripts

| Script | Where to Run | Purpose |
|--------|-------------|---------|
| `check-android-local.sh` | **Local machine** | Verify Android device is connected and authorized |
| `check-android-connection.sh` | **Remote (VS Code)** | Verify port forwarding and remote connection |

## 🐛 Common Issues

### "No devices found" on remote

**Cause:** Port forwarding not configured or local ADB not running

**Fix:**
1. On local: `adb start-server && adb devices` (should show device)
2. In VS Code: Verify port 5037 is forwarded (check PORTS tab)
3. On remote: `adb devices` (should show same device)

### "unauthorized" device

**Cause:** USB debugging not authorized

**Fix:**
1. Check your Android device screen
2. Accept "Allow USB debugging" prompt
3. Check "Always allow from this computer"
4. Run `adb devices` again

### Device not detected at all

**Cause:** USB debugging not enabled, bad cable, or wrong mode

**Fix:**
1. Enable Developer Options (tap Build Number 7 times)
2. Enable USB Debugging in Developer Options
3. Change USB mode to "File Transfer" (not "Charging only")
4. Try different USB cable
5. Run `adb kill-server && adb start-server`

### Port forwarding wrong direction

**Cause:** Port forwarded "Local → Remote" instead of "Remote → Local"

**Fix:**
1. In VS Code PORTS tab, delete port 5037
2. Re-add it
3. Right-click → ensure it's set to "Remote" origin

## ✅ Success Indicators

When everything is working:

**Local machine:**
```bash
$ adb devices
List of devices attached
ABC123    device
```

**Remote (VS Code terminal):**
```bash
$ adb devices
List of devices attached
ABC123    device  ← Same device!

$ make flutter-run-remote
📱 Running Flutter on remote Android device...
Found 2 connected devices:
  Android SDK • ABC123 • android-arm64
  Linux       • linux  • linux-x64
```

## 📚 Documentation

- Full guide: `/home/shedwards/src/borge/docs/ANDROID_REMOTE_SETUP.md`
- Local diagnostic: `~/src/borge/scripts/check-android-local.sh`
- Remote diagnostic: `~/src/borge/scripts/check-android-connection.sh`

## 💡 Pro Tips

1. **Keep ADB running**: Don't stop ADB server on local machine while developing
2. **Persistent connection**: Add RemoteForward to SSH config for automatic setup
3. **Multiple devices**: All local Android devices will be forwarded automatically
4. **Hot reload**: Works normally over the SSH tunnel!

---

**Need help?** Run the diagnostic scripts - they'll tell you exactly what's wrong and how to fix it! 🔧
