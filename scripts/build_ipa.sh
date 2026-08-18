#!/bin/bash
set -euo pipefail

# 1. เคลียร์โฟลเดอร์ build เก่า
rm -rf build/
mkdir -p build

echo "Build Started!"
echo

# 2. ค้นหาชื่อไฟล์ .xcodeproj ในโฟลเดอร์อัตโนมัติ
PROJECT_FILE=$(ls -d *.xcodeproj | head -n 1)
PROJECT_NAME=$(basename "$PROJECT_FILE" .xcodeproj)

echo "Found Project: $PROJECT_NAME"

# 3. [เพิ่มส่วนนี้] ดึงชื่อ Target แรกในโปรเจกต์ มาสร้าง Shared Scheme ชั่วคราวอัตโนมัติ
TARGET_NAME=$(xcodebuild -list -project "$PROJECT_FILE" | grep -A 10 "Targets:" | tail -n +2 | xargs | cut -d ' ' -f 1)
SCHEME_NAME="$TARGET_NAME"

echo "Auto-generating scheme for Target: $SCHEME_NAME..."
xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME_NAME" -manageAutomaticSchemes >/dev/null 2>&1 || true

# 4. สั่ง Archive โปรเจกต์ โดยใช้ Scheme ที่ตรวจพบ
xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME_NAME" \
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

# 5. จัดโครงสร้างโฟลเดอร์ Payload
rm -rf "$PWD/build/Payload"
mkdir -p "$PWD/build/Payload"
cp -R "$APP_PATH" "$PWD/build/Payload/"

# 6. ใช้ ldid ทำ Pseudo-sign
if command -v ldid >/dev/null 2>&1; then
  echo "Signing with ldid..."
  ldid -S "$PWD/build/Payload/$PROJECT_NAME.app/$PROJECT_NAME"
else
  echo "Warning: ldid not installed, skipping pseudo-signing."
fi

# 7. บีบอัดเป็นไฟล์ .ipa
(cd "$PWD/build" && /usr/bin/zip -qry "$PROJECT_NAME.ipa" Payload)

echo
echo "Build Successful!"
echo "IPA created at: build/$PROJECT_NAME.ipa"
exit 0
