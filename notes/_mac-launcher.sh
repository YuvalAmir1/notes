# fonts, bundle, icon, emacs and init come from _friends.nix.
mkdir -p "$HOME/Library/Fonts"
for font in "$fonts"/*; do
  [ -e "$HOME/Library/Fonts/${font##*/}" ] || cp "$font" "$HOME/Library/Fonts/"
done
old="$HOME/Applications/Notes.app"
if grep -qs "$bundle" "$old/Contents/Info.plist"; then
  rm -r "$old"
fi
if [ ! -e "$HOME/Applications/Emacs.app" ]; then
  case "$0" in
    /nix/store/*) self="$HOME/.nix-profile/bin/emacs" ;;
    *) self="$0" ;;
  esac
  app="$HOME/Applications/Emacs.app/Contents"
  mkdir -p "$app/MacOS" "$app/Resources"
  cp "$icon" "$app/Resources/Emacs.icns"
  cat >"$app/Info.plist" <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Emacs</string>
  <key>CFBundleExecutable</key><string>Emacs</string>
  <key>CFBundleIdentifier</key><string>$bundle</string>
  <key>CFBundleIconFile</key><string>Emacs</string>
  <key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
EOT
  # shellcheck disable=SC2016 # "$@" is for the script this writes
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$self" >"$app/MacOS/Emacs"
  chmod +x "$app/MacOS/Emacs"
fi
exec "$emacs" --init-directory="$init" "$@"
