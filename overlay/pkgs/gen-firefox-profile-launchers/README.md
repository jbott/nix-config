# Firefox Profile Launchers Generator

A Python script that automatically creates macOS application launchers for your Firefox profiles, allowing you to launch specific Firefox profiles directly from your Applications folder or Dock as independent running applications.

Inspired by:
- https://asqueella.blogspot.com/2010/01/using-firefox-profiles-on-mac-os-x.html
- http://web.archive.org/web/20100717003457/http://spf13.com/feature/managing-firefox-profiles-os-x

## Requirements

- **Firefox installed** (will be found automatically using macOS `open` command)
- **At least one Firefox profile** created (run Firefox once to create profiles)
- **Python 3** (uses only standard library modules)

## Usage

```bash
python3 gen-firefox-profile-launchers.py
```

The script will:
- Check if Firefox is properly installed
- Scan your Firefox profiles from `~/Library/Application Support/Firefox/profiles.ini`
- Create launcher apps in `~/Applications/` for each non-default profile
- Skip profiles that already have launchers
