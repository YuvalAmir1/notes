;;; my-hel.el --- Hel's cursor and keys, as in Helix  -*- lexical-binding: t -*-
;;; Commentary:
;;
;; SPC w saves and SPC q closes the window, as your Helix has them
;; (modules/base/helix.nix); Hel's window keys stay on C-w.
;;
;; Hel's normal-state cursor is a line between two characters. Here it's a
;; block on the character after that line, as Helix draws it (with a line
;; while typing, and underlined while v extends a selection). With nothing
;; selected, the commands that acted on the character before the line act
;; on the one under the block: d deletes it, c changes it, r replaces it,
;; and a and p go after it. With a selection they act on the selection, as
;; before. The mode line starts with the state, as Helix shows its mode:
;; NOR, INS, or SEL while v extends (with Vim's keys, VIS in visual state).
;;
;;; Code:

(require 'doom-modeline)
(require 'hel)

(setopt hel-insert-state-cursor-type 'bar)

(setcar (hel-state-property 'normal :cursor)
        (lambda () (if hel--extend-selection 'hbar 'box)))

(defun my-hel--delete-a (fn count)
  "Have FN delete COUNT characters from the cursor on if nothing is selected."
  (funcall fn (if (use-region-p) count (- count))))

(defun my-hel--replace-a (fn count)
  "With a selection run FN, else replace COUNT characters from the cursor on."
  (if (use-region-p)
      (funcall fn count)
    (hel-read-char-and-replace (point) (min (point-max) (+ (point) count)))))

(defun my-hel--change-a (fn)
  "With a selection run FN, else change the character under each cursor.
At the end of a line there's none: typing starts there."
  (if (use-region-p)
      (funcall fn)
    (hel-with-each-cursor
      (unless (use-region-p)
        (cond ((not (eolp)) (delete-char 1))
              ((bolp) (indent-according-to-mode)))))
    (hel-insert-state 1)))

(defun my-hel--append-a (fn)
  "Run FN past the character under each cursor if nothing is selected."
  (hel-with-each-cursor
    (unless (or (use-region-p) (eolp))
      (forward-char)))
  (funcall fn))

(defun my-hel--paste-a (fn &rest args)
  "Run FN past the character under the cursor if nothing is selected."
  (unless (or (use-region-p) (eolp))
    (forward-char))
  (apply fn args))

(advice-add 'hel-cut :around #'my-hel--delete-a)
(advice-add 'hel-replace-char :around #'my-hel--replace-a)
(advice-add 'hel-change :around #'my-hel--change-a)
(advice-add 'hel-append :around #'my-hel--append-a)
(advice-add 'hel-paste-after :around #'my-hel--paste-a)

;;;; Saving and closing

(defun my-hel-close ()
  "Close this window, as Helix's :q closes a view. The last one closes the
frame, as C-x C-c does, which asks first about files not saved."
  (interactive)
  (condition-case nil
      (delete-window)
    (error (save-buffers-kill-terminal))))

;; Once, however many cursors there are.
(put 'my-hel-close 'multiple-cursors nil)

(keymap-set mode-specific-map "w" #'save-buffer)
(keymap-set mode-specific-map "q" #'my-hel-close)

;;;; The mode line

(defvar evil-state)

;; Its own way of showing Evil's state would show it twice (my-vim.el).
(setopt doom-modeline-modal nil)

(doom-modeline-def-segment hel-state
  "The state, Hel's or Evil's, in the selected window."
  (when (doom-modeline--active)
    (cond ((bound-and-true-p evil-local-mode)
           (pcase evil-state
             ((or 'normal 'operator) "NOR  ")
             ('insert "INS  ")
             ('visual "VIS  ")
             ('replace "REP  ")))
          (hel-local-mode
           (pcase hel-state
             ('insert "INS  ")
             ('normal (if hel--extend-selection "SEL  " "NOR  ")))))))

(doom-modeline-add-segment 'hel-state 'bar)

(provide 'my-hel)
;;; my-hel.el ends here
