#!/usr/bin/env python3
"""
Fast batch delete using Dropbox files_delete_batch API
Handles up to 1000 files per request with async job polling
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

def batch_delete_fast(dbx, paths, batch_size=1000):
    """Delete files using bulk batch API (up to 1000 per request)"""
    total = len(paths)
    deleted = 0
    failed = 0

    num_batches = (total + batch_size - 1) // batch_size

    for i in range(0, total, batch_size):
        batch = paths[i:i+batch_size]
        batch_num = i//batch_size + 1

        print(f"\nBatch {batch_num}/{num_batches} ({len(batch)} files)")

        try:
            # Create delete batch entries
            entries = [dropbox.files.DeleteArg(path=path) for path in batch]

            # Submit batch delete job
            result = dbx.files_delete_batch(entries)

            # Handle immediate completion or async job
            if isinstance(result, dropbox.files.DeleteBatchLaunch):
                if result.is_complete():
                    batch_result = result.get_complete()
                    deleted += process_batch_result(batch_result, batch)
                elif result.is_async_job_id():
                    async_job_id = result.get_async_job_id()
                    print(f"  Async job {async_job_id} started, polling...")

                    # Poll for completion
                    while True:
                        time.sleep(1)
                        check = dbx.files_delete_batch_check(async_job_id)

                        if check.is_complete():
                            batch_result = check.get_complete()
                            deleted += process_batch_result(batch_result, batch)
                            break
                        elif check.is_failed():
                            print(f"  ✗ Batch failed: {check.get_failed()}")
                            failed += len(batch)
                            break
                        # else: still in_progress, keep polling

            print(f"  Progress: {deleted}/{total} deleted")

            # Rate limiting: wait between batches to avoid too_many_write_operations
            if batch_num < num_batches:
                time.sleep(2)

        except ApiError as e:
            print(f"  ✗ Batch API error: {e}")
            failed += len(batch)
            # Wait longer after an error
            time.sleep(5)

    print(f"\n{'='*70}")
    print(f"COMPLETE: {deleted} deleted, {failed} failed")
    return deleted, failed

def process_batch_result(batch_result, paths):
    """Process the result of a batch delete operation"""
    deleted = 0
    for idx, entry in enumerate(batch_result.entries):
        if entry.is_success():
            deleted += 1
        elif entry.is_failure():
            error = entry.get_failure()
            if 'not_found' in str(error).lower():
                print(f"  ⚠ Already deleted: {paths[idx]}")
                deleted += 1
            else:
                print(f"  ✗ Error deleting {paths[idx]}: {error}")
    return deleted

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 batch-delete-fast.py <file-list.txt>")
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

    # Delete using fast batch API
    batch_delete_fast(dbx, paths)
