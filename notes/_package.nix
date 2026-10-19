# The notes' Emacs, built the same way for your machines (notes.nix) and
# for the copies others install (package.nix).
{
  pkgs,
  lib,
  inputs,
  # The Emacs the packages are built for.
  emacs,
  # The palettes, dark and light ("#rrggbb" by base16 name), the one Emacs
  # starts with (polarity), the sans-serif and monospace fonts' names, the
  # font size, and the windows' opacity.
  theme,
}:
let
  # MELPA's version format, from the commit date (20260709.48 for 00:48):
  # newer than any release number, which packages that need Hel check for.
  dated =
    input:
    let
      date = input.lastModifiedDate;
    in
    "${lib.substring 0 8 date}.${toString (lib.toIntBase10 (lib.substring 8 4 date))}";

  fromInput =
    epkgs: name: args:
    epkgs.melpaBuild (
      {
        pname = name;
        version = dated inputs.${name};
        src = inputs.${name};
      }
      // args
    );

  # Hel and its extensions from their repositories, updated with Helheim,
  # and a package nixpkgs doesn't have.
  overrides = self: _: {
    hel = fromInput self "hel" {
      packageRequires = with self; [
        avy
        dash
        pcre2el
        ultra-scroll
      ];
    };
    hel-leader = fromInput self "hel-leader" {
      packageRequires = with self; [
        dash
        hel
        s
      ];
    };
    hel-collection = fromInput self "hel-collection" {
      files = ''(:defaults "modes")'';
      packageRequires = with self; [
        dash
        hel
      ];
    };
    dired-copy-paste = fromInput self "dired-copy-paste" { };
  };

  typstGrammar = pkgs.tree-sitter.buildGrammar {
    language = "typst";
    version = dated inputs.tree-sitter-typst;
    src = inputs.tree-sitter-typst;
  };

  # What the Helheim modules in _init.el install, then ours.
  packages =
    epkgs: with epkgs; [
      # helheim-core, helheim-keybindings
      adaptive-wrap
      avy
      blackout
      bufferfile
      compat
      compile-angel
      cond-let
      dash
      edit-indirect
      f
      hel
      hel-collection
      hel-leader
      helpful
      nerd-icons
      rainbow-delimiters
      s
      transient
      ultra-scroll
      visual-fill-column
      vundo
      wgrep
      which-key-posframe
      # minibuffer, completion, search, embark, modeline, outline
      cape
      consult
      corfu
      deadgrep
      doom-modeline
      embark
      embark-consult
      marginalia
      nerd-icons-completion
      nerd-icons-corfu
      orderless
      outli
      vertico
      # dired
      async
      casual
      dired-copy-paste
      dired-filter
      dired-narrow
      dired-subtree
      diredfl
      fd-dired
      nerd-icons-dired
      # magit, diff-hl, xref, eglot
      breadcrumb
      consult-eglot
      diff-hl
      dumb-jump
      eldoc-box
      flymake-popon
      git-modes
      magit
      nerd-icons-xref
      sideline
      sideline-eglot
      sideline-flymake
      yasnippet
      # snippets, markdown
      yasnippet-capf
      markdown-mode
      # ours
      base16-theme
      dashboard
      evil
      evil-collection
      jinx
      solaire-mode
      spacious-padding
      treemacs
      treemacs-evil
      treemacs-nerd-icons
      typst-preview
      typst-ts-mode
      (treesit-grammars.with-grammars (
        grammars:
        [ typstGrammar ]
        ++ (with grammars; [
          tree-sitter-bash
          tree-sitter-c
          tree-sitter-cpp
          tree-sitter-css
          tree-sitter-go
          tree-sitter-html
          tree-sitter-javascript
          tree-sitter-json
          tree-sitter-lua
          tree-sitter-markdown
          tree-sitter-markdown-inline
          tree-sitter-nix
          tree-sitter-python
          tree-sitter-rust
          tree-sitter-toml
          tree-sitter-tsx
          tree-sitter-typescript
          tree-sitter-yaml
        ])
      ))
      # Programs Emacs runs, on its own PATH.
      pkgs.fd
      pkgs.ripgrep
      pkgs.tinymist
      pkgs.typst
    ];

  emacsPackages = (pkgs.emacsPackagesFor emacs).overrideScope overrides;
  emacsWithPackages = emacsPackages.withPackages packages;

  start = theme.palettes.${theme.polarity};

  # The colours both palettes have, by base16 (and base24) name, in order.
  colorNames = lib.filter (name: theme.palettes.light ? ${name}) (lib.attrNames theme.palettes.dark);

  palette =
    name: colors:
    "(${name}\n     ${
      lib.concatMapStringsSep "\n     " (color: ''(${color} . "${colors.${color}}")'') colorNames
    })";

  stylixValues = pkgs.writeText "my-stylix.el" ''
    ;;; my-stylix.el --- The palettes and fonts  -*- lexical-binding: t -*-
    (defconst my-stylix-palettes
      '(${palette "dark" theme.palettes.dark}
        ${palette "light" theme.palettes.light})
      "The palettes, dark and light: (NAME . \"#rrggbb\") by base16 name.")
    (defconst my-stylix-polarity '${theme.polarity}
      "The palette Emacs starts with.")
    (defvar my-stylix-colors (alist-get my-stylix-polarity my-stylix-palettes)
      "The palette in use.")
    (defconst my-stylix-sans "${theme.sans}")
    (defconst my-stylix-mono "${theme.mono}")
    (defconst my-stylix-size (float ${toString theme.size}))
    (defconst my-stylix-opacity ${toString (builtins.ceil (theme.opacity * 100))})
    (provide 'my-stylix)
  '';

  # The keyboard add-on (my-keyboard.c), for a system: Linux, macOS, or
  # Windows from Linux.
  mkKeyboard =
    target:
    let
      platform = target.stdenv.hostPlatform;
      suffix =
        if platform.isWindows then
          ".dll"
        else if platform.isDarwin then
          ".dylib"
        else
          ".so";
      flags =
        if platform.isWindows then
          "-shared -luser32"
        else if platform.isDarwin then
          "-dynamiclib -undefined dynamic_lookup -framework Carbon"
        else
          "-shared -fPIC $(pkg-config --cflags --libs gtk+-3.0 x11)";
    in
    target.stdenv.mkDerivation {
      pname = "my-keyboard";
      version = "1";
      src = ./_keyboard;
      nativeBuildInputs = lib.optional platform.isLinux pkgs.pkg-config;
      buildInputs = lib.optionals platform.isLinux [
        target.gtk3
        target.libx11
      ];
      buildPhase = ''
        runHook preBuild
        $CC -O2 -Wall -Wextra -Wno-unused-parameter -o my-keyboard${suffix} my-keyboard.c \
          -I${emacs}/include ${flags}
        runHook postBuild
      '';
      installPhase = ''
        runHook preInstall
        install -D my-keyboard${suffix} $out/lib/my-keyboard${suffix}
        runHook postInstall
      '';
    };

  keyboard = mkKeyboard pkgs;

  # Helheim with its autoloads indexed and its files compiled, which it
  # would otherwise do in its own folder at the first start; ours in
  # user-lisp/my.
  helheim = pkgs.stdenvNoCC.mkDerivation {
    pname = "helheim";
    version = dated inputs.helheim;
    src = inputs.helheim;
    patches = [ ./_helheim-nix.patch ];
    nativeBuildInputs = [ emacsWithPackages ];
    buildPhase = ''
      runHook preBuild
      mkdir user-lisp/my
      cp ${./_lisp}/*.el user-lisp/my/
      cp -r ${./_snippets} snippets
      cp ${stylixValues} user-lisp/my/my-stylix.el
      cp ${librariesValues} user-lisp/my/my-typst-libraries.el
      cp ${keyboard}/lib/* user-lisp/my/
      HOME=$TMPDIR emacs --batch -l ${./_build.el} user-lisp
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      # Helheim's early-init.el points user-emacs-directory here, which
      # Emacs would try to create; ours then moves it out of the store.
      mkdir var
      cp -r . $out
      runHook postInstall
    '';
  };

  # The look notes import (@local/notes), in the same font and colours.
  typstNotes = pkgs.linkFarm "typst-notes-0.1.0" {
    "typst.toml" = pkgs.writeText "typst.toml" ''
      [package]
      name = "notes"
      version = "0.1.0"
      entrypoint = "notes.typ"
    '';
    "notes.typ" = pkgs.replaceVars ./_typst/notes.typ {
      inherit (theme) sans;
      inherit (start)
        base00
        base03
        base05
        base08
        base09
        base0A
        base0B
        base0C
        base0D
        base0E
        ;
    };
  };

  inherit (import ./_typst-libraries.nix { inherit pkgs lib; }) typstLibraries librariesValues;

  # Jinx's dictionaries, where Enchant looks first: Hunspell's US English
  # and Hebrew. Enchant would check Hebrew with Hspell, which passes every
  # Latin word, misspelled English too.
  enchant = pkgs.linkFarm "enchant-config" {
    hunspell = pkgs.symlinkJoin {
      name = "hunspell-dictionaries";
      paths = map (dictionary: "${dictionary}/share/hunspell") [
        pkgs.hunspellDicts.en_US
        pkgs.hunspellDicts.he_IL
      ];
    };
    "enchant.ordering" = pkgs.writeText "enchant.ordering" ''
      he_IL:hunspell
      he:hunspell
    '';
  };

  # The folder Emacs starts from: early-init.el, init.el and Helheim, and
  # what a copy others install needs beside them (_early-init.el).
  mkInit =
    extra:
    pkgs.linkFarm "notes-init" (
      {
        "early-init.el" = ./_early-init.el;
        "init.el" = ./_init.el;
        inherit helheim;
        templates = ./_typst/templates;
      }
      // extra
    );
in
{
  inherit
    overrides
    packages
    emacsPackages
    emacsWithPackages
    helheim
    typstNotes
    typstLibraries
    enchant
    mkInit
    mkKeyboard
    keyboard
    ;
  init = mkInit { };
}
