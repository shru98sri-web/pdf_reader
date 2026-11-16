# Project instructions

## Project overview
- This repository is a Flutter app named ReadSpace: an interactive PDF reader for Android and web.
- The UI is a blue/pink Material 3 reading experience with a library screen and a reader screen.
- The app currently centers on `lib/main.dart`; keep the project simple unless a feature clearly warrants a new file or module.

## Architecture and coding conventions
- Use Dart and Flutter idioms consistent with the existing app: `StatefulWidget` for screen state, `ThemeData`, Material widgets, and `SharedPreferences` for persistence.
- Keep the existing visual identity: blue/pink gradients, navy text, and the current `ReaderHome` structure. Preserve the app name and branding unless the task explicitly changes it.
- Prefer small, local changes that match the current style rather than introducing a new framework, state management package, or deep abstraction.
- Treat the app as a single-screen experience with a library/reader toggle. Avoid a large restructuring unless the feature is clearly multi-module.

## PDF handling rules
- Local PDFs use `FilePicker` + `SfPdfViewer.memory`, while remote PDFs use `SfPdfViewer.network`.
- Keep `_pdfBytes` and `_documentUrl` mutually exclusive and keep `_documentId`, `_documentName`, `_currentPage`, `_pageCount`, and `_searchResult` synchronized when a document opens or changes.
- When adding PDF-related state, update both the UI and persistence together. Bookmarks and per-document page progress live in `SharedPreferences` via `_persistState()` and `_loadSavedState()`.
- Preserve `onPageChanged`, `onDocumentLoaded`, and search-navigation behavior when touching the viewer.
- If you add a new document source, follow the existing pattern: open from bytes, open from URL, or open from bundled assets, and keep the document key stable for saved state.

## Persistence and UX expectations
- Bookmarks are stored by page number, and last-read page is tracked per document id.
- Keep the library screen and empty/no-document states working correctly when opening or switching documents.
- Maintain the light/dark reader toggle and zoom controls without breaking the layout.
- Keep search UX consistent: `TextField` submission triggers `_search()`, and result count text should update as the user navigates matches.

## Validation
- Validate Flutter changes with the smallest relevant command: prefer `flutter analyze` for static validation and `flutter test` for targeted tests when behavior is changed.
- If adding new behavior, add focused tests under `test/` rather than relying on manual checks only.
- For local web validation, use `flutter run -d chrome` as the project’s primary runner.

## Production and licensing notes
- The project uses `syncfusion_flutter_pdfviewer`, which may require a commercial or eligible free community license depending on distribution and usage.
- If a change affects packaging or shipping, confirm licensing requirements before release.
- Remote sample PDFs and browser access depend on the source provider’s availability and CORS rules.
