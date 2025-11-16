#!/usr/bin/env python3
"""Find all recipe book duplicates to delete"""

import json
from pathlib import Path

catalog_path = 'scripts/catalog/dropbox-catalog-20251115-073416.json'

with open(catalog_path, 'r') as f:
    data = json.load(f)

duplicates = data['analysis']['duplicates']
path_to_file = {f['path']: f for f in data['analysis']['all_files']}

# Find all EPUB duplicates that involve recipe books
recipe_dupes_to_delete = []

for hash_val, paths in duplicates.items():
    # Only look at EPUBs
    files = [path_to_file[p] for p in paths if p in path_to_file]
    if not files or files[0].get('extension') != '.epub':
        continue

    # Check if any path contains recipe book indicators
    recipe_indicators = ['recipe', 'cookbook', 'cook', 'bread', 'kitchen']
    is_recipe = any(any(indicator in p.lower() for indicator in recipe_indicators) for p in paths)

    if not is_recipe:
        continue

    # For each duplicate group, decide what to delete
    keep_path = None
    delete_paths = []

    for path in paths:
        # Prefer recipe-books-shared
        if 'recipe-books-shared' in path:
            keep_path = path
        # Delete calibre-library versions
        elif 'calibre-library' in path:
            delete_paths.append(path)
        # If standalone and we have a shared version, delete standalone
        elif keep_path is None:
            keep_path = path
        else:
            delete_paths.append(path)

    if delete_paths:
        recipe_dupes_to_delete.extend(delete_paths)

# Print results
print(f"Found {len(recipe_dupes_to_delete)} recipe book duplicates to delete:\n")
for path in sorted(set(recipe_dupes_to_delete)):
    print(path)
