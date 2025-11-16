#!/usr/bin/env python3
"""
Analyze Dropbox catalog JSON to find best duplicate cleanup opportunities

Reads the massive JSON catalog and identifies:
- Largest duplicate groups by wasted space
- Duplicate patterns by folder
- Duplicate patterns by file type
- Easy wins (entire folders that are duplicated)
"""

import json
import sys
from collections import defaultdict
from pathlib import Path

def analyze_duplicates(catalog_json_path):
    """Analyze duplicate patterns from catalog JSON"""

    print("Loading catalog JSON (729MB, may take a moment)...")
    with open(catalog_json_path, 'r') as f:
        data = json.load(f)

    analysis = data.get('analysis', {})
    duplicates = analysis.get('duplicates', {})
    all_files = analysis.get('all_files', [])

    print(f"Total duplicate groups: {len(duplicates):,}")
    print(f"Total files: {len(all_files):,}")
    print("\nAnalyzing duplicate patterns...\n")

    # Build path->file lookup for fast access
    path_to_file = {f['path']: f for f in all_files}

    # Analysis containers
    duplicate_groups_by_savings = []
    duplicates_by_folder = defaultdict(lambda: {'count': 0, 'savings_bytes': 0, 'groups': []})
    duplicates_by_extension = defaultdict(lambda: {'count': 0, 'savings_bytes': 0, 'groups': []})

    # Analyze each duplicate group
    for hash_val, paths in duplicates.items():
        if len(paths) < 2:
            continue

        # Get file info for this group
        files = [path_to_file[path] for path in paths if path in path_to_file]
        if not files:
            continue

        # Calculate savings (total size of duplicates minus one we keep)
        total_size = sum(f['size'] for f in files)
        savings = total_size - files[0]['size']
        num_duplicates = len(files) - 1

        # Get common info
        extension = files[0].get('extension', '(no extension)')

        # Store group info
        group_info = {
            'paths': paths,
            'num_copies': len(paths),
            'savings_bytes': savings,
            'savings_mb': round(savings / (1024**2), 2),
            'file_size_mb': round(files[0]['size'] / (1024**2), 2),
            'extension': extension,
            'example_path': paths[0]
        }

        duplicate_groups_by_savings.append(group_info)

        # Analyze by folder (top-level folder)
        for path in paths:
            folder = '/' + path.split('/')[1] if len(path.split('/')) > 1 else '/'
            duplicates_by_folder[folder]['count'] += 1
            duplicates_by_folder[folder]['savings_bytes'] += savings / len(paths)  # Distribute savings
            duplicates_by_folder[folder]['groups'].append(group_info)

        # Analyze by extension
        duplicates_by_extension[extension]['count'] += num_duplicates
        duplicates_by_extension[extension]['savings_bytes'] += savings
        duplicates_by_extension[extension]['groups'].append(group_info)

    # Sort by savings
    duplicate_groups_by_savings.sort(key=lambda x: x['savings_bytes'], reverse=True)

    # Generate reports
    print("="*70)
    print("TOP 50 DUPLICATE GROUPS BY SPACE WASTED")
    print("="*70)

    for i, group in enumerate(duplicate_groups_by_savings[:50], 1):
        print(f"\n[{i}] {group['num_copies']} copies × {group['file_size_mb']:.2f} MB = {group['savings_mb']:.2f} MB saved")
        print(f"    Extension: {group['extension']}")
        print(f"    Example: {group['example_path']}")
        if group['num_copies'] <= 5:
            for path in group['paths']:
                print(f"      - {path}")
        else:
            print(f"      (showing 3 of {group['num_copies']})")
            for path in group['paths'][:3]:
                print(f"      - {path}")
            print(f"      ... and {group['num_copies'] - 3} more")

    print("\n" + "="*70)
    print("DUPLICATE GROUPS WITH 10+ COPIES")
    print("="*70)

    large_groups = [g for g in duplicate_groups_by_savings if g['num_copies'] >= 10]
    for i, group in enumerate(large_groups[:20], 1):
        print(f"\n[{i}] {group['num_copies']} copies of {group['file_size_mb']:.2f} MB file = {group['savings_mb']:.2f} MB saved")
        print(f"    Extension: {group['extension']}")
        print(f"    Example: {group['example_path']}")

    print("\n" + "="*70)
    print("DUPLICATES BY TOP-LEVEL FOLDER")
    print("="*70)

    folder_list = sorted(
        duplicates_by_folder.items(),
        key=lambda x: x[1]['savings_bytes'],
        reverse=True
    )[:20]

    for folder, stats in folder_list:
        savings_gb = stats['savings_bytes'] / (1024**3)
        print(f"{folder:40s} {stats['count']:>8,} dupes  {savings_gb:>8.2f} GB wasted")

    print("\n" + "="*70)
    print("DUPLICATES BY FILE TYPE")
    print("="*70)

    ext_list = sorted(
        duplicates_by_extension.items(),
        key=lambda x: x[1]['savings_bytes'],
        reverse=True
    )[:20]

    for ext, stats in ext_list:
        savings_gb = stats['savings_bytes'] / (1024**3)
        print(f"{ext:30s} {stats['count']:>8,} dupes  {savings_gb:>8.2f} GB wasted")

    # Save detailed CSV for further analysis
    csv_output = "scripts/catalog/duplicate-analysis.csv"
    with open(csv_output, 'w') as f:
        f.write("Rank,NumCopies,SavingsMB,FileSizeMB,Extension,ExamplePath\n")
        for i, group in enumerate(duplicate_groups_by_savings, 1):
            f.write(f"{i},{group['num_copies']},{group['savings_mb']:.2f},{group['file_size_mb']:.2f},{group['extension']},\"{group['example_path']}\"\n")

    print(f"\n\nDetailed CSV saved to: {csv_output}")

    return duplicate_groups_by_savings, duplicates_by_folder, duplicates_by_extension


if __name__ == '__main__':
    catalog_path = 'scripts/catalog/dropbox-catalog-20251115-073416.json'

    if not Path(catalog_path).exists():
        print(f"Error: Catalog file not found: {catalog_path}")
        sys.exit(1)

    analyze_duplicates(catalog_path)
