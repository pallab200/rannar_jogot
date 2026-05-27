#!/usr/bin/env bash
# Upload AAB to Google Play using Google Play Developer API and gcloud/service account
# Requires: `gcloud` + `python` + `google-api-python-client` or `playwright`? (we'll use fastlane supply alternative)

AAB_PATH="$PWD/build/app/outputs/bundle/release/app-release.aab"
SERVICE_ACCOUNT_JSON="$PWD/android/play-service-account.json"
PACKAGE_NAME="com.rannarjogot.rannar_jogot"
RELEASE_TRACK="internal" # change to alpha/beta/production as needed

if [ ! -f "$AAB_PATH" ]; then
  echo "AAB not found at $AAB_PATH"
  exit 1
fi

if [ ! -f "$SERVICE_ACCOUNT_JSON" ]; then
  echo "Service account JSON not found at $SERVICE_ACCOUNT_JSON"
  echo "Place your Google Play service account JSON at android/play-service-account.json"
  exit 2
fi

python3 - <<PY
from google.oauth2 import service_account
from googleapiclient.discovery import build
import sys

SERVICE_ACCOUNT = r"$SERVICE_ACCOUNT_JSON"
PACKAGE_NAME = "$PACKAGE_NAME"
AAB_PATH = r"$AAB_PATH"
TRACK = "$RELEASE_TRACK"

SCOPES = ['https://www.googleapis.com/auth/androidpublisher']
creds = service_account.Credentials.from_service_account_file(SERVICE_ACCOUNT, scopes=SCOPES)
service = build('androidpublisher', 'v3', credentials=creds)

edits = service.edits()
edit = edits.insert(body={}, packageName=PACKAGE_NAME).execute()
edit_id = edit['id']
print('Created edit:', edit_id)

# Upload the AAB
print('Uploading AAB...')
with open(AAB_PATH, 'rb') as f:
    upload_response = edits.bundles().upload(packageName=PACKAGE_NAME, editId=edit_id, media_body=AAB_PATH).execute()
print('Upload response:', upload_response)

# Assign to track
track_response = edits.tracks().update(packageName=PACKAGE_NAME, editId=edit_id, track=TRACK, body={
    'releases': [
        {
            'name': 'Automated release',
            'versionCodes': [str(upload_response['versionCode'])],
            'status': 'completed'
        }
    ]
}).execute()
print('Track response:', track_response)

# Commit the edit
commit_response = edits.commit(packageName=PACKAGE_NAME, editId=edit_id).execute()
print('Commit response:', commit_response)
PY
