#!/usr/bin/env python3
"""
Dropbox Account Catalog Generator

Scans entire Dropbox account via API (no local sync required) and generates:
- Complete file/folder inventory
- Size analysis (largest files/folders)
- Duplicate detection (by content hash)
- Age analysis (find old unused files)
- File type statistics
- Cleanup recommendations

Author: Gordo
Created: 2025-11-15
Purpose: Massive Dropbox cleanup and reorganization planning
"""

import os
import sys
import json
import dropbox
from dropbox.exceptions import AuthError, ApiError
from datetime import datetime, timedelta
from collections import defaultdict
from pathlib import Path

# Configuration
TOKEN_FILE = os.path.join(os.path.dirname(__file__), '.dropbox-token')
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'catalog')
CHECKPOINT_FILE = os.path.join(os.path.dirname(__file__), '.dropbox-checkpoint.json')
CHECKPOINT_INTERVAL = 10000  # Save checkpoint every N files


def load_token():
    """Load Dropbox API token from file or environment"""
    # Try environment variable first
    token = os.environ.get('DROPBOX_TOKEN')
    if token:
        return token

    # Try token file
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE, 'r') as f:
            return f.read().strip()

    return None


def save_token(token):
    """Save token to file for future use"""
    with open(TOKEN_FILE, 'w') as f:
        f.write(token)
    os.chmod(TOKEN_FILE, 0o600)  # Secure permissions
    print(f"✓ Token saved to {TOKEN_FILE}")


def save_checkpoint(cursor, all_files, all_folders):
    """Save progress checkpoint"""
    checkpoint = {
        'cursor': cursor,
        'timestamp': datetime.now().isoformat(),
        'files_count': len(all_files),
        'folders_count': len(all_folders),
        'files': all_files,
        'folders': all_folders
    }
    with open(CHECKPOINT_FILE, 'w') as f:
        json.dump(checkpoint, f)
    print(f"      [Checkpoint saved: {len(all_files):,} files]")


def load_checkpoint():
    """Load checkpoint if exists"""
    if os.path.exists(CHECKPOINT_FILE):
        try:
            with open(CHECKPOINT_FILE, 'r') as f:
                checkpoint = json.load(f)
            return checkpoint
        except Exception as e:
            print(f"      Warning: Could not load checkpoint: {e}")
            return None
    return None


def clear_checkpoint():
    """Remove checkpoint file after successful completion"""
    if os.path.exists(CHECKPOINT_FILE):
        os.remove(CHECKPOINT_FILE)
        print("      [Checkpoint cleared]")


def get_folder_stats(dbx, path="", resume_checkpoint=None):
    """Get all files and folders from Dropbox using recursive API call with checkpointing"""
    print(f"\n{'='*60}")
    print("DROPBOX CATALOG GENERATOR")
    print(f"{'='*60}\n")

    all_files = []
    all_folders = []
    result = None

    print("[1/5] Scanning Dropbox account...")
    print("      Using optimized recursive mode for 1M+ files...")
    print(f"      Saving checkpoints every {CHECKPOINT_INTERVAL:,} files...\n")

    try:
        # Resume from checkpoint or start fresh
        if resume_checkpoint:
            all_files = resume_checkpoint['files']
            all_folders = resume_checkpoint['folders']
            cursor = resume_checkpoint['cursor']
            print(f"      ↻ Resuming from checkpoint: {len(all_files):,} files already scanned")
            print(f"      Checkpoint from: {resume_checkpoint['timestamp']}\n")
            result = dbx.files_list_folder_continue(cursor)
        else:
            # Use recursive=True for MUCH faster scanning (single API call stream)
            result = dbx.files_list_folder(path, recursive=True)

        while True:
            for entry in result.entries:
                if isinstance(entry, dropbox.files.FileMetadata):
                    file_info = {
                        'path': entry.path_display,
                        'name': entry.name,
                        'size': entry.size,
                        'modified': entry.client_modified.isoformat() if entry.client_modified else None,
                        'hash': entry.content_hash if hasattr(entry, 'content_hash') else None,
                        'extension': os.path.splitext(entry.name)[1].lower()
                    }
                    all_files.append(file_info)

                    # Progress update and checkpoint save
                    if len(all_files) % CHECKPOINT_INTERVAL == 0:
                        print(f"      Scanned {len(all_files):,} files, {len(all_folders):,} folders...")
                        # Save checkpoint with current cursor
                        if result.cursor:
                            save_checkpoint(result.cursor, all_files, all_folders)

                elif isinstance(entry, dropbox.files.FolderMetadata):
                    all_folders.append({
                        'path': entry.path_display,
                        'name': entry.name
                    })

            if not result.has_more:
                break

            # Continue with next batch
            result = dbx.files_list_folder_continue(result.cursor)

    except (ApiError, Exception) as e:
        print(f"\n      ✗ Error during scan: {e}")
        print(f"      Progress saved at {len(all_files):,} files")
        if result and result.cursor:
            save_checkpoint(result.cursor, all_files, all_folders)
            print(f"\n      You can resume by running the script again!")
        return [], []

    print(f"\n      ✓ Scan complete!")
    print(f"      Total: {len(all_files):,} files, {len(all_folders):,} folders\n")

    # Clear checkpoint on successful completion
    clear_checkpoint()

    return all_files, all_folders


def analyze_files(files):
    """Analyze file collection for insights"""
    print("[2/5] Analyzing files...")

    analysis = {
        'total_files': len(files),
        'total_size_bytes': sum(f['size'] for f in files),
        'total_size_gb': round(sum(f['size'] for f in files) / (1024**3), 2),
        'by_extension': defaultdict(lambda: {'count': 0, 'size': 0}),
        'by_age': defaultdict(lambda: {'count': 0, 'size': 0}),
        'largest_files': [],
        'duplicates': defaultdict(list),
        'old_files': [],
        'by_folder': defaultdict(lambda: {'count': 0, 'size': 0})
    }

    now = datetime.now()

    for file in files:
        # By extension
        ext = file['extension'] or '(no extension)'
        analysis['by_extension'][ext]['count'] += 1
        analysis['by_extension'][ext]['size'] += file['size']

        # By folder (top-level)
        folder = '/' + file['path'].split('/')[1] if len(file['path'].split('/')) > 1 else '/'
        analysis['by_folder'][folder]['count'] += 1
        analysis['by_folder'][folder]['size'] += file['size']

        # By age
        if file['modified']:
            modified = datetime.fromisoformat(file['modified'].replace('Z', '+00:00'))
            age_days = (now - modified.replace(tzinfo=None)).days

            if age_days < 30:
                age_bucket = 'Last 30 days'
            elif age_days < 90:
                age_bucket = '30-90 days'
            elif age_days < 365:
                age_bucket = '3-12 months'
            elif age_days < 365 * 2:
                age_bucket = '1-2 years'
            elif age_days < 365 * 3:
                age_bucket = '2-3 years'
            else:
                age_bucket = '3+ years'
                # Mark as old file
                if file['size'] > 1024 * 1024:  # > 1MB
                    analysis['old_files'].append({
                        'path': file['path'],
                        'size_mb': round(file['size'] / (1024**2), 2),
                        'age_years': round(age_days / 365, 1)
                    })

            analysis['by_age'][age_bucket]['count'] += 1
            analysis['by_age'][age_bucket]['size'] += file['size']

        # Duplicates (by hash)
        if file['hash']:
            analysis['duplicates'][file['hash']].append(file['path'])

    # Find largest files
    analysis['largest_files'] = sorted(
        [{'path': f['path'], 'size_mb': round(f['size'] / (1024**2), 2)} for f in files],
        key=lambda x: x['size_mb'],
        reverse=True
    )[:100]  # Top 100

    # Filter duplicates (only keep where count > 1)
    analysis['duplicates'] = {
        k: v for k, v in analysis['duplicates'].items() if len(v) > 1
    }

    # Sort old files by size
    analysis['old_files'] = sorted(
        analysis['old_files'],
        key=lambda x: x['size_mb'],
        reverse=True
    )[:100]  # Top 100

    print(f"      ✓ Analysis complete\n")

    return analysis


def generate_recommendations(analysis):
    """Generate cleanup recommendations"""
    print("[3/5] Generating recommendations...")

    recommendations = []

    # Duplicate files
    if analysis['duplicates']:
        dup_count = len(analysis['duplicates'])
        dup_files = sum(len(paths) - 1 for paths in analysis['duplicates'].values())

        # Create O(1) lookup dict instead of O(n) linear scan - CRITICAL FIX!
        path_to_file = {f['path']: f for f in analysis.get('all_files', [])}

        dup_size = 0
        for hash_val, paths in analysis['duplicates'].items():
            # Get files by path lookup (O(1) per file instead of O(n))
            files = [path_to_file[path] for path in paths if path in path_to_file]
            if files:
                # Size saved = (total size of all copies) - (size of one copy we keep)
                dup_size += sum(f['size'] for f in files) - files[0]['size']

        recommendations.append({
            'category': 'Duplicates',
            'priority': 'HIGH',
            'potential_savings_gb': round(dup_size / (1024**3), 2) if dup_size else 0,
            'file_count': dup_files,
            'description': f'Found {dup_count} sets of duplicate files. Removing duplicates could save significant space.'
        })

    # Old large files
    if analysis['old_files']:
        old_size = sum(f['size_mb'] for f in analysis['old_files'])
        recommendations.append({
            'category': 'Old Files (3+ years)',
            'priority': 'MEDIUM',
            'potential_savings_gb': round(old_size / 1024, 2),
            'file_count': len(analysis['old_files']),
            'description': f'Found {len(analysis["old_files"])} large files over 3 years old. Review for archival/deletion.'
        })

    # Large file types
    largest_ext = sorted(
        analysis['by_extension'].items(),
        key=lambda x: x[1]['size'],
        reverse=True
    )[:5]

    for ext, stats in largest_ext:
        if stats['size'] > 1024**3:  # > 1GB
            recommendations.append({
                'category': f'File Type: {ext}',
                'priority': 'MEDIUM',
                'potential_savings_gb': round(stats['size'] / (1024**3), 2),
                'file_count': stats['count'],
                'description': f'{stats["count"]} {ext} files using {round(stats["size"] / (1024**3), 2)}GB'
            })

    print(f"      ✓ Generated {len(recommendations)} recommendations\n")

    return recommendations


def generate_reports(analysis, recommendations):
    """Generate JSON and text reports"""
    print("[4/5] Generating reports...")

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    json_file = os.path.join(OUTPUT_DIR, f'dropbox-catalog-{timestamp}.json')
    txt_file = os.path.join(OUTPUT_DIR, f'dropbox-catalog-{timestamp}.txt')

    # Prepare report data
    report = {
        'metadata': {
            'generated': datetime.now().isoformat(),
            'total_files': analysis['total_files'],
            'total_size_gb': analysis['total_size_gb']
        },
        'analysis': analysis,
        'recommendations': recommendations
    }

    # Save JSON
    with open(json_file, 'w') as f:
        json.dump(report, f, indent=2, default=str)

    # Generate text summary
    summary = f"""
{'='*70}
DROPBOX CATALOG REPORT
{'='*70}
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

{'='*70}
OVERVIEW
{'='*70}
Total Files: {analysis['total_files']:,}
Total Size:  {analysis['total_size_gb']:.2f} GB

{'='*70}
TOP FOLDERS BY SIZE
{'='*70}
"""

    # Top folders
    top_folders = sorted(
        analysis['by_folder'].items(),
        key=lambda x: x[1]['size'],
        reverse=True
    )[:20]

    for folder, stats in top_folders:
        summary += f"{folder:50s} {stats['count']:>8,} files  {stats['size']/(1024**3):>8.2f} GB\n"

    summary += f"""
{'='*70}
FILE TYPES BY SIZE
{'='*70}
"""

    # Top extensions
    top_ext = sorted(
        analysis['by_extension'].items(),
        key=lambda x: x[1]['size'],
        reverse=True
    )[:20]

    for ext, stats in top_ext:
        summary += f"{ext:30s} {stats['count']:>8,} files  {stats['size']/(1024**3):>8.2f} GB\n"

    summary += f"""
{'='*70}
FILES BY AGE
{'='*70}
"""

    age_order = ['Last 30 days', '30-90 days', '3-12 months', '1-2 years', '2-3 years', '3+ years']
    for age in age_order:
        if age in analysis['by_age']:
            stats = analysis['by_age'][age]
            summary += f"{age:30s} {stats['count']:>8,} files  {stats['size']/(1024**3):>8.2f} GB\n"

    summary += f"""
{'='*70}
CLEANUP RECOMMENDATIONS
{'='*70}
"""

    for i, rec in enumerate(recommendations, 1):
        summary += f"""
[{i}] {rec['category']} - Priority: {rec['priority']}
    Potential Savings: {rec['potential_savings_gb']:.2f} GB ({rec['file_count']:,} files)
    {rec['description']}
"""

    summary += f"""
{'='*70}
LARGEST FILES (Top 50)
{'='*70}
"""

    for file in analysis['largest_files'][:50]:
        summary += f"{file['size_mb']:>10.2f} MB  {file['path']}\n"

    if analysis['duplicates']:
        summary += f"""
{'='*70}
DUPLICATE FILES (Sample - Top 20 groups)
{'='*70}
"""
        for i, (hash_val, paths) in enumerate(list(analysis['duplicates'].items())[:20], 1):
            summary += f"\n[{i}] Duplicate group ({len(paths)} copies):\n"
            for path in paths:
                summary += f"    {path}\n"

    summary += f"""
{'='*70}
OLD FILES (3+ years, >1MB, Top 50)
{'='*70}
"""

    for file in analysis['old_files'][:50]:
        summary += f"{file['size_mb']:>10.2f} MB  ({file['age_years']:.1f} years old)  {file['path']}\n"

    summary += f"""
{'='*70}
END OF REPORT
{'='*70}

Next Steps:
1. Review recommendations above
2. Feed this report to Gordo for interactive cleanup
3. Make decisions on what to delete/reorganize
4. Run cleanup scripts (to be created based on your decisions)
"""

    with open(txt_file, 'w') as f:
        f.write(summary)

    print(f"      ✓ JSON report: {json_file}")
    print(f"      ✓ Text report: {txt_file}\n")

    return json_file, txt_file


def main():
    """Main execution"""
    print("\n" + "="*70)
    print("DROPBOX CATALOG GENERATOR")
    print("="*70 + "\n")

    # Load or prompt for token
    token = load_token()

    if not token:
        print("No Dropbox API token found.\n")
        print("To get a token:")
        print("1. Go to https://www.dropbox.com/developers/apps")
        print("2. Create a new app (or use existing)")
        print("3. Generate an access token")
        print("4. Paste it below (or set DROPBOX_TOKEN environment variable)\n")

        token = input("Enter Dropbox API token: ").strip()

        if not token:
            print("\n✗ No token provided. Exiting.")
            return 1

        save_token(token)

    # Check for existing checkpoint
    checkpoint = load_checkpoint()
    resume = False

    if checkpoint:
        print(f"Found checkpoint from {checkpoint['timestamp']}")
        print(f"Progress: {checkpoint['files_count']:,} files, {checkpoint['folders_count']:,} folders\n")
        response = input("Resume from checkpoint? [Y/n]: ").strip().lower()
        if response in ('', 'y', 'yes'):
            resume = True
            print("✓ Will resume from checkpoint\n")
        else:
            print("✓ Starting fresh scan\n")
            clear_checkpoint()
            checkpoint = None

    # Initialize Dropbox client
    print("[0/5] Connecting to Dropbox...")
    try:
        dbx = dropbox.Dropbox(token)
        account = dbx.users_get_current_account()
        print(f"      ✓ Connected as: {account.name.display_name}")
        print(f"      Email: {account.email}\n")
    except AuthError:
        print("\n✗ Invalid token. Please check and try again.")
        if os.path.exists(TOKEN_FILE):
            os.remove(TOKEN_FILE)
        return 1

    # Get all files (with optional resume)
    all_files, all_folders = get_folder_stats(dbx, resume_checkpoint=checkpoint if resume else None)

    # Check if scan failed
    if not all_files and not all_folders:
        print("\n✗ Scan failed or was interrupted. Checkpoint saved if possible.")
        print("   Run the script again to resume.\n")
        return 1

    # Analyze
    analysis = analyze_files(all_files)
    analysis['all_files'] = all_files  # Keep for duplicate size calculation

    # Generate recommendations
    recommendations = generate_recommendations(analysis)

    # Generate reports
    json_file, txt_file = generate_reports(analysis, recommendations)

    # Summary
    print("[5/5] Summary")
    print(f"      Files analyzed: {len(all_files):,}")
    print(f"      Total size: {analysis['total_size_gb']:.2f} GB")
    print(f"      Recommendations: {len(recommendations)}")
    print()
    print("="*70)
    print("CATALOG COMPLETE!")
    print("="*70)
    print()
    print("Next: Review the text report and bring it back to Gordo for")
    print("      interactive cleanup planning!")
    print()

    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n✗ Cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
