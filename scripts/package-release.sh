#!/usr/bin/env zsh
# Build the release artifacts into dist/:
#
#   Zapmenu-<version>-universal.zip          Zapmenu.app (arm64 + x86_64)
#   zapmenu-<version>-aarch64-macos.tar.gz   bare binary
#   zapmenu-<version>-x86_64-macos.tar.gz    bare binary
#   checksums.txt
#
# Usage:
#   ./scripts/package-release.sh v1.3.0
#
# Environment (all optional):
#   SIGN_IDENTITY   codesign identity. Default "-" (ad-hoc). A Developer ID
#                   or the self-signed cert from create-signing-cert.sh keeps
#                   the Device Control grant valid across releases.
#   NOTARY_APPLE_ID, NOTARY_TEAM_ID, NOTARY_PASSWORD
#                   When all three are set, the app is signed with the hardened
#                   runtime, notarized and stapled. Needs a Developer ID identity.

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <version, e.g. v1.3.0>" >&2
    exit 1
fi

TAG=$1
VERSION=${TAG#v}
IDENTITY=${SIGN_IDENTITY:--}
BUNDLE_ID=com.kaynetik.zapmenu

ROOT=${0:A:h:h}
cd "$ROOT"

DIST=$ROOT/dist
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
rm -rf "$DIST"
mkdir -p "$DIST"

notarize=false
if [[ -n ${NOTARY_APPLE_ID:-} && -n ${NOTARY_TEAM_ID:-} && -n ${NOTARY_PASSWORD:-} ]]; then
    if [[ $IDENTITY == - ]]; then
        echo "Notarization needs SIGN_IDENTITY set to a Developer ID identity." >&2
        exit 1
    fi
    notarize=true
fi

sign() {
    local -a args=(--force --sign "$IDENTITY" --identifier "$BUNDLE_ID")
    if $notarize; then args+=(--options runtime --timestamp); fi
    codesign "${args[@]}" "$1"
}

for arch in aarch64 x86_64; do
    echo "==> building $arch"
    zig build -Dtarget=$arch-macos -Doptimize=ReleaseFast --prefix "$STAGE/$arch"
done

echo "==> bare binaries"
for arch in aarch64 x86_64; do
    sign "$STAGE/$arch/bin/zapmenu"
    tar -czf "$DIST/zapmenu-$TAG-$arch-macos.tar.gz" -C "$STAGE/$arch/bin" zapmenu
done

echo "==> universal Zapmenu.app"
APP=$STAGE/Zapmenu.app
mkdir -p "$APP/Contents/MacOS"
lipo -create "$STAGE/aarch64/bin/zapmenu" "$STAGE/x86_64/bin/zapmenu" \
    -output "$APP/Contents/MacOS/zapmenu"
cp macos/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $VERSION" \
    -c "Set :CFBundleVersion $VERSION" \
    "$APP/Contents/Info.plist"
sign "$APP"
codesign --verify --strict --verbose=2 "$APP"

ZIP=$DIST/Zapmenu-$TAG-universal.zip
# ditto keeps the bundle's signature metadata intact; plain zip may not.
ditto -c -k --keepParent "$APP" "$ZIP"

if $notarize; then
    echo "==> notarizing"
    xcrun notarytool submit "$ZIP" \
        --apple-id "$NOTARY_APPLE_ID" \
        --team-id "$NOTARY_TEAM_ID" \
        --password "$NOTARY_PASSWORD" \
        --wait
    xcrun stapler staple "$APP"
    rm "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
fi

(cd "$DIST" && shasum -a 256 *.zip *.tar.gz >checksums.txt)

echo
echo "==> dist/"
ls -l "$DIST"
echo
codesign -d --verbose=2 "$APP" 2>&1 | grep -E "^(Identifier|Authority|Signature|TeamIdentifier|CodeDirectory)" || true
lipo -archs "$APP/Contents/MacOS/zapmenu"
