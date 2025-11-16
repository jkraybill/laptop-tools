#!/usr/bin/env python3
"""
Delete files/folders from Dropbox via API

Usage: python3 delete-from-dropbox.py <path>
"""

import os
import sys
import dropbox
from dropbox.exceptions import ApiError

TOKEN_FILE = os.path.join(os.path.dirname(__file__), '.dropbox-token')
REFRESH_TOKEN_FILE = os.path.join(os.path.dirname(__file__), '.dropbox-refresh-token')

def load_dropbox_client():
    """Load Dropbox client with refresh token support"""
    # Try refresh token first (best option - never expires)
    if os.path.exists(REFRESH_TOKEN_FILE):
        with open(REFRESH_TOKEN_FILE, 'r') as f:
            lines = f.read().strip().split('\n')
            if len(lines) == 3:
                app_key, app_secret, refresh_token = lines
                return dropbox.Dropbox(
                    app_key=app_key,
                    app_secret=app_secret,
                    oauth2_refresh_token=refresh_token
                )

    # Fall back to access token (expires in 4 hours)
    token = os.environ.get('DROPBOX_TOKEN')
    if not token and os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE, 'r') as f:
            token = f.read().strip()

    if token:
        return dropbox.Dropbox(token)

    return None

def delete_path(dbx, path):
    """Delete a file or folder from Dropbox"""
    try:
        print(f"Deleting: {path}")
        result = dbx.files_delete_v2(path)
        print(f"✓ Successfully deleted: {path}")
        return True
    except ApiError as e:
        print(f"✗ Error deleting {path}: {e}")
        return False

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 delete-from-dropbox.py <path> [--yes]")
        sys.exit(1)

    path = sys.argv[1]
    auto_confirm = '--yes' in sys.argv or '-y' in sys.argv

    # Load Dropbox client
    dbx = load_dropbox_client()
    if not dbx:
        print("Error: No Dropbox credentials found")
        print("Run: python3 dropbox-setup-oauth.py")
        sys.exit(1)

    # Confirm
    if not auto_confirm:
        print(f"\nABOUT TO DELETE: {path}")
        print("This action cannot be undone (unless you have Dropbox version history)")
        response = input("Continue? [y/N]: ").strip().lower()

        if response != 'y':
            print("Cancelled")
            sys.exit(0)
    else:
        print(f"Auto-confirmed deletion of: {path}")

    # Delete
    success = delete_path(dbx, path)
    sys.exit(0 if success else 1)
