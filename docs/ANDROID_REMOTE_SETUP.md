# Android Device Remote Development - VS Code Port Forwarding

Use your local Android device with remote Flutter development via VS Code's built-in port forwarding.

## 🎯 Simple Setup (Using VS Code)

### Step 1: Start ADB on Local Machine

**On your local machine** (where Android device is connected):

```bash
# Start ADB server
adb start-server

# Verify device is connected
adb devices
```

You should see your device listed.

### Step 2: Configure VS Code Port Forwarding

1. **Connect to remote** via VS Code Remote SSH (as you normally do)

2. **Forward the ADB port**:
   - Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
   - Type: "Forward a Port"
   - Choose: "Forward a Port"
   - Enter port: `5037`
   - Select: "Remote → Local" (this forwards remote's 5037 to your local 5037)

   Or use the **Ports tab** in VS Code:
   - Click the "Ports" tab in the bottom panel
   - Click "+" to add port
   - Enter `5037`
   - Right-click → Set Port Label to "ADB Server"

3. **Done!** The port forwarding persists for your SSH session.

### Step 3: Verify on Remote

In your VS Code remote terminal:

```bash
# Check devices (should see your local Android device!)
adb devices

# Run Flutter
cd ~/src/borge/flutter
flutter run
```

## 🚀 Quick Start Script

Use this script on the **remote machine** to check everything:

```bash
~/src/borge/scripts/connect-android-remote.sh
```

## ⚙️ Permanent Setup (Optional)

To automatically forward port 5037 every time you connect via VS Code:

1. On your **local machine**, edit VS Code settings:
   - `Ctrl+,` (or `Cmd+,`) → Search for "remote.SSH.localServerDownload"
   
2. Or add to your local `~/.ssh/config`:

```
Host your-remote-dev
    HostName your-server.com
    User shedwards
    RemoteForward 5037 localhost:5037
```

This way the port forwards automatically when you connect via VS Code!

## 🐛 Troubleshooting

### Device not showing:

```bash
# On LOCAL machine - restart ADB
adb kill-server
adb start-server
adb devices

# In VS Code - re-forward port 5037 if needed
```

### Port already in use on remote:

```bash
# On REMOTE machine (VS Code terminal)
adb kill-server

# Then try again
adb devices
```

### "Unauthorized" device:

- Check your Android device screen
- Accept "Allow USB debugging" prompt
- Check "Always allow from this computer"

## ✅ Success Check

**Local machine terminal:**
```bash
$ adb devices
List of devices attached
ABC123    device
```

**VS Code remote terminal:**
```bash
$ adb devices
List of devices attached
ABC123    device  ← Same device!

$ flutter devices
2 connected devices:
Android SDK (mobile) • ABC123 • android-arm64
Linux (desktop)      • linux  • linux-x64
```

## 💡 Pro Tips

1. **Keep ADB running locally**: Don't stop the ADB server on your local machine while developing

2. **Port forwarding persists**: Once set up in VS Code, it stays active for your entire session

3. **Multiple devices**: If you have multiple Android devices, they'll all be forwarded

4. **Debugging**: Use `flutter run -v` to see verbose output if device isn't detected

---

**That's it!** No scripts needed, just use VS Code's built-in port forwarding. 🎉
