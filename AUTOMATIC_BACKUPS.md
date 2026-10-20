# ClaimMitra automatic backups

ClaimMitra creates an automatic SQLite backup when it starts if no backup exists or the newest backup is at least 24 hours old. It keeps the 10 newest successful backups.

Backups are stored in the application's support directory under `backups`. On Windows, this is normally under the current user's `%APPDATA%` application-support location provided by `path_provider`; the exact location can vary by platform/runtime. The active database remains `claimmitra.sqlite` in the support directory.

The backup implementation uses SQLite `VACUUM INTO` to create a consistent snapshot, then opens the snapshot and runs `PRAGMA integrity_check` before treating it as successful. Old backups are removed only after the new backup has passed verification.

This is a local recovery mechanism, not protection against loss of the whole computer or drive. A future UI should expose backup status and allow copying a backup to an external drive. Restore functionality is not included in this change.

## Test before client delivery

1. Run the app once and confirm a `backups` folder and one `claimmitra_YYYYMMDD_HHMMSS.sqlite` file are created in the app support directory.
2. Close and reopen the app within 24 hours; confirm no extra backup is created.
3. For testing only, move the newest backup outside the folder and reopen the app to confirm a new backup is created.
4. Use a SQLite tool or script to run `PRAGMA integrity_check` on a copied backup and confirm it returns `ok`.
5. Test on the actual Windows build. Do not use real client records during testing.
