#!/usr/bin/env python3
"""
Find all ML/AI model files in Dropbox
Searches for large model files and catalogs them by type
"""

import os
import sys
import dropbox
from dropbox.exceptions import ApiError
from collections import defaultdict
from datetime import datetime

TOKEN_FILE = os.path.join(os.path.dirname(__file__), '.dropbox-token')
REFRESH_TOKEN_FILE = os.path.join(os.path.dirname(__file__), '.dropbox-refresh-token')
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'catalog')

# Model file extensions to look for
MODEL_EXTENSIONS = [
    '.ckpt',       # Checkpoint files (Stable Diffusion, PyTorch)
    '.safetensors', # Safe tensors format
    '.pt',         # PyTorch
    '.pth',        # PyTorch
    '.bin',        # Binary models (BERT, etc.)
    '.h5',         # Keras/HDF5
    '.pb',         # TensorFlow
    '.onnx',       # ONNX format
    '.model',      # Generic model files
    '.weights',    # Weight files
    '.pkl',        # Pickle files (often models)
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

def is_model_file(path):
    """Check if path is a model file"""
    path_lower = path.lower()
    for ext in MODEL_EXTENSIONS:
        if path_lower.endswith(ext):
            return True
    return False

def categorize_model(path):
    """Categorize model by type/framework"""
    path_lower = path.lower()

    if 'stable-diffusion' in path_lower or 'sd-' in path_lower or '/sd/' in path_lower or 'stablediffusion' in path_lower:
        return 'Stable Diffusion'
    elif 'vae' in path_lower:
        return 'VAE'
    elif 'lora' in path_lower:
        return 'LoRA'
    elif 'controlnet' in path_lower:
        return 'ControlNet'
    elif 'embedding' in path_lower or 'textual_inversion' in path_lower:
        return 'Embeddings'
    elif 'bert' in path_lower or 'gpt' in path_lower or 'llama' in path_lower or 'mistral' in path_lower:
        return 'Language Models'
    elif 'yolo' in path_lower or 'detection' in path_lower:
        return 'Object Detection'
    elif 'resnet' in path_lower or 'vgg' in path_lower or 'inception' in path_lower:
        return 'Image Classification'
    elif 'gan' in path_lower:
        return 'GAN'
    else:
        return 'Other Models'

def format_size(size_bytes):
    """Format size in human-readable format"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} PB"

def scan_dropbox(dbx, min_size_mb=1):
    """Scan entire Dropbox for model files"""
    print(f"\n{'='*80}")
    print("SCANNING DROPBOX FOR ML/AI MODEL FILES")
    print(f"{'='*80}\n")
    print(f"Minimum file size: {min_size_mb} MB")
    print(f"Extensions: {', '.join(MODEL_EXTENSIONS)}\n")

    min_size_bytes = min_size_mb * 1024 * 1024
    models = []
    categories = defaultdict(lambda: {'files': [], 'total_size': 0})
    scanned = 0

    try:
        result = dbx.files_list_folder("", recursive=True)

        while True:
            for entry in result.entries:
                scanned += 1
                if scanned % 10000 == 0:
                    print(f"  Scanned {scanned:,} files, found {len(models):,} models...")

                if isinstance(entry, dropbox.files.FileMetadata):
                    if entry.size >= min_size_bytes and is_model_file(entry.path_display):
                        category = categorize_model(entry.path_display)
                        models.append((entry.size, entry.path_display, category))
                        categories[category]['files'].append((entry.size, entry.path_display))
                        categories[category]['total_size'] += entry.size

                        if len(models) <= 10:
                            print(f"  Found: {entry.path_display} ({format_size(entry.size)})")

            if not result.has_more:
                break

            result = dbx.files_list_folder_continue(result.cursor)

    except ApiError as e:
        print(f"Error scanning Dropbox: {e}")
        return None, None

    print(f"\nScan complete: {scanned:,} files scanned, {len(models):,} models found\n")
    return models, categories

def main():
    # Load Dropbox client
    dbx = load_dropbox_client()
    if not dbx:
        print("Error: No Dropbox credentials found")
        sys.exit(1)

    # Get min size from args
    min_size_mb = 1
    if len(sys.argv) > 1:
        try:
            min_size_mb = float(sys.argv[1])
        except ValueError:
            print(f"Invalid minimum size: {sys.argv[1]}")
            sys.exit(1)

    # Scan Dropbox
    models, categories = scan_dropbox(dbx, min_size_mb)

    if models is None:
        sys.exit(1)

    # Sort models by size (largest first)
    models.sort(reverse=True, key=lambda x: x[0])

    # Print summary
    print(f"{'='*80}")
    print(f"ML/AI MODEL FILES SUMMARY")
    print(f"{'='*80}")
    print(f"Total model files found: {len(models):,}")
    print(f"Total size: {format_size(sum(m[0] for m in models))}")
    print(f"\n{'='*80}")
    print(f"BY CATEGORY:")
    print(f"{'='*80}")

    for category in sorted(categories.keys(), key=lambda k: categories[k]['total_size'], reverse=True):
        cat_data = categories[category]
        print(f"\n{category}:")
        print(f"  Files: {len(cat_data['files']):,}")
        print(f"  Total size: {format_size(cat_data['total_size'])}")

    # Ensure output dir exists
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Write detailed catalog
    timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    output_file = os.path.join(OUTPUT_DIR, f'ml-models-{timestamp}.txt')

    with open(output_file, 'w') as f:
        f.write(f"ML/AI Model Files Catalog\n")
        f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Minimum size: {min_size_mb} MB\n")
        f.write(f"Total files: {len(models):,}\n")
        f.write(f"Total size: {format_size(sum(m[0] for m in models))}\n")
        f.write(f"\n{'='*120}\n")
        f.write(f"{'Size':<15} {'Category':<25} {'Path'}\n")
        f.write(f"{'='*120}\n")

        for size, path, category in models:
            f.write(f"{format_size(size):<15} {category:<25} {path}\n")

    print(f"\n{'='*80}")
    print(f"Detailed catalog written to: {output_file}")

    # Write category-specific files
    for category, cat_data in categories.items():
        category_slug = category.lower().replace(' ', '-').replace('/', '-')
        category_file = os.path.join(OUTPUT_DIR, f'ml-models-{category_slug}-{timestamp}.txt')

        with open(category_file, 'w') as f:
            f.write(f"{category} Model Files\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total files: {len(cat_data['files']):,}\n")
            f.write(f"Total size: {format_size(cat_data['total_size'])}\n")
            f.write(f"\n{'='*120}\n")
            f.write(f"{'Size':<15} {'Path'}\n")
            f.write(f"{'='*120}\n")

            for size, path in sorted(cat_data['files'], reverse=True, key=lambda x: x[0]):
                f.write(f"{format_size(size):<15} {path}\n")

        print(f"  - {category_file}")

    print(f"\n{'='*80}")
    print("Done!")

if __name__ == '__main__':
    main()
