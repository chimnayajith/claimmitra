#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_URL:?Set SUPABASE_URL to your Supabase project URL}"
: "${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY to your Supabase anon/publishable key}"
: "${LICENSE_ADMIN_SECRET:?Set LICENSE_ADMIN_SECRET to the admin secret configured for the create-license Edge Function}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 'Customer name' [customer@email.com]" >&2
  exit 2
fi

customer_name="$1"
customer_email="${2:-}"
payload=$(CUSTOMER_NAME="$customer_name" CUSTOMER_EMAIL="$customer_email" python3 - <<'PY'
import json, os
print(json.dumps({"customer_name": os.environ["CUSTOMER_NAME"], "customer_email": os.environ["CUSTOMER_EMAIL"]}))
PY
)

curl --fail-with-body --silent --show-error \
  -X POST "${SUPABASE_URL%/}/functions/v1/create-license" \
  -H "Content-Type: application/json" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "x-admin-secret: $LICENSE_ADMIN_SECRET" \
  --data "$payload"
echo
