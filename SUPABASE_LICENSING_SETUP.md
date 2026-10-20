# ClaimMitra: Supabase licensing + GitHub updates

This is the database-backed licensing design:

1. You create a licence from your own terminal using `scripts/create_license.sh`.
2. Supabase stores the licence record and only a hash of the raw key.
3. The customer enters the key in ClaimMitra.
4. The `activate` Edge Function checks Supabase and atomically binds the licence to the first computer.
5. The function returns a signed activation token. ClaimMitra stores it locally and verifies it offline on later launches. **This token is generated automatically by the server; you do not send a separate signed licence file to the customer.**
6. ClaimMitra checks GitHub Releases for updates and offers to open the new installer download.

## What the files are for

- `supabase/migrations/...sql`: creates the private `licenses` table.
- `supabase/functions/activate/index.ts`: checks a key, enforces one-computer activation, and returns the local offline token.
- `supabase/functions/create-license/index.ts`: admin-only endpoint to create a licence record and return the new key once.
- `scripts/create_license.sh`: calls that admin-only endpoint so you can issue keys from your own computer.
- `scripts/generate_licensing_keys.sh`: creates the Ed25519 signing key pair used to sign offline activation tokens. This is **not** a customer licence-file generator. Keep the private key secret.
- `lib/licensing/activation_screen.dart` and `license_service.dart`: customer activation and local token verification.
- `lib/licensing/update_service.dart` and `update_prompt.dart`: GitHub update checking and installer download prompt.

## 1. Supabase project

Create a Supabase project. In Project Settings, find the project URL and the publishable key. The publishable key is okay to include in a desktop client; never use a secret/service-role key in Flutter.

Install the Supabase CLI, then from this repository root run:

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```

## 2. Create the server-side signing secret

This key lets the Edge Function sign activation tokens so the app can verify them offline. It stays in Supabase and is never included in the Flutter app.

```bash
./scripts/generate_licensing_keys.sh
```

The script writes files to `~/.config/claimmitra-licensing/`. Keep `private.pem` and `private_pkcs8.b64` private and backed up. Then create an admin secret and save it in your password manager:

```bash
openssl rand -hex 32 > ~/.config/claimmitra-licensing/admin_secret.txt
chmod 600 ~/.config/claimmitra-licensing/admin_secret.txt
supabase secrets set \
  LICENSE_PRIVATE_KEY_PKCS8_B64="$(cat ~/.config/claimmitra-licensing/private_pkcs8.b64)" \
  LICENSE_ADMIN_SECRET="$(cat ~/.config/claimmitra-licensing/admin_secret.txt)"
```

Do not commit these files or paste them into chat.

## 3. Deploy the database and Edge Functions

```bash
supabase db push
supabase functions deploy activate --no-verify-jwt
supabase functions deploy create-license --no-verify-jwt
```

The functions use Supabase's server-side service-role key through the Edge Function environment. Do not expose that key to the client. The `licenses` table has RLS enabled and no public access policies.

## 4. Configure GitHub Actions

In GitHub repository **Settings → Secrets and variables → Actions**, add:

- `SUPABASE_URL`: your project URL
- `SUPABASE_ANON_KEY`: your full publishable key (or legacy anon key)
- `LICENSE_PUBLIC_KEY_B64`: contents of `~/.config/claimmitra-licensing/public_raw.b64`

Do not add `LICENSE_PRIVATE_KEY_PKCS8_B64`, `LICENSE_ADMIN_SECRET`, or `SUPABASE_SERVICE_ROLE_KEY` as Flutter build arguments.

The release workflow is triggered by version tags such as `v1.0.1`. It builds the Windows installer and publishes it to GitHub Releases. Check the workflow output and release assets before distributing.

## 5. Issue a customer licence

On your own computer, run:

```bash
export SUPABASE_URL='https://YOUR_PROJECT_REF.supabase.co'
export SUPABASE_ANON_KEY='YOUR_FULL_PUBLISHABLE_KEY'
export LICENSE_ADMIN_SECRET="$(cat ~/.config/claimmitra-licensing/admin_secret.txt)"
./scripts/create_license.sh 'Customer Name' 'customer@example.com'
```

Send the returned `license_key` privately to the customer. The database stores only the key hash, so the raw key cannot be retrieved later. Keep your own sales record.

## 6. Test before selling

1. Build and install on a Windows test computer.
2. Issue a test key and activate while online.
3. Restart offline; ClaimMitra should still open.
4. Try the same key on a second computer; activation should be rejected.
5. Install a later GitHub Release and confirm the cases, backups, and activation token remain intact.

For a legitimate computer replacement, confirm the customer's identity and then reset that licence's `machine_hash` and `activated_at` to `NULL` in the Supabase dashboard. The customer must be online to activate the replacement computer.

## Limitations

- The fingerprint hashes Windows `MachineGuid`. Windows reinstallation can change it, and it is not impossible to spoof.
- Offline activation cannot be revoked immediately while a customer remains offline.
- The update feature checks GitHub Releases and offers a download; it does not silently install updates.
- The code has not yet been validated with `flutter analyze`, a Windows build, or an end-to-end activation test. Test it before selling.
