# ClaimMitra

ClaimMitra is a Flutter desktop case-management application for tracking case milestones, statutory/office deadlines, deposits, fees and execution proceedings.

## Requirements

- Flutter SDK compatible with Dart 3.10+
- Linux desktop development dependencies (for Linux builds)
- Excel files in `.xlsx` format for import/export

## Run locally

This source archive does not include generated platform runner folders. On your Linux development machine, generate the Linux runner once from the project root, then run the app:

```bash
flutter create --platforms=linux .
flutter config --enable-linux-desktop
flutter pub get
flutter analyze
flutter test
flutter run -d linux
```

The first run creates a local SQLite database named `claimmitra.sqlite` in the operating system's application-support directory. Records persist between launches. The database is local to the current computer; this build does not synchronize between computers.

## Excel import format

Use **Cases → Export Excel** to create an `.xlsx` workbook with the supported column headings. You can also create a spreadsheet with these columns (header matching is case-insensitive):

- Case Number (optional)
- Case Received Date (required; `DD/MM/YYYY` or ISO date)
- Accident Date
- Client Name (required)
- Address
- Phone
- Police Station
- Responsible Company / Person
- Police Documents Date
- Case Filed Date
- Evidence Date
- Award Date
- Deposit Date
- Deposit Amount
- Fees Received Date
- Fees Amount
- EP Filed Date
- Deposit Against Execution Date
- Deposit Against Execution Amount

Import validates rows and displays a preview before committing. Rows missing a client name or valid case received date are skipped. Existing non-empty case numbers are skipped rather than overwritten. Cases without case numbers are allowed.

## Workflow notes

- Police documents: 3 months yellow, 4 months orange, 5 months red from case received date.
- Case filed: 4 months yellow, 5 months red from case received date.
- Deposit: 2 months + 15 days yellow, 3 months orange, 3 months + 15 days red from award date.
- EP filing is required if normal deposit has not occurred by 4 months after award.
- Fees are expected within 7 days of deposit.
- Evidence is one date field.
- A normal case is treated as closed after deposit and fees are recorded. The execution branch is treated as closed after deposit against execution is recorded.

Deadlines are calculated from saved dates; status labels are not stored as authoritative database fields.
