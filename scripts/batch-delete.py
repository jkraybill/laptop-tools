#!/usr/bin/env python3
"""
Batch delete files from a list
"""

import os
import sys
import time
import dropbox
from dropbox.exceptions import ApiError

TOKEN_FILE = os.path.join(os.path.dirname(__file__), '.dropbox-token')
REFRESH_TOKEN_FILE = os.path.join(os.path.dirname(__file__), '.dropbox-refresh-token')

def load_dropbox_client():
    """Load Dropbox client with refresh token support"""
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

    token = os.environ.get('DROPBOX_TOKEN')
    if not token and os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE, 'r') as f:
            token = f.read().strip()

    if token:
        return dropbox.Dropbox(token)

    return None

def batch_delete(dbx, paths, batch_size=100):
    """Delete files in batches"""
    total = len(paths)
    deleted = 0
    failed = 0

    for i in range(0, total, batch_size):
        batch = paths[i:i+batch_size]

        print(f"\nBatch {i//batch_size + 1}/{(total-1)//batch_size + 1} ({len(batch)} files)")

        for path in batch:
            try:
                dbx.files_delete_v2(path)
                deleted += 1
                if deleted % 10 == 0:
                    print(f"  Progress: {deleted}/{total} deleted")
            except ApiError as e:
                if 'not_found' in str(e):
                    print(f"  ⚠ Already deleted: {path}")
                    deleted += 1
                else:
                    print(f"  ✗ Error: {path}: {e}")
                    failed += 1

            # Rate limiting
            time.sleep(0.05)

    print(f"\n{'='*70}")
    print(f"COMPLETE: {deleted} deleted, {failed} failed")
    return deleted, failed

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 batch-delete.py <file-list.txt>")
        sys.exit(1)

    list_file = sys.argv[1]

    # Load paths
    with open(list_file, 'r') as f:
        paths = [line.strip() for line in f if line.strip()]

    print(f"Loaded {len(paths)} paths from {list_file}")

    # Load Dropbox client
    dbx = load_dropbox_client()
    if not dbx:
        print("Error: No Dropbox credentials found")
        sys.exit(1)

    # Delete
    batch_delete(dbx, paths)
