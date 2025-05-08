#!/bin/bash

set -e

APP_NAME="ShutdownScheduler"
SCHEME="ShutdownScheduler"
CONFIGURATION="Release"
PROJECT="ShutdownScheduler.xcodeproj"
ARCHIVE_PATH="build/${APP_NAME}.xcarchive"
EXPORT_PATH="build/export"
EXPORT_OPTIONS_PLIST="ExportOptions.plist"   # 你需自定义或复用现有
DMG_NAME="${APP_NAME}.dmg"
CERT_ID="Developer ID Application: Hangzhou Gravity Cyberinfo Co.,Ltd (6X2HSWDZCR)"  # 替换为你实际的证书名称
NOTARY_PROFILE="AC_PASSWORD"  # 需先用 `xcrun notarytool store-credentials` 配置好

echo "🧹 Cleaning previous builds..."
rm -rf build

echo "🏗️ Archiving..."
xcodebuild archive \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -archivePath "${ARCHIVE_PATH}" \
  -destination 'generic/platform=macOS' \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

echo "📦 Exporting .app..."
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}"

echo "💿 Creating DMG..."
create-dmg \
  --volname "${APP_NAME}" \
  --window-size 800 600 \
  --background "background.png" \
  --icon "${APP_NAME}.app" 200 250 \
  --app-drop-link 600 250 \
  "${DMG_NAME}" \
  "${EXPORT_PATH}/"

echo "🔏 Signing .app..."
codesign --deep --force --verify --verbose \
  --sign "$CERT_ID" "$EXPORT_PATH/$APP_NAME.app"

echo "🔏 Signing .dmg..."
codesign --force --sign "$CERT_ID" "$DMG_NAME"

echo "📨 Submitting for notarization..."
xcrun notarytool submit "$DMG_NAME" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "📎 Stapling notarization ticket..."
xcrun stapler staple "$DMG_NAME"

echo "✅ Build, notarization and DMG creation completed."
