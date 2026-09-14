#!/bin/bash
set -euo pipefail

KEYCHAIN_NAME="roost-dev.keychain"
KEYCHAIN_PATH="$HOME/Library/Keychains/${KEYCHAIN_NAME}-db"
KEYCHAIN_PASSWORD="roost"
IDENTITY_NAME="Roost Local Dev"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if security find-certificate -c "$IDENTITY_NAME" "$KEYCHAIN_PATH" >/dev/null 2>&1; then
  echo "Signing identity '$IDENTITY_NAME' already exists — nothing to do."
  exit 0
fi

echo "Creating a self-signed code-signing identity so Accessibility permission survives rebuilds..."

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME" 2>/dev/null || true
security set-keychain-settings "$KEYCHAIN_NAME"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"

cat > "$WORKDIR/cert.cnf" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = Roost Local Dev
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -keyout "$WORKDIR/key.pem" -out "$WORKDIR/cert.pem" \
  -days 3650 -nodes -config "$WORKDIR/cert.cnf" >/dev/null 2>&1

openssl pkcs12 -export -inkey "$WORKDIR/key.pem" -in "$WORKDIR/cert.pem" \
  -out "$WORKDIR/id.p12" -passout "pass:$KEYCHAIN_PASSWORD" -name "$IDENTITY_NAME" \
  -legacy -macalg sha1 -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES >/dev/null 2>&1

security import "$WORKDIR/id.p12" -k "$KEYCHAIN_NAME" -P "$KEYCHAIN_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME" >/dev/null 2>&1

EXISTING=$(security list-keychains -d user | sed -e 's/"//g' -e 's/^[[:space:]]*//')
security list-keychains -d user -s "$KEYCHAIN_NAME" $EXISTING >/dev/null 2>&1

echo "Done. Build with:  make dev"
echo "Grant Accessibility once, and every future 'make dev' keeps it."
