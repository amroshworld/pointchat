#!/bin/bash
set -e

APP_PATH="build/ios/iphoneos/Runner.app"
PROFILE_PATH="/Users/amrosh/Library/MobileDevice/Provisioning Profiles/de23e11e-cace-43c3-b323-651a8c36f449.mobileprovision"
IDENTITY="Apple Distribution: Amr Taha (KGY5RUQ34C)"
OUTPUT_DIR="build/ios/ipa"
IPA_PATH="$OUTPUT_DIR/PointChat.ipa"

echo "=== Packaging PointChat iOS App Store Release (Build 5) ==="

mkdir -p "$OUTPUT_DIR"
rm -f "$IPA_PATH"

# Remove back-deployed system Swift dylibs (not needed for iOS 15+)
rm -f "$APP_PATH"/Frameworks/libswift*.dylib

# 1. Embed Mobileprovision
echo "1. Embedding provisioning profile..."
cp "$PROFILE_PATH" "$APP_PATH/embedded.mobileprovision"

# 2. Extract Entitlements
echo "2. Extracting entitlements from provisioning profile..."
security cms -D -i "$PROFILE_PATH" > /tmp/profile.plist
/usr/libexec/PlistBuddy -x -c "Print :Entitlements" /tmp/profile.plist > /tmp/entitlements.plist

# 3. Sign all frameworks
echo "3. Signing embedded frameworks..."
if [ -d "$APP_PATH/Frameworks" ]; then
  find "$APP_PATH/Frameworks" -type d -name "*.framework" | while read -r framework; do
    echo "  Signing $framework"
    codesign --force --sign "$IDENTITY" --timestamp --options runtime "$framework"
  done
fi

# 4. Sign the App Bundle
echo "4. Signing Runner.app bundle..."
codesign --force --sign "$IDENTITY" --timestamp --options runtime --entitlements /tmp/entitlements.plist "$APP_PATH"

# 5. Verify signature
echo "5. Verifying codesign signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

# 6. Create standard IPA package structure (Payload/Runner.app)
echo "6. Creating clean IPA archive..."
rm -rf build/ios/staging
mkdir -p build/ios/staging/Payload
cp -R "$APP_PATH" build/ios/staging/Payload/

cd build/ios/staging
zip -qr "../ipa/PointChat.ipa" Payload
cd ../../..
rm -rf build/ios/staging

echo "=== IPA generated successfully at $IPA_PATH ==="
ls -lh "$IPA_PATH"
