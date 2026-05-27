Android Release Signing

1) Create a release keystore (locally) using keytool:

   keytool -genkey -v -keystore android/app/release-keystore.jks -alias rj_key -keyalg RSA -keysize 2048 -validity 10000

2) Create `key.properties` inside `android/` at `d:\Cooking\android\key.properties` with these fields:

   storePassword=<your_store_password>
   keyPassword=<your_key_password>
   keyAlias=rj_key
   storeFile=app/release-keystore.jks

3) Keep both `key.properties` and the keystore file out of version control.

4) Build the release AAB:

   flutter clean
   flutter pub get
   flutter build appbundle --release

5) Expected output path:

   build/app/outputs/bundle/release/app-release.aab

Notes:
- The Gradle script now loads `key.properties` if present and configures the `release` signing config.
- If `android/key.properties` is missing or invalid, the release build now fails instead of silently using the debug signing key.
