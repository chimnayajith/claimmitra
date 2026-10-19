# Build ClaimMitra for Windows with GitHub Actions

1. Create a GitHub repository and upload/push the contents of this project ZIP to its root (not the ZIP file itself).
2. Ensure the default branch is named `main` or `master`.
3. Open the repository on GitHub, select **Actions**, and enable workflows if prompted.
4. Select **Build ClaimMitra for Windows**, click **Run workflow**, and run it on the default branch. A push to `main`/`master` also triggers the workflow.
5. Wait for the run to finish. Download the `ClaimMitra-Windows-x64` artifact from the completed run's **Artifacts** section.
6. Extract the artifact ZIP and run `claimmitra.exe`. Keep every file and folder extracted alongside the executable.

The workflow generates Windows desktop platform files on the Windows runner because this source archive did not include a `windows/` directory. It runs `flutter analyze`, `flutter test`, then builds and packages the release. If analysis or tests fail, no release artifact is published; fix the reported issue and push again.

Test the extracted app on a separate Windows machine/account before distributing it, especially SQLite persistence and import/export. The artifact is a portable folder ZIP, not a signed installer.
