#!/usr/bin/env bash
# Cuts a release: bumps the version, builds a universal app, signs it with the Developer ID,
# notarizes and staples it, signs the Sparkle appcast, publishes a GitHub release with the zip,
# and updates the Homebrew cask.
#
#   Scripts/release.sh patch            # 0.1.0 -> 0.1.1   (also: minor, major)
#   Scripts/release.sh 0.2.0            # an exact version
#   Scripts/release.sh patch --dry-run  # build, sign, notarize and verify. Publish nothing.
#
# Environment:
#   NOTARY_PROFILE   notarytool keychain profile  (default: camus-notary)
#   SIGN_IDENTITY    Developer ID identity        (default: Developer ID Application: Techzy LLC (539293JFA3))
#   TAP_REPO         Homebrew tap repository      (default: tornikegomareli/homebrew-tap)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="FindSFSymbols"
REPO="tornikegomareli/FindSFSymbols"
TEAM_ID="539293JFA3"
NOTARY_PROFILE="${NOTARY_PROFILE:-camus-notary}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Techzy LLC ($TEAM_ID)}"
TAP_REPO="${TAP_REPO:-tornikegomareli/homebrew-tap}"
DIST="$ROOT/dist"

step() { printf '\n==> %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

BUMP="${1:-}"
DRY_RUN=0
[[ "${2:-}" == "--dry-run" ]] && DRY_RUN=1
[[ -n "$BUMP" ]] || fail "usage: Scripts/release.sh <patch|minor|major|X.Y.Z> [--dry-run]"

# --- Version ---------------------------------------------------------------
source "$ROOT/version.env"
IFS=. read -r MAJOR MINOR PATCH <<< "$MARKETING_VERSION"
case "$BUMP" in
  patch) VERSION="$MAJOR.$MINOR.$((PATCH + 1))" ;;
  minor) VERSION="$MAJOR.$((MINOR + 1)).0" ;;
  major) VERSION="$((MAJOR + 1)).0.0" ;;
  *) VERSION="$BUMP" ;;
esac
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "the version must be semver, for example 0.2.0 (got '$VERSION')"
NEW_BUILD=$((BUILD_NUMBER + 1))
TAG="v$VERSION"
ZIP="$DIST/$APP_NAME-$VERSION.zip"
# The same bytes under a name with no version. releases/latest/download/FindSFSymbols.zip always works.
STABLE_ZIP="$DIST/$APP_NAME.zip"

# --- Preflight -------------------------------------------------------------
step "Preflight for $TAG (build $NEW_BUILD)"
# With pipefail, `command | grep -q` fails when grep exits before the command ends. So the text goes to a variable.
IDENTITIES="$(security find-identity -v -p codesigning)"
[[ "$IDENTITIES" == *"$SIGN_IDENTITY"* ]] || fail "signing identity not found: $SIGN_IDENTITY"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 || fail "notarytool profile '$NOTARY_PROFILE' not found. Store it one time with:
    xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id <apple-id> --team-id $TEAM_ID --password <app-specific-password>"
if [[ "$DRY_RUN" == 0 ]]; then
  gh auth status >/dev/null 2>&1 || fail "gh is not logged in"
  [[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || fail "release from the main branch"
  [[ -z "$(git status --porcelain)" ]] || fail "the working tree has uncommitted changes"
  git fetch --quiet --tags origin
  ! git rev-parse "$TAG" >/dev/null 2>&1 || fail "the tag $TAG exists already"
fi
echo "  identity, notary profile and repository are ready"

# --- Bump, test, build -----------------------------------------------------
ORIGINAL_VERSION_ENV="$(cat "$ROOT/version.env")"
restore_version() { printf '%s\n' "$ORIGINAL_VERSION_ENV" > "$ROOT/version.env"; }
printf 'MARKETING_VERSION=%s\nBUILD_NUMBER=%s\n' "$VERSION" "$NEW_BUILD" > "$ROOT/version.env"
# A failed or dry run leaves version.env as it was.
trap restore_version EXIT

step "swift test"
swift test 2>&1 | tail -3

step "Build a universal app and sign it with the Developer ID"
APP_IDENTITY="$SIGN_IDENTITY" ARCHES="arm64 x86_64" "$ROOT/Scripts/package_app.sh" release | tail -2
APP="$ROOT/$APP_NAME.app"
codesign --verify --deep --strict "$APP" || fail "the signature does not verify"
SIGNATURE="$(codesign -dv "$APP" 2>&1)"
[[ "$SIGNATURE" == *"TeamIdentifier=$TEAM_ID"* ]] || fail "the app is not signed by team $TEAM_ID"
BUILT="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[[ "$BUILT" == "$VERSION" ]] || fail "the built app reports version '$BUILT', not $VERSION"
echo "  $(lipo -archs "$APP/Contents/MacOS/$APP_NAME"), version $BUILT, team $TEAM_ID"

# --- Notarize --------------------------------------------------------------
step "Notarize with profile '$NOTARY_PROFILE' (this takes a few minutes)"
rm -rf "$DIST" && mkdir -p "$DIST"
/usr/bin/ditto --norsrc -c -k --keepParent "$APP" "$DIST/notarize.zip"
NOTARY_LOG="$(xcrun notarytool submit "$DIST/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)"
echo "$NOTARY_LOG" | grep -E "id:|status:" | tail -2 | sed 's/^/  /'
[[ "$NOTARY_LOG" == *"status: Accepted"* ]] || fail "notarization failed. See: xcrun notarytool log <id> --keychain-profile $NOTARY_PROFILE"
rm "$DIST/notarize.zip"

step "Staple and verify"
xcrun stapler staple "$APP" >/dev/null
xcrun stapler validate "$APP" >/dev/null || fail "the staple ticket is not valid"
spctl -a -t exec -vv "$APP" 2>&1 | sed 's/^/  /'
spctl -a -t exec "$APP" || fail "Gatekeeper rejects the app"

/usr/bin/ditto --norsrc -c -k --keepParent "$APP" "$ZIP"
SHA256="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
echo "  $(basename "$ZIP")  sha256 $SHA256"

# --- Sparkle appcast ---------------------------------------------------------
# generate_appcast signs the zip with the EdDSA key in the login Keychain and adds the version to appcast.xml.
# The Keychain can ask for access the first time. Choose Always Allow, so later releases run unattended.
# Only the versioned zip is in dist/ at this point: generate_appcast refuses two archives with one version.
step "Sparkle appcast"
SPARKLE_BIN="$ROOT/.build/artifacts/sparkle/Sparkle/bin"
[[ -x "$SPARKLE_BIN/generate_appcast" ]] || fail "Sparkle's tools are missing. Run swift build one time."
APPCAST="$ROOT/appcast.xml"
APPCAST_BEFORE="$(cat "$APPCAST" 2>/dev/null || true)"
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/" \
  --link "https://tornikegomareli.github.io/FindSFSymbols/" \
  --full-release-notes-url "https://github.com/$REPO/releases" \
  --maximum-versions 5 \
  -o "$APPCAST" "$DIST"
APPCAST_TEXT="$(cat "$APPCAST")"
[[ "$APPCAST_TEXT" == *"sparkle:edSignature"* ]] || fail "the appcast has no EdDSA signature"
[[ "$APPCAST_TEXT" == *"$APP_NAME-$VERSION.zip"* ]] || fail "the appcast does not name $APP_NAME-$VERSION.zip"
echo "  appcast.xml names $VERSION and carries a signature"

# The copy for releases/latest/download/. It is made after the appcast, for the reason above.
cp "$ZIP" "$STABLE_ZIP"

if [[ "$DRY_RUN" == 1 ]]; then
  # A dry run leaves appcast.xml as it was.
  if [[ -n "$APPCAST_BEFORE" ]]; then printf '%s\n' "$APPCAST_BEFORE" > "$APPCAST"; else rm -f "$APPCAST"; fi
  step "Dry run complete. Nothing was published. The zip is in dist/."
  exit 0
fi

# --- Publish ---------------------------------------------------------------
step "Commit, tag and push"
trap - EXIT
git add version.env appcast.xml
git commit --quiet -m "Release $TAG"
git tag "$TAG"
git push --quiet origin main "$TAG"

step "GitHub release $TAG"
gh release create "$TAG" "$ZIP" "$STABLE_ZIP" --repo "$REPO" --title "$APP_NAME $VERSION" --generate-notes

step "Homebrew cask in $TAP_REPO"
TAP_DIR="$(mktemp -d)"
gh repo clone "$TAP_REPO" "$TAP_DIR" -- --quiet --depth 1
mkdir -p "$TAP_DIR/Casks"
cat > "$TAP_DIR/Casks/findsfsymbols.rb" <<CASK
cask "findsfsymbols" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/$REPO/releases/download/v#{version}/$APP_NAME-#{version}.zip"
  name "$APP_NAME"
  desc "Semantic SF Symbols search with a physics pile"
  homepage "https://tornikegomareli.github.io/FindSFSymbols/"

  depends_on macos: :sonoma

  app "$APP_NAME.app"

  zap trash: [
    "~/Library/Preferences/dev.gomareli.findsfsymbols.plist",
  ]
end
CASK
git -C "$TAP_DIR" add Casks/findsfsymbols.rb
git -C "$TAP_DIR" commit --quiet -m "findsfsymbols $VERSION"
git -C "$TAP_DIR" push --quiet
rm -rf "$TAP_DIR"

step "Released $TAG"
echo "  https://github.com/$REPO/releases/tag/$TAG"
echo "  brew install --cask tornikegomareli/tap/findsfsymbols"
