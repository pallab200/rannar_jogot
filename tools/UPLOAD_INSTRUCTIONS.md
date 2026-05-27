Upload to Google Play - Instructions

1) Create a service account in the Play Console
   - Open Google Play Console -> Settings -> Developer account -> API access.
   - Create a service account and grant it the "Release Manager" or similar role.
   - Download the JSON key and place it at `android/play-service-account.json` (keep it secret).

2) Install dependencies

   pip install -r tools/requirements.txt

3) Run the upload script

   python tools/upload_to_play.py \
     --service-account android/play-service-account.json \
     --package com.rannarjogot.rannar_jogot \
     --aab build/app/outputs/bundle/release/app-release.aab \
     --track internal \
     --release-name "v1.0" \
     --release-notes-file release_notes.txt

4) Notes
   - `internal` track publishes quickly for testing; use `production` when ready.
   - The script uses the Google Play Developer API and commits an edit that uploads the bundle and assigns it to the chosen track.
   - Do NOT commit your service-account JSON to source control.

