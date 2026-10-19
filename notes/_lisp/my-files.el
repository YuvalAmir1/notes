;;; my-files.el --- A file tree, as VS Code's  -*- lexical-binding: t -*-
;;; Commentary:
;;
;; SPC e shows the files as a tree at the left of the frame, or hides it:
;; the notes folder from a note or the start page, a project's folder (one
;; Git keeps) from its files, else the file's own folder. A click opens a
;; file or a folder; so do l and Enter, h closes one, and j and k move. The
;; tree marks the file you're in; ? lists its keys for making, renaming and
;; deleting files.
;;
;;; Code:

(require 'my-notes)

(defvar treemacs--find-user-project-functions)
(defvar treemacs-mode-map)
(defvar treemacs-persist-file)
(declare-function tab-bar-tab-name-current "tab-bar")
(declare-function treemacs-current-visibility "treemacs-scope")
(declare-function treemacs-get-local-window "treemacs-scope")
(declare-function treemacs-load-theme "treemacs-themes")
(declare-function treemacs-next-line "treemacs-interface")
(declare-function treemacs-previous-line "treemacs-interface")

(defun my-files--notes ()
  "The notes folder, from a note or the start page."
  (and (or (derived-mode-p 'dashboard-mode)
           (file-in-directory-p default-directory my-notes-directory))
       my-notes-directory))

;; The tree shows one folder, picked again each time: none to remember.
(setq treemacs-persist-file nil)

(with-eval-after-load 'treemacs
  (require 'treemacs-nerd-icons)
  (treemacs-load-theme "nerd-icons")
  ;; Before a project's folder, and the file's.
  (add-to-list 'treemacs--find-user-project-functions #'my-files--notes)
  (keymap-set treemacs-mode-map "j" #'treemacs-next-line)
  (keymap-set treemacs-mode-map "k" #'treemacs-previous-line)
  (keymap-set treemacs-mode-map "<mouse-1>" #'treemacs-single-click-expand-action))

(defun my-files-tree ()
  "Show the tree of the files around this one, or hide it."
  (interactive)
  (if (and (featurep 'treemacs) (eq (treemacs-current-visibility) 'visible))
      (delete-window (treemacs-get-local-window))
    (treemacs-add-and-display-current-project-exclusively)))

(keymap-set mode-specific-map "e" #'my-files-tree)

;; While the tree has the focus, the tab keeps the name of the file beside it.
(defun my-files--tab-name ()
  "Name the tab after the selected window's buffer, or the file beside the tree."
  (if (window-parameter (selected-window) 'window-side)
      (buffer-name (window-buffer (get-mru-window nil nil t)))
    (tab-bar-tab-name-current)))

(setopt tab-bar-tab-name-function #'my-files--tab-name)

(provide 'my-files)
;;; my-files.el ends here
