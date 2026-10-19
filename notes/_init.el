;;; init.el --- Helheim, with packages from Nix  -*- lexical-binding: t; no-byte-compile: t -*-
;;; Commentary:
;;
;; Helheim's init.example.el, set up for this system. Nix installs every
;; package (modules/optional/notes/_package.nix), on Windows ahead of time
;; (_friends.nix). The palettes and Stylix's main font, and the example's
;; fonts for icons, are in my-look.el. Modules are Helheim's (user-lisp/helheim)
;; and ours (user-lisp/my, from _lisp/).
;;
;;; Code:

;;; Helheim core

;; typst-ts-mode's autoloads use a compile.el macro; without it they stop
;; before registering .typ files.
(require 'compile)

(setq helheim-package-manager 'nix)
(require 'helheim-core)

;; Nix compiled every package already; compile-angel would queue them again.
(remove-hook 'after-init-hook #'compile-angel-on-load-mode)

;; Nix provides the tree-sitter grammars; nothing here can build one.
(setopt treesit-auto-install-grammar 'never)

;; *scratch* is an empty page of text, not Lisp.
(setq initial-major-mode 'text-mode
      initial-scratch-message nil)

;;; Essentials

(require 'helheim-minibuffer) ; Vertico + Marginalia
(require 'helheim-completion) ; Corfu + Orderless + Cape
(require 'helheim-search)     ; Consult + Deadgrep
(require 'helheim-keybindings)

(require 'helheim-ibuffer)    ; Buffers menu
(require 'helheim-dired)      ; File manager
(require 'helheim-embark)     ; Context-aware action menus
(require 'helheim-modeline)   ; The status line
(require 'helheim-outline)    ; See "Outline Mode" in the Emacs manual
(require 'helheim-tab-bar)    ; Each tab is a set of windows, as in Vim

;;; Search

(require 'helheim-consult)  ; Search commands with preview
(require 'helheim-deadgrep) ; Ripgrep in Emacs

;;; IDE

(require 'helheim-xref)  ; Go to definition
(require 'helheim-eglot) ; Eglot + Flymake (both built in)

;; Helheim hides Flymake's name in the mode line with nil, which Flymake's
;; type for it (a string) doesn't allow: Emacs warned when Flymake loaded.
(put 'flymake-mode-line-lighter 'custom-check-value nil)

;;; Version control

(require 'helheim-magit)
(require 'helheim-diff-hl) ; Git gutter marks

;;; Snippets

(require 'helheim-snippets) ; YASnippet, with snippets in the completion menu

;; Yours first, where SPC i n saves them (`my-snippets-directory'), then the
;; ones in Helheim's folder, read-only: ours, for Typst (_snippets/).
(make-directory my-snippets-directory t)
(setopt yas-snippet-dirs
        (list my-snippets-directory
              (expand-file-name "snippets/" helheim-root-directory)))

;; In Typst they stay out of the menu that opens as you type: keys like link
;; and toc hold syllables of prose (in, to), and Enter closed the menu instead
;; of starting a line. / lists them, and a key then Tab expands one.
(defun my-snippets-on-request ()
  "Leave snippets out of the completion menu that opens as you type."
  (remove-hook 'completion-at-point-functions #'helheim-yas-capf t))
(add-hook 'typst-ts-mode-hook #'my-snippets-on-request)

;;; Major modes

(require 'helheim-markdown)

;;; Ours

(require 'my-look)        ; Fonts, shading, room
(require 'my-colors)      ; Colours as in Helix
(require 'my-hel)         ; Hel's cursor, SPC w and SPC q, as in Helix
(require 'my-bidi)        ; Hebrew and English in the same text
(require 'my-hebrew-keys) ; Commands from a Hebrew layout
(require 'my-spelling)    ; Spelling, in English and Hebrew
(require 'my-typst)       ; Typst files, with a live preview
(require 'my-notes)       ; Notes in Typst, from templates
(require 'my-files)       ; A file tree, as VS Code's
(require 'my-dashboard)   ; The start page
(require 'my-vim)         ; Helix's keys or Vim's

;;; init.el ends here
