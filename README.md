# Notes

Emacs set up for notes in [Typst](https://typst.app), in Hebrew and English: a live preview beside the text, templates, links between notes, a note for each day, notebooks that make one PDF of many notes, snippets, spell checking, a file tree, Typst's libraries for mathematics, physics and computer science, and Helix's keys or Vim's. Hebrew layouts still give commands, as the Latin keys in their places, whichever Latin layout you use.

This repository is made from a private configuration by its `notes-publish` command; changes are made there.

## Install

**Linux and macOS** (Apple silicon), through [Nix](https://nixos.org):

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

Open a new terminal, then:

```sh
nix profile add github:YuvalAmir1/notes#notes
```

The first time takes a while: Emacs's packages are compiled on your computer. Start it with `emacs` (if you had an Emacs, this one takes its place). On Linux, Emacs is in the apps menu after you log out and in; on a Mac, the first start puts Emacs in the Applications folder of your home folder.

**Windows**, in PowerShell, with no admin rights needed:

```powershell
irm https://github.com/YuvalAmir1/notes/releases/download/notes/install.ps1 | iex
```

Emacs is then in the Start menu and on the desktop. Spell checking isn't available on Windows.

## Update

- Linux and macOS: `nix profile upgrade --all`, then open Emacs again.
- Windows: close Emacs and run the same line again; it downloads only what changed.

## First steps

The first start asks whether to edit with Helix's keys or Vim's. Either way, `i` starts typing, `Esc` stops, and `Space` opens a menu of commands that shows the keys as you go.

| To | Press |
| --- | --- |
| make a note from a template | `Space n t`, then a title |
| open a note by its title | `Space n n` |
| search every note | `Space n /` |
| open today's note | `Space n d` |
| link another note (`g f` follows a link) | `Space n l` |
| include a note in a notebook | `Space n i` |
| paste a picture from the clipboard | `Space i p` |
| set the note up for one of Typst's libraries | `Space i l` |
| save | `Space w` |
| close the window | `Space q` |
| show or hide the file tree | `Space e` |
| go into the tree, and back to the note (the window to the left, to the right) | `C-w h`, `C-w l` |
| stop or start the preview | `Space c p` |
| write the PDF next to the note | `Space Space` |
| switch between dark and light | `Space t l` |
| show the preview as the PDF looks, or in the theme | `Space t p` |
| switch between Helix's keys and Vim's | `Space t k` |
| turn a paragraph the other way (a Hebrew one that starts with an English word), and back | `Space t f` |

Notes are Typst files in `notes` in your home folder; any `.typ` file in `notes/templates` is a template.

Typst's libraries for physics notation, units, plots, drawings, diagrams, theorems, pseudocode and more come installed and work offline: `Space i l` lists them. The colours are [Catppuccin](https://catppuccin.com)'s Mocha and Latte. The preview opens in a window of its own when Chrome, Edge, Brave, Chromium or Vivaldi is installed (Edge comes with Windows), else in a tab of your browser.

## Remove

- Linux and macOS: `nix profile remove notes`; on a Mac, also delete Emacs from the Applications folder in your home folder.
- Windows: delete `%LOCALAPPDATA%\Notes` and the two Emacs shortcuts.

Your notes stay where they are.
