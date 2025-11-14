# Dropbox API Setup Guide

This guide will help you get a Dropbox API token to run the catalog script.

## Quick Setup (5 minutes)

### Step 1: Create Dropbox App

1. Go to https://www.dropbox.com/developers/apps
2. Click **"Create app"**
3. Choose settings:
   - **API:** Scoped access
   - **Access type:** Full Dropbox (to scan everything)
   - **App name:** Something like "laptop-tools-catalog" (must be unique)
4. Click **"Create app"**

### Step 2: Configure Permissions

1. On your app's settings page, click the **"Permissions"** tab
2. Enable these permissions:
   - `files.metadata.read` (Read file metadata)
   - `files.content.read` (Read file content - for hashing)
3. Click **"Submit"** at the bottom

### Step 3: Generate Access Token

1. Go back to the **"Settings"** tab
2. Scroll down to **"OAuth 2"** section
3. Under "Generated access token", click **"Generate"**
4. Copy the token (long string starting with `sl.`)
5. **Keep this secret!** Don't share it or commit it to git

### Step 4: Run the Script

**Option A: Set environment variable (temporary)**
```bash
export DROPBOX_TOKEN="your-token-here"
python3 catalog-dropbox.py
```

**Option B: Enter token when prompted (saves for future use)**
```bash
python3 catalog-dropbox.py
# Script will prompt for token and save it to .dropbox-token
```

**Option C: Manually create token file**
```bash
echo "your-token-here" > .dropbox-token
chmod 600 .dropbox-token
python3 catalog-dropbox.py
```

## Install Dependencies

Before running the script, install required Python packages:

```bash
pip install dropbox
```

Or use the requirements file:

```bash
pip install -r dropbox-requirements.txt
```

## What the Script Does

- **Connects to Dropbox API** (no local sync required)
- **Scans entire account** recursively
- **Analyzes files** by size, age, type, duplicates
- **Generates reports**:
  - JSON catalog (machine-readable)
  - Text summary (human-readable)
- **Provides recommendations** for cleanup

## Output

The script creates files in `scripts/catalog/`:
- `dropbox-catalog-TIMESTAMP.json` - Full data
- `dropbox-catalog-TIMESTAMP.txt` - Summary report

## Security Notes

- ✅ Token is stored in `.dropbox-token` with secure permissions (600)
- ✅ `.dropbox-token` is already in `.gitignore` (won't be committed)
- ✅ Script is read-only (makes no changes to your Dropbox)
- ⚠️ Keep your token secret - it has full access to your Dropbox

## Troubleshooting

**"Invalid token" error**
- Token may have expired - generate a new one
- Check you copied the entire token (no extra spaces)

**"Permission denied" error**
- Go back to Step 2 and enable the required permissions
- You may need to regenerate the token after changing permissions

**Script is slow**
- Normal for large accounts (1000s of files)
- Script shows progress every 1000 files
- Can take 5-15 minutes for very large accounts

## Next Steps

After running the script:
1. Review the text report
2. Share it with Gordo
3. Plan your cleanup strategy together!

---

**Created:** 2025-11-15
**Purpose:** Dropbox cleanup and reorganization project
