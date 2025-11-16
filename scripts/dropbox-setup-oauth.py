#!/usr/bin/env python3
"""
Set up Dropbox OAuth with refresh token (never expires)

This script helps you get a refresh token for long-term Dropbox API access.
Run this once, and you'll never need to re-authenticate.
"""

import os
import sys
from dropbox import DropboxOAuth2FlowNoRedirect

TOKEN_FILE = os.path.join(os.path.dirname(__file__), '.dropbox-token')
REFRESH_TOKEN_FILE = os.path.join(os.path.dirname(__file__), '.dropbox-refresh-token')
APP_KEY_FILE = os.path.join(os.path.dirname(__file__), '.dropbox-app-key')
APP_SECRET_FILE = os.path.join(os.path.dirname(__file__), '.dropbox-app-secret')


def setup_oauth():
    """Interactive OAuth setup to get refresh token"""

    print("\n" + "="*70)
    print("DROPBOX OAUTH SETUP - GET REFRESH TOKEN")
    print("="*70 + "\n")

    # Check if we already have app credentials
    app_key = None
    app_secret = None

    if os.path.exists(APP_KEY_FILE):
        with open(APP_KEY_FILE, 'r') as f:
            app_key = f.read().strip()

    if os.path.exists(APP_SECRET_FILE):
        with open(APP_SECRET_FILE, 'r') as f:
            app_secret = f.read().strip()

    # Get app credentials if needed
    if not app_key or not app_secret:
        print("You need your Dropbox App credentials.")
        print("\nTo get them:")
        print("1. Go to: https://www.dropbox.com/developers/apps")
        print("2. Click on your app (or create one if needed)")
        print("3. Go to 'Settings' tab")
        print("4. Find 'App key' and 'App secret'\n")

        app_key = input("Enter App Key: ").strip()
        app_secret = input("Enter App Secret: ").strip()

        # Save for future use
        with open(APP_KEY_FILE, 'w') as f:
            f.write(app_key)
        os.chmod(APP_KEY_FILE, 0o600)

        with open(APP_SECRET_FILE, 'w') as f:
            f.write(app_secret)
        os.chmod(APP_SECRET_FILE, 0o600)

        print("\n✓ App credentials saved\n")

    # Start OAuth flow
    print("="*70)
    print("STEP 1: Authorize the app")
    print("="*70 + "\n")

    auth_flow = DropboxOAuth2FlowNoRedirect(
        app_key,
        consumer_secret=app_secret,
        token_access_type='offline'  # This is the key - gets us a refresh token!
    )

    authorize_url = auth_flow.start()

    print(f"1. Go to this URL in your browser:\n")
    print(f"   {authorize_url}\n")
    print("2. Click 'Allow' (you might need to log in first)")
    print("3. Copy the authorization code\n")

    auth_code = input("Enter the authorization code here: ").strip()

    # Exchange code for tokens
    print("\n" + "="*70)
    print("STEP 2: Getting tokens...")
    print("="*70 + "\n")

    try:
        oauth_result = auth_flow.finish(auth_code)

        access_token = oauth_result.access_token
        refresh_token = oauth_result.refresh_token

        # Save refresh token (this is what we really want!)
        with open(REFRESH_TOKEN_FILE, 'w') as f:
            f.write(f"{app_key}\n{app_secret}\n{refresh_token}")
        os.chmod(REFRESH_TOKEN_FILE, 0o600)

        # Save access token too (valid for 4 hours)
        with open(TOKEN_FILE, 'w') as f:
            f.write(access_token)
        os.chmod(TOKEN_FILE, 0o600)

        print("✓ SUCCESS!")
        print(f"\n✓ Refresh token saved to: {REFRESH_TOKEN_FILE}")
        print(f"✓ Access token saved to: {TOKEN_FILE}")
        print("\nYou're all set! The refresh token will work forever.")
        print("Your scripts will now automatically refresh access tokens as needed.\n")

        return True

    except Exception as e:
        print(f"\n✗ Error: {e}")
        return False


if __name__ == '__main__':
    if not setup_oauth():
        sys.exit(1)
