# ReadSpace — Interactive PDF Reader

A Flutter PDF reader starter project with a blue/pink theme, local PDF upload, online sample PDFs, page navigation, text search, zoom, bookmarks, and persisted reading positions.

## Platforms
- Android
- Chrome / Flutter Web

## Requirements
- Flutter stable SDK
- Android Studio (for Android builds)
- Google Chrome (for web run)

## Run in VS Code (Windows PowerShell)

```powershell
cd path\to\bluepink_pdf_reader
flutter doctor
flutter clean
flutter pub get
flutter run -d chrome
```

For Android, connect a device or start an emulator:

```powershell
flutter devices
flutter run -d android
```

Build release outputs:

```powershell
flutter build web --release
flutter build apk --release
```

## How to use
1. Start the app.
2. Select **Upload a PDF** to choose a PDF from your computer/device.
3. Or open one of the sample PDFs from **Explore sample books**.
4. Use the top toolbar to navigate pages, search text, zoom, switch reading theme, and bookmark pages.
5. Bookmarks and page positions are stored locally using SharedPreferences.

## Sample PDF resources
- Biology 2e is an openly licensed OpenStax textbook. OpenStax asks users redistributing its PDF to retain its attribution. This app opens it from its host rather than bundling a redistributed copy.
- Flutter Succinctly is a Syncfusion-hosted learning book sample.

## PDF engine and licensing
The reader uses `syncfusion_flutter_pdfviewer`. Syncfusion states that the package requires either a commercial licence or an eligible free Community licence. Review the current terms before distributing a production app:
https://www.syncfusion.com/sales/communitylicense

## Web PDF.js integration
`web/index.html` includes the PDF.js module script required by the Syncfusion viewer web implementation. The web reader needs internet access to load PDF.js from cdnjs. Online PDFs may also depend on the source server allowing browser cross-origin requests (CORS).

## Important production notes
This project is a furnished application starter, not a certified production deployment. Before publishing:
- Confirm Syncfusion licensing for your organisation and distribution model.
- Test on your target Android versions and browsers.
- Add crash reporting, privacy policy, app signing, release testing, accessibility review, and automated tests.
- For persistent offline library storage, add a managed file-copy/database layer. Currently selected local PDF bytes live for the current app session; bookmarks and page positions persist.
- Large PDF files can use substantial memory. Test with your real document sizes.
- Sample remote PDF availability and CORS are controlled by the source host.

## Included local sample
`assets/sample_study_guide.pdf` is a small original study guide generated for testing the reader. Open it from the Offline Sample card on the home screen.