#!/usr/bin/env python3
"""
Extract and catalog all ML/AI model files from Dropbox catalog
Focuses on large model files (.ckpt, .safetensors, .pt, .pth, .bin, etc.)
"""

import sys
import os
from collections import defaultdict

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
    '.pth.tar',    # PyTorch tarball
    '.ckpt.tar',   # Checkpoint tarball
]

def parse_catalog_line(line):
    """Parse a catalog line: size|path"""
    parts = line.strip().split('|', 1)
    if len(parts) != 2:
        return None, None
    try:
        size = int(parts[0])
        path = parts[1]
        return size, path
    except:
        return None, None

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

    if 'stable-diffusion' in path_lower or 'sd-' in path_lower or '/sd/' in path_lower:
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

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 catalog-ml-models.py <catalog-file.txt>")
        sys.exit(1)

    catalog_file = sys.argv[1]

    # Parse catalog and find all model files
    models = []
    categories = defaultdict(lambda: {'files': [], 'total_size': 0})

    print(f"Scanning {catalog_file} for ML/AI model files...")

    with open(catalog_file, 'r') as f:
        for line in f:
            size, path = parse_catalog_line(line)
            if size is None or path is None:
                continue

            if is_model_file(path):
                category = categorize_model(path)
                models.append((size, path, category))
                categories[category]['files'].append((size, path))
                categories[category]['total_size'] += size

    # Sort models by size (largest first)
    models.sort(reverse=True, key=lambda x: x[0])

    # Print summary
    print(f"\n{'='*80}")
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

    # Write detailed catalog
    output_file = catalog_file.replace('.txt', '-models.txt')

    with open(output_file, 'w') as f:
        f.write(f"ML/AI Model Files Catalog\n")
        f.write(f"Generated from: {catalog_file}\n")
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
        category_file = output_file.replace('-models.txt', f'-models-{category.lower().replace(" ", "-").replace("/", "-")}.txt')

        with open(category_file, 'w') as f:
            f.write(f"{category} Model Files\n")
            f.write(f"Total files: {len(cat_data['files']):,}\n")
            f.write(f"Total size: {format_size(cat_data['total_size'])}\n")
            f.write(f"\n{'='*120}\n")
            f.write(f"{'Size':<15} {'Path'}\n")
            f.write(f"{'='*120}\n")

            for size, path in sorted(cat_data['files'], reverse=True, key=lambda x: x[0]):
                f.write(f"{format_size(size):<15} {path}\n")

        print(f"  - {category_file}")

if __name__ == '__main__':
    main()
