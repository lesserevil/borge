#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "Google Drive API Setup for Borge"
echo -e "==========================================${NC}"
echo ""

# Configuration
PROJECT_ID="borge-music-viewer"
APP_PACKAGE_NAME="com.lesserevil.borge"
APP_NAME="Borge Music Viewer"

# Step 1: Check if gcloud is authenticated
echo -e "${YELLOW}Step 1: Checking gcloud authentication...${NC}"
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo -e "${RED}Not authenticated with gcloud.${NC}"
    echo "Please run: gcloud auth login"
    exit 1
fi
ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1)
echo -e "${GREEN}✓ Authenticated as: $ACCOUNT${NC}"
echo ""

# Step 2: Create or select project
echo -e "${YELLOW}Step 2: Setting up Google Cloud project...${NC}"
if gcloud projects describe "$PROJECT_ID" &>/dev/null; then
    echo -e "${GREEN}✓ Project '$PROJECT_ID' already exists${NC}"
else
    echo "Creating new project '$PROJECT_ID'..."
    gcloud projects create "$PROJECT_ID" --name="$APP_NAME"
    echo -e "${GREEN}✓ Project created${NC}"
fi

# Set the project as active
gcloud config set project "$PROJECT_ID"
echo -e "${GREEN}✓ Active project set to: $PROJECT_ID${NC}"
echo ""

# Step 3: Enable billing (if needed)
echo -e "${YELLOW}Step 3: Checking billing...${NC}"
BILLING_ENABLED=$(gcloud beta billing projects describe "$PROJECT_ID" --format="value(billingEnabled)" 2>/dev/null || echo "false")

if [ "$BILLING_ENABLED" = "False" ]; then
    echo -e "${YELLOW}⚠ Billing is not enabled for this project${NC}"
    echo "Google Drive API requires a billing account (free tier is sufficient)"
    echo ""
    echo "Please enable billing manually:"
    echo "1. Visit: https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID"
    echo "2. Link a billing account (you won't be charged for API usage within free tier)"
    echo ""
    read -p "Press Enter after enabling billing to continue..."
else
    echo -e "${GREEN}✓ Billing is enabled${NC}"
fi
echo ""

# Step 4: Enable required APIs
echo -e "${YELLOW}Step 4: Enabling required APIs...${NC}"
echo "Enabling Google Drive API..."
gcloud services enable drive.googleapis.com
echo -e "${GREEN}✓ Drive API enabled${NC}"

echo "Enabling Google Sign-In..."
gcloud services enable people.googleapis.com
gcloud services enable gmail.googleapis.com
echo -e "${GREEN}✓ Google Sign-In APIs enabled${NC}"
echo ""

# Step 5: Get Android SHA-1 fingerprints
echo -e "${YELLOW}Step 5: Getting Android SHA-1 fingerprints...${NC}"

# Debug keystore
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"
if [ -f "$DEBUG_KEYSTORE" ]; then
    echo "Getting SHA-1 from debug keystore..."
    DEBUG_SHA1=$(keytool -list -v -keystore "$DEBUG_KEYSTORE" -alias androiddebugkey -storepass android -keypass android 2>/dev/null | grep "SHA1:" | awk '{print $2}')
    echo -e "${GREEN}✓ Debug SHA-1: $DEBUG_SHA1${NC}"
else
    echo -e "${RED}✗ Debug keystore not found at $DEBUG_KEYSTORE${NC}"
    DEBUG_SHA1=""
fi

# Release keystore (if exists)
RELEASE_KEYSTORE="$HOME/.android/release.keystore"
RELEASE_SHA1=""
if [ -f "$RELEASE_KEYSTORE" ]; then
    echo "Getting SHA-1 from release keystore..."
    read -sp "Enter release keystore password: " RELEASE_PASS
    echo ""
    RELEASE_SHA1=$(keytool -list -v -keystore "$RELEASE_KEYSTORE" -storepass "$RELEASE_PASS" 2>/dev/null | grep "SHA1:" | head -1 | awk '{print $2}')
    if [ -n "$RELEASE_SHA1" ]; then
        echo -e "${GREEN}✓ Release SHA-1: $RELEASE_SHA1${NC}"
    fi
fi
echo ""

# Step 6: Configure OAuth consent screen
echo -e "${YELLOW}Step 6: Configuring OAuth consent screen...${NC}"
echo "Setting up consent screen for external users..."

# Note: This requires manual configuration via web console
echo -e "${YELLOW}⚠ OAuth consent screen must be configured manually${NC}"
echo ""
echo "Please complete these steps in the Google Cloud Console:"
echo "1. Visit: https://console.cloud.google.com/apis/credentials/consent?project=$PROJECT_ID"
echo "2. Select 'External' user type and click CREATE"
echo "3. Fill in the required fields:"
echo "   - App name: $APP_NAME"
echo "   - User support email: $ACCOUNT"
echo "   - Developer contact: $ACCOUNT"
echo "4. Click 'SAVE AND CONTINUE' through all steps"
echo "5. Add your email as a test user (for testing before verification)"
echo ""
read -p "Press Enter after completing OAuth consent screen setup..."
echo ""

# Step 7: Create OAuth 2.0 Client ID
echo -e "${YELLOW}Step 7: Creating OAuth 2.0 credentials...${NC}"

# Check if credentials already exist
EXISTING_CLIENTS=$(gcloud alpha iap oauth-clients list --format="value(name)" 2>/dev/null | wc -l)

if [ "$EXISTING_CLIENTS" -gt 0 ]; then
    echo -e "${YELLOW}⚠ OAuth clients already exist. Creating new one...${NC}"
fi

echo "Creating Android OAuth client..."
echo ""
echo -e "${YELLOW}⚠ OAuth client creation must be done manually${NC}"
echo ""
echo "Please complete these steps:"
echo "1. Visit: https://console.cloud.google.com/apis/credentials?project=$PROJECT_ID"
echo "2. Click 'CREATE CREDENTIALS' → 'OAuth client ID'"
echo "3. Select Application type: 'Android'"
echo "4. Enter:"
echo "   - Name: $APP_NAME (Android)"
echo "   - Package name: $APP_PACKAGE_NAME"
if [ -n "$DEBUG_SHA1" ]; then
    echo "   - SHA-1 fingerprint (debug): $DEBUG_SHA1"
fi
if [ -n "$RELEASE_SHA1" ]; then
    echo "   - SHA-1 fingerprint (release): $RELEASE_SHA1"
fi
echo "5. Click 'CREATE'"
echo ""
echo "If you need to add multiple SHA-1 fingerprints:"
echo "  - Create separate OAuth clients for debug and release"
echo "  OR"
echo "  - Edit the client after creation to add multiple fingerprints"
echo ""
read -p "Press Enter after creating OAuth client..."
echo ""

# Step 8: Save configuration
echo -e "${YELLOW}Step 8: Saving configuration...${NC}"

CONFIG_FILE="$HOME/.config/borge/google-drive-config.sh"
mkdir -p "$(dirname "$CONFIG_FILE")"

cat > "$CONFIG_FILE" << EOF
# Google Drive API Configuration for Borge
# Generated: $(date)

export GOOGLE_CLOUD_PROJECT_ID="$PROJECT_ID"
export ANDROID_PACKAGE_NAME="$APP_PACKAGE_NAME"
export DEBUG_SHA1="$DEBUG_SHA1"
export RELEASE_SHA1="$RELEASE_SHA1"

# Note: OAuth Client ID will be automatically discovered by google-sign-in
# based on the package name and SHA-1 fingerprint at runtime
EOF

echo -e "${GREEN}✓ Configuration saved to: $CONFIG_FILE${NC}"
echo ""

# Step 9: Update Android configuration
echo -e "${YELLOW}Step 9: Checking Android app configuration...${NC}"

ANDROID_MANIFEST="/home/shedwards/src/borge/flutter/android/app/src/main/AndroidManifest.xml"
BUILD_GRADLE="/home/shedwards/src/borge/flutter/android/app/build.gradle"

# Check package name in build.gradle
if grep -q "namespace.*$APP_PACKAGE_NAME" "$BUILD_GRADLE" || grep -q "applicationId.*$APP_PACKAGE_NAME" "$BUILD_GRADLE"; then
    echo -e "${GREEN}✓ Package name is correctly set in build.gradle${NC}"
else
    echo -e "${YELLOW}⚠ Package name may need to be updated in build.gradle${NC}"
    echo "   Current package should be: $APP_PACKAGE_NAME"
fi

echo ""

# Step 10: Summary and next steps
echo -e "${GREEN}=========================================="
echo "Setup Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Configuration Summary:"
echo "  • Project ID: $PROJECT_ID"
echo "  • Package Name: $APP_PACKAGE_NAME"
if [ -n "$DEBUG_SHA1" ]; then
    echo "  • Debug SHA-1: $DEBUG_SHA1"
fi
if [ -n "$RELEASE_SHA1" ]; then
    echo "  • Release SHA-1: $RELEASE_SHA1"
fi
echo ""
echo "Next Steps:"
echo "1. Build the app: cd flutter && flutter build apk --debug"
echo "2. Install on device: flutter install"
echo "3. Test Google Drive sign-in"
echo ""
echo "Useful Commands:"
echo "  • View project: https://console.cloud.google.com/home/dashboard?project=$PROJECT_ID"
echo "  • View credentials: https://console.cloud.google.com/apis/credentials?project=$PROJECT_ID"
echo "  • View API usage: https://console.cloud.google.com/apis/dashboard?project=$PROJECT_ID"
echo ""
echo -e "${BLUE}Happy coding!${NC}"
