#!/usr/bin/env python3
"""
tools/upload_to_play.py

Upload an Android App Bundle (AAB) to Google Play using a service-account JSON.
Requires:
  pip install -r tools/requirements.txt

Example:
  python tools/upload_to_play.py \
    --service-account android/play-service-account.json \
    --package com.rannarjogot.rannar_jogot \
    --aab build/app/outputs/bundle/release/app-release.aab \
    --track internal \
    --release-name "v1.0" \
    --release-notes-file release_notes.txt
"""
import argparse
import os
import sys

try:
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload
except Exception as e:
    print("Missing dependencies. Run: pip install -r tools/requirements.txt")
    raise

SCOPES = ['https://www.googleapis.com/auth/androidpublisher']


def upload_aab(service_account_file, package_name, aab_path, track='internal', release_name=None, release_notes=None, release_notes_file=None):
    if not os.path.exists(service_account_file):
        raise SystemExit(f"Service account file not found: {service_account_file}")
    if not os.path.exists(aab_path):
        raise SystemExit(f"AAB file not found: {aab_path}")

    creds = service_account.Credentials.from_service_account_file(service_account_file, scopes=SCOPES)
    service = build('androidpublisher', 'v3', credentials=creds, cache_discovery=False)

    edits = service.edits()
    edit = edits.insert(body={}, packageName=package_name).execute()
    edit_id = edit['id']
    print(f"Created edit: {edit_id}")

    print("Uploading AAB...")
    media = MediaFileUpload(aab_path, mimetype='application/octet-stream')
    upload_response = edits.bundles().upload(packageName=package_name, editId=edit_id, media_body=media).execute()
    version_code = upload_response.get('versionCode')
    print(f"Uploaded bundle, versionCode={version_code}")

    notes = []
    if release_notes_file:
        if os.path.exists(release_notes_file):
            with open(release_notes_file, 'r', encoding='utf-8') as f:
                text = f.read().strip()
                if text:
                    notes.append({'language': 'en-US', 'text': text})
        else:
            print(f"Warning: release notes file not found: {release_notes_file}")
    elif release_notes:
        notes.append({'language': 'en-US', 'text': release_notes})

    release_body = {
        'releases': [
            {
                'name': release_name or 'Automated release',
                'versionCodes': [str(version_code)],
                'status': 'completed',
                'releaseNotes': notes
            }
        ]
    }

    print(f"Updating track '{track}'...")
    edits.tracks().update(packageName=package_name, editId=edit_id, track=track, body=release_body).execute()

    print("Committing edit...")
    commit_response = edits.commit(packageName=package_name, editId=edit_id).execute()
    print("Commit response:", commit_response)
    print("Upload complete. Open the Play Console to review the release.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Upload AAB to Google Play via service account')
    parser.add_argument('--service-account', required=True, help='Path to service account JSON file')
    parser.add_argument('--package', required=True, help='Android package name (applicationId)')
    parser.add_argument('--aab', required=True, help='Path to the .aab file')
    parser.add_argument('--track', default='internal', choices=['internal','alpha','beta','production'], help='Release track')
    parser.add_argument('--release-name', help='Release name/title')
    parser.add_argument('--release-notes', help='Release notes text')
    parser.add_argument('--release-notes-file', help='Path to a file containing release notes')

    args = parser.parse_args()

    upload_aab(args.service_account, args.package, args.aab, track=args.track, release_name=args.release_name, release_notes=args.release_notes, release_notes_file=args.release_notes_file)
