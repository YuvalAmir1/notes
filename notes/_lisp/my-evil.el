;;; my-evil.el --- Vim's keys, set up  -*- lexical-binding: t -*-
;;; Commentary:
;;
;; Loaded when Vim's keys are chosen (my-vim.el): Evil, evil-collection's
;; Vim keys for Dired, Magit, help, the start page and the rest, and this
;; setup's own keys as they are with Helix's: SPC's menu (with SPC w and
;; SPC q; :w and :q are Vim's), commands from a Hebrew layout
;; (my-hebrew-keys.el), typing math (my-typst.el), ] s, [ s and z = for
;; spelling, ] d and [ d for errors, gf following a note's links
;; (my-notes.el), h and l by the screen, Vim's keys in the file tree, and
;; the cursors in the palette's colours. The mode line starts with the state
;; (my-hel.el).
;;
;;; Code:

(require 'evil)
(require 'evil-collection)
(require 'hel-leader)
(require 'my-look)
(require 'my-notes)
(require 'my-spelling)
(require 'my-typst)

(declare-function flymake-goto-next-error "flymake")
(declare-function flymake-goto-prev-error "flymake")
(defvar dashboard-mode-map)
(defvar typst-ts-mode-map)

(evil-collection-init)

;; SPC's menu, as with Helix's keys.
(evil-define-key* '(normal visual motion) 'global (kbd "SPC") #'hel-leader)

;; The start page's n, for new notes, as its r is evil-collection's.
(defun my-evil--start-page (&rest _)
  "Keep the start page's n for its templates."
  (evil-define-key* 'normal dashboard-mode-map "n" (lookup-key dashboard-mode-map "n")))

(advice-add 'dashboard-insert-startupify-lists :after #'my-evil--start-page)
(when (boundp 'dashboard-mode-map)
  (my-evil--start-page))

;;;; Spelling

(evil-define-key* '(normal motion) 'global
  (kbd "z =") #'my-spelling-correct
  (kbd "] s") #'jinx-next
  (kbd "[ s") #'jinx-previous)

;;;; Errors, and following links (my-notes.el)

(evil-define-key* '(normal motion) 'global
  (kbd "] d") #'flymake-goto-next-error
  (kbd "[ d") #'flymake-goto-prev-error)

(with-eval-after-load 'typst-ts-mode
  (evil-define-key* 'normal typst-ts-mode-map "gf" #'my-notes-follow))

;;;; Left and right by the screen, in Hebrew lines too (my-bidi.el)

(evil-define-motion my-evil-left (count)
  "Move COUNT characters left on the screen."
  :type exclusive
  (left-char (or count 1)))

(evil-define-motion my-evil-right (count)
  "Move COUNT characters right on the screen."
  :type exclusive
  (right-char (or count 1)))

(evil-define-key* '(normal visual) 'global
  "h" #'my-evil-left
  "l" #'my-evil-right
  (kbd "<left>") #'my-evil-left
  (kbd "<right>") #'my-evil-right)

;;;; Typing math

(with-eval-after-load 'typst-ts-mode
  (evil-define-key* 'insert typst-ts-mode-map
    "$" #'my-typst-dollar
    "(" #'my-typst-open "[" #'my-typst-open "{" #'my-typst-open
    ")" #'my-typst-close "]" #'my-typst-close "}" #'my-typst-close
    "\"" #'my-typst-mark "*" #'my-typst-mark "_" #'my-typst-mark "`" #'my-typst-mark
    (kbd "DEL") #'my-typst-delete-backward-char
    (kbd "S-<return>") #'my-typst-newline))

;;;; The file tree

(with-eval-after-load 'treemacs
  (require 'treemacs-evil))

;;;; The cursors, as Helix's and kitty's

(defun my-evil--cursors (colors)
  "Shape Evil's cursors as Helix's, in COLORS, an alist by base16 name."
  (let-alist colors
    (setq evil-normal-state-cursor `(box ,.base05)
          evil-motion-state-cursor `(box ,.base05)
          evil-visual-state-cursor `(box ,.base09)
          evil-insert-state-cursor `(bar ,.base05)
          evil-replace-state-cursor `(hbar ,.base05)
          evil-operator-state-cursor `(hbar ,.base05)
          evil-emacs-state-cursor `(bar ,.base05)))
  (when (bound-and-true-p evil-local-mode)
    (evil-refresh-cursor)))

(my-evil--cursors my-stylix-colors)
(add-hook 'my-look-palette-functions #'my-evil--cursors)

(provide 'my-evil)
;;; my-evil.el ends here
