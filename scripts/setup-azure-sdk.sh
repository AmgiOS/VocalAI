#!/bin/bash
# Downloads and extracts the Azure Speech SDK xcframework for iOS.
# Run this once before building the project.
#
# Usage: ./scripts/setup-azure-sdk.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FRAMEWORKS_DIR="$PROJECT_DIR/Frameworks"
XCFRAMEWORK_DIR="$FRAMEWORKS_DIR/MicrosoftCognitiveServicesSpeech.xcframework"
DOWNLOAD_URL="https://aka.ms/csspeech/iosbinary"
TEMP_DIR="$(mktemp -d)"

echo "=== Azure Speech SDK Setup ==="

# Check if already installed
if [ -d "$XCFRAMEWORK_DIR" ]; then
    echo "xcframework already exists at $XCFRAMEWORK_DIR"
    echo "Delete it first if you want to re-download."
    exit 0
fi

mkdir -p "$FRAMEWORKS_DIR"

echo "Downloading Azure Speech SDK from $DOWNLOAD_URL..."
curl -L -o "$TEMP_DIR/speech-sdk.zip" "$DOWNLOAD_URL"

echo "Extracting xcframework..."
unzip -q "$TEMP_DIR/speech-sdk.zip" -d "$TEMP_DIR/extracted"

# Find the xcframework in the extracted contents
FOUND_XCFRAMEWORK=$(find "$TEMP_DIR/extracted" -name "MicrosoftCognitiveServicesSpeech.xcframework" -type d | head -1)

if [ -z "$FOUND_XCFRAMEWORK" ]; then
    echo "ERROR: MicrosoftCognitiveServicesSpeech.xcframework not found in download."
    echo "Contents of extracted archive:"
    ls -la "$TEMP_DIR/extracted"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Moving xcframework to $FRAMEWORKS_DIR..."
mv "$FOUND_XCFRAMEWORK" "$FRAMEWORKS_DIR/"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "Done! xcframework installed at:"
echo "  $XCFRAMEWORK_DIR"
echo ""
echo "Next steps:"
echo "  1. Open VocalAI.xcodeproj in Xcode"
echo "  2. Go to project settings > Package Dependencies"
echo "  3. Add local package: Packages/AzureSpeechSDK"
echo "  4. Or simply drag Packages/AzureSpeechSDK into the Xcode project navigator"
