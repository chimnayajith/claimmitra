# ClaimMitra

ClaimMitra is a Flutter desktop application for insurance-claim case management.

## Run on NixOS/Linux

```bash
nix-shell
flutter pub get
flutter run -d linux
```

## Build and distribute on Windows

The GitHub Actions workflow `.github/workflows/windows-release.yml` builds the Windows release and packages both:

- `ClaimMitra-Setup-1.0.3.exe`: a Windows installer with ClaimMitra branding and Start Menu shortcut.
- `ClaimMitra-Portable-Windows-x64.zip`: portable app folder for testing.

Push the project to GitHub and run **Actions → Build ClaimMitra for Windows → Run workflow**. The workflow runs `flutter analyze`, `flutter test`, and `flutter build windows --release` before packaging. If analysis or tests fail, the artifact will not be produced.

The installed application is listed as **ClaimMitra** in the Start Menu. The portable build contains the executable and supporting files; do not distribute only the executable.

## Branding assets

- `assets/branding/claimmitra.png`: app logo used in the sidebar.
- `assets/branding/claimmitra_icon.png`: square app icon source.
- `assets/branding/claimmitra_logo.svg`: vector logo lockup.
- `installer/claimmitra.ico`: Windows installer and executable icon.

## Data safety

Back up the SQLite database before testing bulk deletion. Test the installer on a clean Windows account or PC before shipping it to a customer.
