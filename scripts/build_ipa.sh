#!/bin/bash
set -euo pipefail

# 1. เคลียร์โฟลเดอร์ build เก่า
rm -rf build/
mkdir -p build

echo "Build Started!"
echo

# 2. ค้นหาชื่อไฟล์ .xcodeproj ในโฟลเดอร์อัตโนมัติ (ไม่ต้องแก้ไขชื่อโปรเจกต์เอง)
PROJECT_FILE=$(ls -d *.xcodeproj | head -n 1)
PROJECT_NAME=$(basename "$PROJECT_FILE" .xcodeproj)

echo "Found Project: $PROJECT_NAME"

# 3. สั่ง Archive โปรเจกต์ โดยปิด Code Signing
xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$PROJECT_NAME" \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  archive \
  -archivePath "$PWD/build/$PROJECT_NAME.xcarchive"

APP_PATH="$PWD/build/$PROJECT_NAME.xcarchive/Products/Applications/$PROJECT_NAME.app"

if [ ! -d "$APP_PATH" ]; then
  echo "Missing app at $APP_PATH"
  exit 1
fi

# 4. จัดโครงสร้างโฟลเดอร์ Payload
rm -rf "$PWD/build/Payload"
mkdir -p "$PWD/build/Payload"
cp -R "$APP_PATH" "$PWD/build/Payload/"

# 5. ใช้ ldid ทำ Pseudo-sign (แบบไม่ต้องใช้ไฟล์ .entitlements)
if command -v ldid >/dev/null 2>&1; then
  echo "Signing with ldid..."
  ldid -S "$PWD/build/Payload/$PROJECT_NAME.app/$PROJECT_NAME"
else
  echo "Warning: ldid not installed, skipping pseudo-signing."
fi

# 6. บีบอัดเป็นไฟล์ .ipa
(cd "$PWD/build" && /usr/bin/zip -qry "$PROJECT_NAME.ipa" Payload)

echo
echo "Build Successful!"
echo "IPA created at: build/$PROJECT_NAME.ipa"
exit 0
