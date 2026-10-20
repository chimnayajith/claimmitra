#!/usr/bin/env bash
set -euo pipefail

command -v openssl >/dev/null || { echo 'OpenSSL is required.' >&2; exit 1; }
key_dir="${HOME}/.config/claimmitra-licensing"
mkdir -p "$key_dir"
chmod 700 "$key_dir"
if [[ -e "$key_dir/private.pem" ]]; then
  echo "Refusing to overwrite existing key: $key_dir/private.pem" >&2
  echo 'Back up the existing key first. Losing it means you cannot issue licences that verify against existing builds.' >&2
  exit 1
fi
umask 077
openssl genpkey -algorithm ED25519 -out "$key_dir/private.pem"
openssl pkcs8 -topk8 -nocrypt -in "$key_dir/private.pem" -outform DER | base64 -w0 > "$key_dir/private_pkcs8.b64"
echo >> "$key_dir/private_pkcs8.b64"
openssl pkey -in "$key_dir/private.pem" -pubout -outform DER | tail -c 32 | base64 -w0 > "$key_dir/public_raw.b64"
echo >> "$key_dir/public_raw.b64"
chmod 600 "$key_dir"/*
echo "Keys created in $key_dir"
echo 'PUBLIC KEY (safe to put in GitHub Actions secret LICENSE_PUBLIC_KEY_B64):'
cat "$key_dir/public_raw.b64"
echo
echo 'PRIVATE KEY (secret; upload ONLY to Supabase as LICENSE_PRIVATE_KEY_PKCS8_B64):'
cat "$key_dir/private_pkcs8.b64"
echo
echo 'Never commit either file or paste the private key into ClaimMitra or a public repository.'
