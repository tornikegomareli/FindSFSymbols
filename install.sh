#!/usr/bin/env bash
# Installs the latest FindSFSymbols release.
#
#   curl -fsSL https://raw.githubusercontent.com/tornikegomareli/FindSFSymbols/main/install.sh | bash
#
# Environment:
#   INSTALL_DIR   where the app goes      (default: /Applications, or ~/Applications if that is read-only)
#   NO_OPEN=1     do not start the app after the install
set -euo pipefail

APP="FindSFSymbols"
TEAM_ID="539293JFA3"
URL="https://github.com/tornikegomareli/FindSFSymbols/releases/latest/download/$APP.zip"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "$APP is a macOS app."
MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[[ "$MACOS_MAJOR" -ge 14 ]] || fail "$APP needs macOS 14 or later. This Mac has $(sw_vers -productVersion)."

DEST="${INSTALL_DIR:-/Applications}"
if [[ ! -w "$DEST" ]]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Download $APP"
curl -fsSL "$URL" -o "$WORK/$APP.zip"
/usr/bin/ditto -x -k "$WORK/$APP.zip" "$WORK"

echo "==> Check the signature"
codesign --verify --deep --strict "$WORK/$APP.app" || fail "the signature of the download is not valid"
SIGNATURE="$(codesign -dv "$WORK/$APP.app" 2>&1)"
[[ "$SIGNATURE" == *"TeamIdentifier=$TEAM_ID"* ]] || fail "the download is not signed by the publisher"

echo "==> Install to $DEST"
pkill -x "$APP" 2>/dev/null || true
rm -rf "$DEST/$APP.app"
mv "$WORK/$APP.app" "$DEST/"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/$APP.app/Contents/Info.plist")"
echo "==> Installed $APP $VERSION"
echo "    Summon it from any app with Control-Option-Space."
[[ "${NO_OPEN:-0}" == "1" ]] || open "$DEST/$APP.app"
