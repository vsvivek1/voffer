"""Replaces the Play Store listing graphics with the files in store/android.

Uses the service account in PLAY_SERVICE_ACCOUNT_JSON. Uploads the icon, the
feature graphic and every PNG in phoneScreenshots (sorted by name) to the
listing's default language, then commits the edit.
"""

import json
import os
import pathlib
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PACKAGE = "com.calecutech.voffer"
ROOT = pathlib.Path(__file__).parent / "android"


def main() -> None:
    info = json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"])
    creds = service_account.Credentials.from_service_account_info(
        info, scopes=["https://www.googleapis.com/auth/androidpublisher"]
    )
    edits = build("androidpublisher", "v3", credentials=creds).edits()

    edit_id = edits.insert(packageName=PACKAGE, body={}).execute()["id"]
    language = (
        os.environ.get("LISTING_LANGUAGE")
        or edits.details().get(packageName=PACKAGE, editId=edit_id).execute().get(
            "defaultLanguage"
        )
        or "en-US"
    )
    print(f"Updating the {language} listing of {PACKAGE}")

    images = {
        "icon": [ROOT / "icon.png"],
        "featureGraphic": [ROOT / "featureGraphic.png"],
        "phoneScreenshots": sorted((ROOT / "phoneScreenshots").glob("*.png")),
    }
    for image_type, files in images.items():
        edits.images().deleteall(
            packageName=PACKAGE,
            editId=edit_id,
            language=language,
            imageType=image_type,
        ).execute()
        for path in files:
            edits.images().upload(
                packageName=PACKAGE,
                editId=edit_id,
                language=language,
                imageType=image_type,
                media_body=MediaFileUpload(str(path), mimetype="image/png"),
            ).execute()
            print(f"  {image_type}: {path.name}")

    edits.commit(packageName=PACKAGE, editId=edit_id).execute()
    print("Committed.")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # Print the API's message, not just a stack trace.
        print(f"::error::{e}")
        sys.exit(1)
