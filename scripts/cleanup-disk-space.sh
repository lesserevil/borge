#!/bin/bash
set -e

echo "=========================================="
echo "Disk Space Cleanup Script"
echo "=========================================="
echo ""

# Show current disk usage
echo "Current disk usage:"
df -h / | grep -E '(Filesystem|/dev/mapper)'
echo ""

# Function to show space freed
show_freed() {
    local before=$1
    local after=$2
    local freed=$((before - after))
    echo "  → Freed: $(numfmt --to=iec --suffix=B $freed)"
}

# Get initial disk usage
initial_used=$(df / | tail -1 | awk '{print $3}')

echo "Cleanup plan:"
echo "  1. Flutter build artifacts (~1.6G)"
echo "  2. Gradle caches (~5.6G)"
echo "  3. Android build artifacts"
echo "  4. /tmp directory (~4.2G)"
echo "  5. System package caches"
echo ""

read -p "Proceed with cleanup? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# 1. Flutter build artifacts
echo "1. Cleaning Flutter build artifacts..."
if [ -d "/home/shedwards/src/borge/flutter/build" ]; then
    before=$(df / | tail -1 | awk '{print $3}')
    rm -rf /home/shedwards/src/borge/flutter/build
    after=$(df / | tail -1 | awk '{print $3}')
    show_freed $before $after
else
    echo "  → No Flutter build directory found"
fi

# 2. Gradle caches
echo "2. Cleaning Gradle caches..."
if [ -d "$HOME/.gradle" ]; then
    before=$(df / | tail -1 | awk '{print $3}')
    rm -rf "$HOME/.gradle/caches"
    rm -rf "$HOME/.gradle/daemon"
    after=$(df / | tail -1 | awk '{print $3}')
    show_freed $before $after
else
    echo "  → No Gradle cache directory found"
fi

# 3. Android build artifacts
echo "3. Cleaning Android build artifacts..."
if [ -d "/home/shedwards/src/borge/flutter/android" ]; then
    before=$(df / | tail -1 | awk '{print $3}')
    cd /home/shedwards/src/borge/flutter/android
    ./gradlew clean 2>/dev/null || echo "  → Gradlew clean failed (expected if Gradle daemon is locked)"
    rm -rf .gradle
    rm -rf build
    rm -rf app/build
    cd - > /dev/null
    after=$(df / | tail -1 | awk '{print $3}')
    show_freed $before $after
else
    echo "  → No Android directory found"
fi

# 4. Clean /tmp (requires sudo)
echo "4. Cleaning /tmp directory (requires sudo)..."
before=$(df / | tail -1 | awk '{print $3}')
sudo find /tmp -type f -atime +2 -delete 2>/dev/null || true
sudo find /tmp -type d -empty -delete 2>/dev/null || true
after=$(df / | tail -1 | awk '{print $3}')
show_freed $before $after

# 5. System package caches (requires sudo)
echo "5. Cleaning system package caches (requires sudo)..."
before=$(df / | tail -1 | awk '{print $3}')
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove -y
after=$(df / | tail -1 | awk '{print $3}')
show_freed $before $after

# 6. Docker cleanup (if installed)
if command -v docker &> /dev/null; then
    echo "6. Cleaning Docker resources (requires sudo)..."
    before=$(df / | tail -1 | awk '{print $3}')
    sudo docker system prune -af --volumes 2>/dev/null || echo "  → Docker cleanup failed"
    after=$(df / | tail -1 | awk '{print $3}')
    show_freed $before $after
else
    echo "6. Docker not installed, skipping..."
fi

# Calculate total freed
final_used=$(df / | tail -1 | awk '{print $3}')
total_freed=$((initial_used - final_used))

echo ""
echo "=========================================="
echo "Cleanup complete!"
echo "=========================================="
echo "Total space freed: $(numfmt --to=iec --suffix=B $total_freed)"
echo ""
echo "Current disk usage:"
df -h / | grep -E '(Filesystem|/dev/mapper)'
echo ""
