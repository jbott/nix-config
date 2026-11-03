{
  lib,
  runCommandLocal,
  stdenv,
  herdr-app,
}:
# llm-agents installs only bin/herdr-app on macOS; this is the bundle
# upstream's scripts/package makes. It holds the real binary rather than the
# wrapper script, which only adds herdr-core to PATH: macOS ties the window to
# the bundle only if the process starts inside it, and the app already finds
# herdr-core in /run/current-system/sw/bin.
if !stdenv.hostPlatform.isDarwin
then herdr-app
else
  runCommandLocal "herdr-app-${herdr-app.version}" {
    inherit (herdr-app) version;
    passthru = {inherit (herdr-app) src;};
    meta = herdr-app.meta // {platforms = lib.platforms.darwin;};
  } ''
    app=$out/Applications/Herdr.app
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$out/bin"
    cp ${herdr-app}/bin/.herdr-app-wrapped "$app/Contents/MacOS/Herdr"
    cp ${herdr-app.src}/assets/icons/Herdr.icns "$app/Contents/Resources/Herdr.icns"
    cp ${herdr-app.src}/LICENSE ${herdr-app.src}/THIRD-PARTY-NOTICES "$app/Contents/Resources/"
    # Usage descriptions are from upstream's 0.1.12 DMG.
    cat > "$app/Contents/Info.plist" <<PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
        <key>CFBundleExecutable</key><string>Herdr</string>
        <key>CFBundleIdentifier</key><string>dev.herdr.app</string>
        <key>CFBundleName</key><string>Herdr</string>
        <key>CFBundleDisplayName</key><string>Herdr</string>
        <key>CFBundleIconFile</key><string>Herdr</string>
        <key>CFBundlePackageType</key><string>APPL</string>
        <key>CFBundleShortVersionString</key><string>${herdr-app.version}</string>
        <key>CFBundleVersion</key><string>${herdr-app.version}</string>
        <key>NSPrincipalClass</key><string>NSApplication</string>
        <key>NSHighResolutionCapable</key><true/>
        <key>NSAppleEventsUsageDescription</key><string>Terminal programs running in Herdr can use AppleScript to control other apps.</string>
        <key>NSCameraUsageDescription</key><string>Terminal programs running in Herdr can use the camera.</string>
        <key>NSMicrophoneUsageDescription</key><string>Terminal programs running in Herdr can use the microphone, for example for voice input.</string>
        <key>LSEnvironment</key><dict/></dict></plist>
    PLIST
    ln -s "$app/Contents/MacOS/Herdr" "$out/bin/herdr-app"
  ''
