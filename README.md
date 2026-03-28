# YouTube App

Production-oriented Flutter YouTube player with:
- standard video playback
- Shorts vertical feed
- playlist autoplay and queue
- Riverpod-based player state
- CI for format, analyze, test, and release artifacts

## Requirements

- Flutter stable
- Android SDK and NDK installed
- Xcode for iOS builds

## Configure API key

This app reads the API key from compile-time environment values.

Run locally with:

```bash
flutter run --dart-define=YOUTUBE_API_KEY=YOUR_KEY
```

Build release with:

```bash
flutter build apk --release --dart-define=YOUTUBE_API_KEY=YOUR_KEY
flutter build appbundle --release --dart-define=YOUTUBE_API_KEY=YOUR_KEY
```

Do not hardcode secrets in source files. Use CI secrets and pass them as dart-define values.

## Quality gates

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test --coverage
```

## Android release signing

1. Create keystore once and store securely.
2. Add android/key.properties locally.
3. Keep signing files out of version control.

The repository already ignores:
- android/key.properties
- *.jks

## CI pipeline

GitHub Actions workflow:
- format check
- static analysis with fatal warnings
- tests with coverage
- Android APK and AAB artifacts
- iOS release build without codesign
