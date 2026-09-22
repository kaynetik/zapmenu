#!/usr/bin/env zsh
# Create a stable self-signed code-signing certificate for zapmenu.
#
# macOS ties the Input Monitoring / Accessibility grant to the binary's code
# signature. Zig's ad-hoc signature changes its cdhash on every build, so the
# grant breaks after each rebuild. Signing every build with one long-lived
# self-signed certificate gives the binary a stable identity, so you grant the
# permission once and it survives rebuilds.
#
# Run this ONCE. Never regenerate the cert, or every existing grant breaks.
#
# Usage:
#   ./scripts/create-signing-cert.sh
#   zig build -Doptimize=ReleaseFast -Dsign-identity="zapmenu Dev"

set -euo pipefail

IDENTITY="zapmenu Dev"
# Homebrew OpenSSL 3 is often first on PATH and writes PKCS#12 that
# security(1) rejects as "MAC verification failed (wrong password?)".
# Apple's LibreSSL matches the importer.
OPENSSL=/usr/bin/openssl
SECURITY=/usr/bin/security

if [[ "$(uname -s)" != Darwin ]]; then
    echo "This script is macOS-only." >&2
    exit 1
fi

if [[ ! -x $OPENSSL ]]; then
    echo "Missing $OPENSSL (required so PKCS#12 matches Apple's importer)." >&2
    exit 1
fi

identity_listed() {
    $SECURITY find-identity -p codesigning | grep -F -q "\"$IDENTITY\""
}

if identity_listed; then
    echo "Signing identity '$IDENTITY' already exists. Nothing to do."
    echo "Build with: zig build -Doptimize=ReleaseFast -Dsign-identity=\"$IDENTITY\""
    exit 0
fi

KEYCHAIN=$($SECURITY default-keychain -d user | sed 's/^[[:space:]]*"//;s/"$//')
if [[ -z $KEYCHAIN ]]; then
    echo "Could not determine the default user keychain." >&2
    exit 1
fi

echo "Creating self-signed code-signing certificate '$IDENTITY'..."
echo "Using $OPENSSL ($($OPENSSL version)) and keychain: $KEYCHAIN"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Empty PKCS#12 passwords are also rejected as a MAC failure. This
# passphrase only protects the temp .p12; it is discarded with TMP_DIR.
P12_PASS=$(/usr/bin/uuidgen | tr -d '-')

cat >"$TMP_DIR/cert.conf" <<EOF
[ req ]
distinguished_name = dn
prompt = no
x509_extensions = v3

[ dn ]
CN = $IDENTITY

[ v3 ]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
subjectKeyIdentifier = hash
EOF

$OPENSSL genrsa -out "$TMP_DIR/key.pem" 2048 2>/dev/null
$OPENSSL req -new -x509 -key "$TMP_DIR/key.pem" -out "$TMP_DIR/cert.pem" \
    -days 3650 -config "$TMP_DIR/cert.conf" -extensions v3
$OPENSSL pkcs12 -export \
    -inkey "$TMP_DIR/key.pem" -in "$TMP_DIR/cert.pem" \
    -name "$IDENTITY" -out "$TMP_DIR/cert.p12" \
    -passout "pass:${P12_PASS}"

$SECURITY import "$TMP_DIR/cert.p12" -k "$KEYCHAIN" \
    -P "$P12_PASS" -A -T /usr/bin/codesign -T /usr/bin/security

if ! identity_listed; then
    echo "Import finished, but '$IDENTITY' is not a codesigning identity." >&2
    echo "Check: $SECURITY find-identity -p codesigning" >&2
    exit 1
fi

# codesign accepts this self-signed identity even though it is not in
# the trust store (find-identity -v will not list it). Signing a copy of
# a system binary here forces any keychain "Always Allow" prompt now,
# instead of during zig build.
cp /bin/echo "$TMP_DIR/smoke"
if ! codesign --force --sign "$IDENTITY" --identifier com.kaynetik.zapmenu.smoke "$TMP_DIR/smoke"; then
    echo "codesign could not use identity '$IDENTITY'." >&2
    exit 1
fi
smoke_info=$(codesign -d --verbose=2 "$TMP_DIR/smoke" 2>&1) || true
if [[ $smoke_info != *"Authority=$IDENTITY"* ]]; then
    echo "Smoke signature was not issued by '$IDENTITY'." >&2
    echo "$smoke_info" >&2
    exit 1
fi

echo
echo "Done. Identity '$IDENTITY' is in $KEYCHAIN"
echo "A self-signed cert shows as CSSMERR_TP_NOT_TRUSTED; that is expected."
echo "Verify with:"
echo "  security find-identity -p codesigning"
echo
echo "Build the signed binary with:"
echo "  zig build -Doptimize=ReleaseFast -Dsign-identity=\"$IDENTITY\""
echo
echo "Then grant Device Control and Data Access ONCE; it will persist across rebuilds."
