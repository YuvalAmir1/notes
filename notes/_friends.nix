# The notes for others to install, built as notes.nix builds yours
# (_package.nix), in palettes of their own that your wallpaper doesn't change:
#
# - notes, for Linux and macOS: Emacs, the setup and its fonts, run by
#   `emacs` (and Emacs in the menus);
# - notes-windows (from x86_64-linux): the setup as a folder for Windows
#   (notes-windows.zip) and the script that installs it with Emacs and the
#   programs (install.ps1).
#
# Your flake builds them for trying (package.nix); the public repository
# that notes-publish fills (_publish.nix) builds them for everyone.
{
  pkgs,
  lib,
  inputs,
  system,
}:
let
  # Where notes-publish puts them, and the Windows script downloads from.
  repository = "YuvalAmir1/notes";

  # Their palettes: Catppuccin's Mocha (dark) and Latte (light), as
  # tinted-theming maps them to base16, with mantle and crust as base10 and
  # base11; and their fonts.
  palettes = {
    dark = {
      base00 = "#1e1e2e";
      base01 = "#313244";
      base02 = "#45475a";
      base03 = "#6c7086";
      base04 = "#a6adc8";
      base05 = "#cdd6f4";
      base06 = "#f5e0dc";
      base07 = "#b4befe";
      base08 = "#f38ba8";
      base09 = "#fab387";
      base0A = "#f9e2af";
      base0B = "#a6e3a1";
      base0C = "#94e2d5";
      base0D = "#89b4fa";
      base0E = "#cba6f7";
      base0F = "#f2cdcd";
      base10 = "#181825";
      base11 = "#11111b";
    };
    light = {
      base00 = "#eff1f5";
      base01 = "#ccd0da";
      base02 = "#bcc0cc";
      base03 = "#9ca0b0";
      base04 = "#6c6f85";
      base05 = "#4c4f69";
      base06 = "#dc8a78";
      base07 = "#7287fd";
      base08 = "#d20f39";
      base09 = "#fe640b";
      base0A = "#df8e1d";
      base0B = "#40a02b";
      base0C = "#179299";
      base0D = "#1e66f5";
      base0E = "#8839ef";
      base0F = "#dd7878";
      base10 = "#e6e9ef";
      base11 = "#dce0e8";
    };
  };
  mono = {
    name = "JetBrainsMono Nerd Font";
    package = pkgs.nerd-fonts.jetbrains-mono;
  };
  sans = {
    name = "Inter";
    package = pkgs.inter;
  };

  # GNU's build of Emacs for Windows, of the version the others have.
  windowsEmacs = {
    version = "31.1";
    url = "https://ftp.gnu.org/gnu/emacs/windows/emacs-31/emacs-31.1_1.zip";
    sha256 = "02856997d64c42e1e267b12b03ed67ff19a0599983e2f5871637077f7d12a92e";
  };

  inherit (pkgs.stdenv) hostPlatform;

  notes = import ./_package.nix {
    inherit pkgs lib inputs;
    emacs = if hostPlatform.isDarwin then pkgs.emacs else pkgs.emacs-pgtk;
    theme = {
      inherit palettes;
      polarity = "dark";
      sans = sans.name;
      mono = mono.name;
      size = 12;
      # Opaque: the editor shows base, as the preview's page does.
      opacity = 1.0;
    };
  };

  # The fonts the notes and Emacs use: the sans-serif one, Helheim's icons,
  # and Hebrew's; of the monospace one, its four main styles.
  fontFiles =
    pkgs.runCommand "notes-fonts"
      {
        nativeBuildInputs = [ pkgs.fontconfig ];
        mono = mono.name;
        families = lib.concatStringsSep "|" [
          sans.name
          "Symbols Nerd Font"
          "Symbols Nerd Font Mono"
          "Noto Sans Hebrew"
          "Noto Serif Hebrew"
        ];
      }
      ''
        mkdir $out
        find ${
          lib.concatMapStringsSep " " (font: "${font}/share/fonts") [
            mono.package
            sans.package
            pkgs.nerd-fonts.symbols-only
            pkgs.noto-fonts
          ]
        } -type f \( -name '*.ttf' -o -name '*.otf' -o -name '*.ttc' \) |
          while read -r file; do
            if fc-scan --format '%{family[0]}\t%{style[0]}\n' "$file" |
              awk -F '\t' -v mono="$mono" -v families="$families" '
                BEGIN { n = split(families, list, "|"); for (i = 1; i <= n; i++) keep[list[i]] = 1 }
                ($1 == mono && $2 ~ /^(Regular|Bold|Italic|Bold Italic)$/) || ($1 in keep) { found = 1 }
                END { exit !found }'; then
              cp "$file" $out/
            fi
          done
      '';

  init = notes.mkInit {
    inherit (notes) enchant;
    "typst-packages/local/notes/0.1.0" = notes.typstNotes;
    "typst-packages/preview" = notes.typstLibraries;
    fonts = fontFiles;
  };

  # Linux: Wayland's Emacs in a Wayland session, else X's (with the same
  # packages, built for the first), and the fonts beside the system's.
  x11 = (pkgs.emacsPackagesFor pkgs.emacs).withPackages (_: notes.packages notes.emacsPackages);

  fontsConf = pkgs.writeText "fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      <dir>${fontFiles}</dir>
      <cachedir prefix="xdg">fontconfig</cachedir>
      <match>
        <test name="lang" compare="contains"><string>he</string></test>
        <edit name="family" mode="prepend" binding="strong"><string>Noto Sans Hebrew</string></edit>
      </match>
    </fontconfig>
  '';

  linux = pkgs.symlinkJoin {
    name = "notes";
    meta.mainProgram = "emacs";
    paths = [
      (pkgs.writeShellScriptBin "emacs" ''
        if [ -n "''${WAYLAND_DISPLAY-}" ]; then
          emacs=${notes.emacsWithPackages}
        else
          emacs=${x11}
        fi
        export FONTCONFIG_FILE=${fontsConf}
        exec "$emacs/bin/emacs" --init-directory=${init} "$@"
      '')
      (pkgs.makeDesktopItem {
        name = "notes";
        desktopName = "Emacs";
        genericName = "Text Editor";
        comment = "Notes in Typst";
        icon = "emacs";
        exec = "emacs %F";
        mimeTypes = [ "text/vnd.typst" ];
        categories = [
          "Office"
          "TextEditor"
        ];
        startupWMClass = "Emacs";
      })
      (pkgs.runCommand "notes-icons" { } ''
        mkdir -p $out/share
        ln -s ${pkgs.emacs}/share/icons $out/share/icons
      '')
    ];
  };

  # macOS: Emacs takes fonts from the system, so the notes' are put in
  # yours once; the first start also puts Emacs in Applications, in place
  # of the Notes it was called once.
  bundle = "com.github.${lib.replaceStrings [ "/" ] [ "." ] repository}";
  macLauncher = pkgs.writeShellApplication {
    name = "emacs";
    text = ''
      fonts=${fontFiles}
      bundle=${bundle}
      icon=${pkgs.emacs}/Applications/Emacs.app/Contents/Resources/Emacs.icns
      emacs=${notes.emacsWithPackages}/bin/emacs
      init=${init}
    ''
    + builtins.readFile ./_mac-launcher.sh;
  };

  # Windows: the setup as a folder, with the packages compiled here, the
  # Typst grammar and the keyboard add-on built for Windows, and the
  # script that installs it with Emacs and the programs.
  windows =
    let
      mingw = pkgs.pkgsCross.mingwW64;
      grammar = mingw.stdenv.mkDerivation {
        pname = "tree-sitter-typst";
        version = "1";
        src = inputs.tree-sitter-typst;
        buildPhase = "$CC -O2 -shared -Isrc -o libtree-sitter-typst.dll src/parser.c src/scanner.c";
        installPhase = "install -D libtree-sitter-typst.dll $out/libtree-sitter-typst.dll";
      };
      helheim = pkgs.runCommand "helheim-windows" { } ''
        cp -r ${notes.helheim} $out
        chmod -R u+w $out
        rm $out/user-lisp/my/my-keyboard.so
        cp ${notes.mkKeyboard mingw}/lib/my-keyboard.dll $out/user-lisp/my/
      '';
      siteLisp = pkgs.runCommand "notes-site-lisp" { } ''
        cp -rL ${notes.emacsWithPackages.deps}/share/emacs/site-lisp $out
        chmod -R u+w $out
        rm -f $out/site-start.el* $out/subdirs.el*
        find $out \( -name '*.so' -o -name '*.eln' \) -delete
      '';
      folder = notes.mkInit {
        inherit helheim;
        site-lisp = siteLisp;
        tree-sitter = grammar;
        "typst-packages/local/notes/0.1.0" = notes.typstNotes;
        "typst-packages/preview" = notes.typstLibraries;
        fonts = fontFiles;
      };
      script = pkgs.replaceVars ./_windows/install.ps1 {
        inherit repository;
        emacsVersion = windowsEmacs.version;
        emacsUrl = windowsEmacs.url;
        emacsSha256 = lib.toUpper windowsEmacs.sha256;
        typstVersion = pkgs.typst.version;
        tinymistVersion = pkgs.tinymist.version;
        ripgrepVersion = pkgs.ripgrep.version;
        fdVersion = pkgs.fd.version;
      };
    in
    assert lib.assertMsg
      (lib.versions.major windowsEmacs.version == lib.versions.major pkgs.emacs-pgtk.version)
      "optional/notes/_friends.nix: Emacs for Windows is ${windowsEmacs.version}, the others ${pkgs.emacs-pgtk.version}; its packages, compiled by the second, need the same major version.";
    pkgs.runCommand "notes-windows" { nativeBuildInputs = [ pkgs.zip ]; } ''
      mkdir -p $out work
      # The store's times, all the same: Emacs, preferring the newer
      # of a .el and its .elc, takes the compiled one.
      cp -rL --preserve=timestamps ${folder} work/config
      chmod -R u+w work
      (cd work && zip -qr9 $out/notes-windows.zip config)
      sed 's/$/\r/' ${script} > $out/install.ps1
    '';
in
{
  inherit repository;
  packages =
    lib.optionalAttrs hostPlatform.isLinux { notes = linux; }
    // lib.optionalAttrs hostPlatform.isDarwin { notes = macLauncher; }
    // lib.optionalAttrs (system == "x86_64-linux") { notes-windows = windows; };
}
