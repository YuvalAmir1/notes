;;; my-colors.el --- Colours as Helix shows them  -*- lexical-binding: t -*-
;;; Commentary:
;;
;; Stylix colours Emacs and Helix from one palette, each through its own
;; template (base16-theme here, which my-look.el loads). Here
;; Emacs takes Helix's choices: code; Typst, each heading level in its
;; colour and code in raw blocks in its language's; the mode line, the
;; completion menu and the cursors. Red is for errors alone, as in Helix
;; (helix.nix): not for variables, headings, deleted lines, files flagged
;; for deletion or icons.
;;
;;; Code:

(require 'my-stylix)
(require 'my-look)

;; typst-ts-mode reads these as it loads.
(defvar typst-ts-markup-header-same-height)
(defvar typst-ts-enable-raw-blocks-highlight)
(setq typst-ts-markup-header-same-height nil
      typst-ts-enable-raw-blocks-highlight t)

;; Helix colours code by its grammar alone; here too, without the language
;; server's colours (semantic tokens) over it.
(defvar eglot-ignored-server-capabilities)
(with-eval-after-load 'eglot
  (add-to-list 'eglot-ignored-server-capabilities :semanticTokensProvider))

;; The `user' theme outlasts `load-theme'.
(defun my-colors (colors)
  "Give the faces Helix's colours from COLORS, an alist by base16 name."
  (let-alist colors
    (custom-theme-set-faces
     'user
     ;; Code
     '(font-lock-comment-face ((t :slant italic)))
     '(font-lock-comment-delimiter-face ((t :slant italic)))
     `(font-lock-variable-name-face ((t :foreground ,.base05)))
     `(font-lock-property-name-face ((t :foreground ,.base0D)))
     `(font-lock-number-face ((t :foreground ,.base09)))
     `(font-lock-escape-face ((t :foreground ,.base0C)))
     `(font-lock-warning-face ((t :foreground ,.base09)))
     `(rainbow-delimiters-depth-7-face ((t :foreground ,.base0F)))
     ;; Headings, by level: Markdown's, Org's, outlines in code, and Typst's
     ;; (below).
     `(outline-1 ((t :foreground ,.base0D :weight bold)))
     `(outline-2 ((t :foreground ,.base0E :weight bold)))
     `(outline-3 ((t :foreground ,.base09 :weight bold)))
     `(outline-4 ((t :foreground ,.base0A :weight bold)))
     `(outline-5 ((t :foreground ,.base0B :weight bold)))
     `(outline-6 ((t :foreground ,.base0C :weight bold)))
     ;; Typst (nil: as the text around)
     '(typst-ts-error-face ((t :inherit error)))
     `(typst-ts-markup-strong-face ((t :foreground ,.base0A :weight bold)))
     `(typst-ts-markup-strong-indicator-face ((t :foreground ,.base0A :weight bold)))
     `(typst-ts-markup-emphasis-face ((t :foreground ,.base0E :slant italic)))
     `(typst-ts-markup-emphasis-indicator-face ((t :foreground ,.base0E :slant italic)))
     `(typst-ts-markup-item-indicator-face ((t :foreground ,.base0D)))
     `(typst-ts-markup-term-indicator-face ((t :foreground ,.base0D)))
     '(typst-ts-markup-term-description-face ((t nil)))
     '(typst-ts-markup-raw-indicator-face ((t nil)))
     `(typst-ts-markup-raw-blob-face ((t :foreground ,.base0B)))
     `(typst-ts-markup-label-face ((t :foreground ,.base0C)))
     `(typst-ts-markup-reference-face ((t :foreground ,.base0C)))
     `(typst-ts-markup-url-face ((t :foreground ,.base0C)))
     `(typst-ts-markup-quote-face ((t :foreground ,.base0C)))
     `(typst-ts-markup-escape-face ((t :foreground ,.base0C)))
     `(typst-ts-markup-linebreak-face ((t :foreground ,.base09)))
     `(typst-ts-shorthand-face ((t :foreground ,.base09)))
     '(typst-ts-code-indicator-face ((t nil)))
     '(typst-ts-math-indicator-face ((t nil)))
     '(typst-ts-script-char-face ((t nil)))
     ;; Diffs
     `(diff-removed ((t :foreground ,.base0E)))
     '(diff-indicator-removed ((t :inherit diff-removed)))
     `(diff-refine-removed ((t :foreground ,.base00 :background ,.base0E)))
     `(diff-hl-delete ((t :foreground ,.base0E)))
     `(magit-diff-added ((t :foreground ,.base0B :background ,.base01)))
     `(magit-diff-added-highlight ((t :foreground ,.base0B :background ,.base02)))
     `(magit-diff-removed ((t :foreground ,.base0E :background ,.base01)))
     `(magit-diff-removed-highlight ((t :foreground ,.base0E :background ,.base02)))
     `(magit-diffstat-removed ((t :foreground ,.base0E)))
     ;; Files (and buffers) flagged for deletion, programs, icons, the tree
     `(dired-flagged ((t :foreground ,.base0E :weight bold)))
     `(diredfl-deletion ((t :background ,.base0E)))
     `(diredfl-deletion-file-name ((t :background ,.base0E)))
     `(diredfl-exec-priv ((t :foreground ,.base0B)))
     `(diredfl-executable-tag ((t :foreground ,.base0B)))
     `(ibuffer-deletion ((t :foreground ,.base0E :weight bold)))
     `(nerd-icons-red ((t :foreground ,.base0E)))
     `(nerd-icons-lred ((t :foreground ,.base0E)))
     `(nerd-icons-dred ((t :foreground ,.base0E)))
     `(nerd-icons-red-alt ((t :foreground ,.base0E)))
     `(treemacs-nerd-icons-file-face ((t :foreground ,.base0D)))
     `(treemacs-nerd-icons-root-face ((t :foreground ,.base09)))
     `(treemacs-git-modified-face ((t :foreground ,.base09)))
     `(treemacs-marked-file-face ((t :foreground ,.base00 :background ,.base0E :weight bold)))
     ;; Around the text
     '(mode-line-buffer-id ((t :foreground unspecified)))
     '(doom-modeline-project-dir ((t :foreground unspecified)))
     `(show-paren-match ((t :foreground ,.base05 :background ,.base02 :weight bold)))
     `(corfu-current ((t :foreground ,.base01 :background ,.base04)))
     `(marginalia-off ((t :foreground ,.base03)))
     ;; Cursors as Helix and kitty draw them.
     `(cursor ((t :background ,.base05)))
     `(hel-normal-state-main-cursor ((t :background ,.base05)))
     `(hel-extend-selection-cursor ((t :background ,.base09)))
     `(hel-normal-state-fake-cursor ((t :foreground ,.base00 :background ,.base06)))
     `(hel-insert-state-fake-cursor ((t :foreground ,.base00 :background ,.base06))))
    ;; As a theme is enabled, before the colours here, Hel copies the cursor's
    ;; colour into its own for the windows to come, over any theme: base16's
    ;; red, which on the first frame of the Emacs that keeps running, a
    ;; terminal's, is "red". Every window opened then had a red cursor.
    (set-face-attribute 'hel-normal-state-main-cursor t :background .base05)))

(my-colors my-stylix-colors)
(add-hook 'my-look-palette-functions #'my-colors)

;; Typst's headings, and Markdown's, take the outline colours.
(dotimes (i 6)
  (let ((outline (intern (format "outline-%d" (1+ i)))))
    (dolist (face '("typst-ts-markup-header-face-%d"
                    "typst-ts-markup-header-indicator-face-%d"
                    "markdown-header-face-%d"))
      (custom-theme-set-faces
       'user `(,(intern (format face (1+ i))) ((t :inherit ,outline)))))))

(provide 'my-colors)
;;; my-colors.el ends here
