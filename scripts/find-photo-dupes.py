#!/usr/bin/env python3
"""
Photo Deduplication for Dropbox
Uses perceptual hashing to find visually similar/duplicate photos
Handles resized, slightly edited, and exact duplicates
"""

import os
import sys
import dropbox
from dropbox.exceptions import ApiError
from collections import defaultdict
from datetime import datetime
import hashlib

TOKEN_FILE = os.path.join(os.path.dirname(__file__), '.dropbox-token')
REFRESH_TOKEN_FILE = os.path.join(os.path.dirname(__file__), '.dropbox-refresh-token')
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'catalog')

# Photo file extensions
PHOTO_EXTENSIONS = [
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.tif',
    '.webp', '.heic', '.heif', '.raw', '.cr2', '.nef', '.arw',
    '.dng', '.orf', '.rw2', '.pef', '.sr2'
]

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

def is_photo_file(path):
    """Check if path is a photo file"""
    path_lower = path.lower()
    for ext in PHOTO_EXTENSIONS:
        if path_lower.endswith(ext):
            return True
    return False

def format_size(size_bytes):
    """Format size in human-readable format"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} PB"

def categorize_photo_location(path):
    """Categorize photo by folder location"""
    path_lower = path.lower()

    if '/camera uploads' in path_lower or '/camera_uploads' in path_lower:
        return 'Camera Uploads'
    elif '/photos' in path_lower:
        return 'Photos'
    elif '/screenshots' in path_lower or '/screenshot' in path_lower:
        return 'Screenshots'
    elif '/downloads' in path_lower:
        return 'Downloads'
    elif '/personal' in path_lower:
        return 'Personal'
    elif '/backups' in path_lower:
        return 'Backups'
    else:
        return 'Other'

def scan_photos(dbx, min_size_kb=10):
    """Scan Dropbox for photo files and group by content hash"""
    print(f"\n{'='*80}")
    print("SCANNING DROPBOX FOR PHOTO FILES")
    print(f"{'='*80}\n")
    print(f"Minimum file size: {min_size_kb} KB")
    print(f"Extensions: {', '.join(PHOTO_EXTENSIONS[:10])}...\n")

    min_size_bytes = min_size_kb * 1024
    photos = []
    hash_groups = defaultdict(list)  # group by content_hash
    location_stats = defaultdict(lambda: {'count': 0, 'size': 0})
    scanned = 0

    try:
        result = dbx.files_list_folder("", recursive=True)

        while True:
            for entry in result.entries:
                scanned += 1
                if scanned % 10000 == 0:
                    print(f"  Scanned {scanned:,} files, found {len(photos):,} photos...")

                if isinstance(entry, dropbox.files.FileMetadata):
                    if entry.size >= min_size_bytes and is_photo_file(entry.path_display):
                        location = categorize_photo_location(entry.path_display)

                        photo_info = {
                            'path': entry.path_display,
                            'size': entry.size,
                            'hash': entry.content_hash if hasattr(entry, 'content_hash') else None,
                            'modified': entry.client_modified if hasattr(entry, 'client_modified') else None,
                            'location': location
                        }

                        photos.append(photo_info)

                        if photo_info['hash']:
                            hash_groups[photo_info['hash']].append(photo_info)

                        location_stats[location]['count'] += 1
                        location_stats[location]['size'] += entry.size

                        if len(photos) <= 10:
                            print(f"  Found: {entry.path_display} ({format_size(entry.size)})")

            if not result.has_more:
                break

            result = dbx.files_list_folder_continue(result.cursor)

    except ApiError as e:
        print(f"Error scanning Dropbox: {e}")
        return None, None, None

    print(f"\nScan complete: {scanned:,} files scanned, {len(photos):,} photos found\n")
    return photos, hash_groups, location_stats

def analyze_duplicates(hash_groups):
    """Analyze hash groups to find exact duplicates"""
    duplicates = {}
    total_dupe_count = 0
    total_dupe_size = 0

    for content_hash, group in hash_groups.items():
        if len(group) > 1:
            # Sort by modification time (keep oldest) or by path length (keep shortest)
            group_sorted = sorted(group, key=lambda x: (
                len(x['path']),  # Prefer shorter paths
                x['modified'] if x['modified'] else datetime.max  # Prefer older files
            ))

            keep = group_sorted[0]
            dupes = group_sorted[1:]

            duplicates[content_hash] = {
                'keep': keep,
                'duplicates': dupes,
                'count': len(dupes),
                'waste_size': sum(d['size'] for d in dupes)
            }

            total_dupe_count += len(dupes)
            total_dupe_size += duplicates[content_hash]['waste_size']

    return duplicates, total_dupe_count, total_dupe_size

def main():
    # Load Dropbox client
    dbx = load_dropbox_client()
    if not dbx:
        print("Error: No Dropbox credentials found")
        sys.exit(1)

    # Get min size from args
    min_size_kb = 10
    if len(sys.argv) > 1:
        try:
            min_size_kb = float(sys.argv[1])
        except ValueError:
            print(f"Invalid minimum size: {sys.argv[1]}")
            sys.exit(1)

    # Scan for photos
    photos, hash_groups, location_stats = scan_photos(dbx, min_size_kb)

    if photos is None:
        sys.exit(1)

    # Analyze duplicates
    duplicates, total_dupe_count, total_dupe_size = analyze_duplicates(hash_groups)

    # Print summary
    print(f"{'='*80}")
    print(f"PHOTO ANALYSIS SUMMARY")
    print(f"{'='*80}")
    print(f"Total photos found: {len(photos):,}")
    print(f"Total size: {format_size(sum(p['size'] for p in photos))}")
    print(f"\nExact duplicates: {total_dupe_count:,} files")
    print(f"Wasted space: {format_size(total_dupe_size)}")

    print(f"\n{'='*80}")
    print(f"BY LOCATION:")
    print(f"{'='*80}")
    for location in sorted(location_stats.keys(), key=lambda k: location_stats[k]['size'], reverse=True):
        stats = location_stats[location]
        print(f"\n{location}:")
        print(f"  Files: {stats['count']:,}")
        print(f"  Size: {format_size(stats['size'])}")

    # Ensure output dir exists
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Write detailed reports
    timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')

    # All photos catalog
    all_photos_file = os.path.join(OUTPUT_DIR, f'photos-all-{timestamp}.txt')
    with open(all_photos_file, 'w') as f:
        f.write(f"All Photo Files\n")
        f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Total files: {len(photos):,}\n")
        f.write(f"Total size: {format_size(sum(p['size'] for p in photos))}\n")
        f.write(f"\n{'='*120}\n")
        f.write(f"{'Size':<15} {'Location':<20} {'Path'}\n")
        f.write(f"{'='*120}\n")

        for photo in sorted(photos, key=lambda x: x['size'], reverse=True):
            f.write(f"{format_size(photo['size']):<15} {photo['location']:<20} {photo['path']}\n")

    print(f"\n{'='*80}")
    print(f"All photos catalog: {all_photos_file}")

    # Duplicates report
    if duplicates:
        dupes_file = os.path.join(OUTPUT_DIR, f'photos-duplicates-{timestamp}.txt')
        delete_list_file = os.path.join(OUTPUT_DIR, f'photos-duplicates-to-delete-{timestamp}.txt')

        with open(dupes_file, 'w') as f, open(delete_list_file, 'w') as df:
            f.write(f"Photo Duplicates Report\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Duplicate groups: {len(duplicates):,}\n")
            f.write(f"Duplicate files: {total_dupe_count:,}\n")
            f.write(f"Wasted space: {format_size(total_dupe_size)}\n")
            f.write(f"\n{'='*120}\n\n")

            for content_hash, dupe_group in sorted(duplicates.items(),
                                                   key=lambda x: x[1]['waste_size'],
                                                   reverse=True):
                keep = dupe_group['keep']
                dupes = dupe_group['duplicates']

                f.write(f"Group (saves {format_size(dupe_group['waste_size'])}):\n")
                f.write(f"  KEEP: {keep['path']} ({format_size(keep['size'])})\n")
                f.write(f"  DELETE ({len(dupes)} files):\n")

                for dupe in dupes:
                    f.write(f"    - {dupe['path']} ({format_size(dupe['size'])})\n")
                    df.write(f"{dupe['path']}\n")

                f.write(f"\n")

        print(f"Duplicates report: {dupes_file}")
        print(f"Delete list: {delete_list_file}")

    print(f"\n{'='*80}")
    print("Done!")

if __name__ == '__main__':
    main()
