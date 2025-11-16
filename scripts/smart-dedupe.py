#!/usr/bin/env python3
"""
Smart deduplication: Delete duplicate files, keeping one copy of each unique file
"""

import json
import sys
from pathlib import Path

def smart_dedupe(catalog_path, target_folders, keep_preference=None):
    """
    Find duplicates and decide which copies to delete

    Args:
        catalog_path: Path to catalog JSON
        target_folders: List of folder paths to deduplicate
        keep_preference: Function that takes a list of paths and returns the one to KEEP
    """
    with open(catalog_path, 'r') as f:
        data = json.load(f)

    duplicates = data['analysis']['duplicates']
    path_to_file = {f['path']: f for f in data['analysis']['all_files']}

    to_delete = []

    for hash_val, paths in duplicates.items():
        if len(paths) < 2:
            continue

        # Check if any path is in our target folders
        relevant_paths = [p for p in paths if any(p.startswith(tf) for tf in target_folders)]
        if not relevant_paths:
            continue

        # Decide which to keep
        if keep_preference:
            keep_path = keep_preference(paths)
        else:
            # Default: keep the first path alphabetically
            keep_path = sorted(paths)[0]

        # Delete all others
        for path in paths:
            if path != keep_path and any(path.startswith(tf) for tf in target_folders):
                to_delete.append(path)

    return to_delete

def camera_uploads_preference(paths):
    """
    For Camera Uploads duplicates: Keep the organized version (NOT in Camera Uploads)
    Only keep Camera Uploads version if it's the only copy
    """
    non_camera = [p for p in paths if not p.startswith('/Camera Uploads/')]
    if non_camera:
        # Keep the first non-camera-uploads version
        return sorted(non_camera)[0]
    else:
        # All are in Camera Uploads, keep first
        return sorted(paths)[0]

def recipes_preference(paths):
    """
    For recipe duplicates: Prefer /personal/recipes/ organized folders over Camera Uploads
    Within recipes, prefer gallery over generated
    """
    recipe_paths = [p for p in paths if p.startswith('/personal/recipes/')]
    if not recipe_paths:
        # No recipe paths, keep first
        return sorted(paths)[0]

    # Prefer gallery over generated
    gallery_paths = [p for p in recipe_paths if '/gallery/' in p]
    if gallery_paths:
        return sorted(gallery_paths)[0]

    # Otherwise keep first recipe path
    return sorted(recipe_paths)[0]

def dashcord_preference(paths):
    """
    For dashcord duplicates: Keep first alphabetically
    """
    dashcord_paths = [p for p in paths if p.startswith('/dashcord/')]
    if not dashcord_paths:
        return sorted(paths)[0]
    return sorted(dashcord_paths)[0]


if __name__ == '__main__':
    catalog_path = 'scripts/catalog/dropbox-catalog-20251115-073416.json'

    if len(sys.argv) < 2:
        print("Usage: python3 smart-dedupe.py <target>")
        print("Targets: camera-uploads, recipes, dashcord")
        sys.exit(1)

    target = sys.argv[1]

    if target == 'camera-uploads':
        to_delete = smart_dedupe(
            catalog_path,
            ['/Camera Uploads/'],
            keep_preference=camera_uploads_preference
        )
        print(f"Camera Uploads deduplication plan:")
        print(f"Will delete {len(to_delete)} duplicate files from /Camera Uploads/")
        print(f"(Only files that exist elsewhere will be deleted)\n")

    elif target == 'recipes':
        to_delete = smart_dedupe(
            catalog_path,
            ['/personal/recipes/'],
            keep_preference=recipes_preference
        )
        print(f"Recipes deduplication plan:")
        print(f"Will delete {len(to_delete)} duplicate files from /personal/recipes/")
        print(f"(Keeping gallery versions, deleting generated duplicates)\n")

    elif target == 'dashcord':
        to_delete = smart_dedupe(
            catalog_path,
            ['/dashcord/', '/dashcord-dev/'],
            keep_preference=dashcord_preference
        )
        print(f"Dashcord deduplication plan:")
        print(f"Will delete {len(to_delete)} duplicate files from /dashcord/\n")

    else:
        print(f"Unknown target: {target}")
        sys.exit(1)

    # Print files to delete
    for path in sorted(to_delete)[:50]:
        print(path)

    if len(to_delete) > 50:
        print(f"\n... and {len(to_delete) - 50} more")

    # Output delete list
    output_file = f'scripts/catalog/dedupe-{target}.txt'
    with open(output_file, 'w') as f:
        for path in sorted(to_delete):
            f.write(path + '\n')

    print(f"\nFull list saved to: {output_file}")
