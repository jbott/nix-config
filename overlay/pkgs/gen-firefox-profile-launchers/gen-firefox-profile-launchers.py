#!/usr/bin/env python3

import configparser
import sys
from pathlib import Path

def find_firefox_path():
    """Find Firefox.app path using spotlight search."""
    import subprocess
    try:
        result = subprocess.run(['mdfind', 'kMDItemCFBundleIdentifier == "org.mozilla.firefox"'],
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0 and result.stdout.strip():
            return Path(result.stdout.strip().split('\n')[0])
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return None

def create_launcher_app(profile_name, applications_dir, firefox_path):
    """Create a macOS app launcher for a Firefox profile."""
    launcher_path = applications_dir / f"Firefox ({profile_name}).app"

    if launcher_path.exists():
        print(f"Skipping existing launcher: Firefox ({profile_name}).app")
        return

    # Create directory structure
    macos_dir = launcher_path / "Contents" / "MacOS"
    macos_dir.mkdir(parents=True, exist_ok=True)

    # Create Info.plist
    info_plist = launcher_path / "Contents" / "Info.plist"
    info_plist.write_text(f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>firefox-{profile_name}</string>
    <key>CFBundleIconFile</key>
    <string>firefox.icns</string>
    <key>CFBundleIdentifier</key>
    <string>org.mozilla.firefox.{profile_name}</string>
    <key>CFBundleName</key>
    <string>Firefox ({profile_name})</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
</dict>
</plist>
""")

    # Create executable script
    executable = macos_dir / f"firefox-{profile_name}"
    executable.write_text(f"""#!/usr/bin/env bash
open -n -a Firefox.app --args -no-remote -P "{profile_name}" "$@"
""")
    executable.chmod(0o755)

    # Copy Firefox icon if available
    if firefox_path:
        firefox_icon = firefox_path / "Contents" / "Resources" / "firefox.icns"
        if firefox_icon.exists():
            resources_dir = launcher_path / "Contents" / "Resources"
            resources_dir.mkdir(parents=True, exist_ok=True)
            import shutil
            shutil.copy2(firefox_icon, resources_dir / "firefox.icns")

    print(f"Created launcher: Firefox ({profile_name}).app")

def main():
    # Find Firefox installation path
    firefox_path = find_firefox_path()
    if not firefox_path:
        print("Error: Firefox is not installed or cannot be found")
        print("Please install Firefox from https://www.mozilla.org/firefox/ before running this script.")
        sys.exit(1)

    profiles_ini = Path.home() / "Library" / "Application Support" / "Firefox" / "profiles.ini"
    applications_dir = Path.home() / "Applications"

    if not profiles_ini.exists():
        print(f"Firefox profiles.ini not found at: {profiles_ini}")
        print("Firefox may not have been run yet. Please start Firefox at least once to create profiles.")
        sys.exit(1)

    applications_dir.mkdir(parents=True, exist_ok=True)

    # Parse profiles.ini
    config = configparser.ConfigParser()
    config.read(profiles_ini)

    # Find all profile sections and create launchers for non-default profiles
    for section_name in config.sections():
        if section_name.startswith("Profile"):
            section = config[section_name]
            if "Name" in section:
                profile_name = section["Name"]
                # Skip profiles containing "default" (case-insensitive)
                if "default" not in profile_name.lower():
                    create_launcher_app(profile_name, applications_dir, firefox_path)

    print("Firefox profile launchers created successfully!")

if __name__ == "__main__":
    main()
