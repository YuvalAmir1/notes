;;; early-init.el --- Helheim's, and where Emacs keeps its files  -*- lexical-binding: t; no-byte-compile: t -*-
;;; Commentary:
;;
;; Emacs starts from the folder this file is in (_package.nix makes it),
;; with Helheim in helheim/ and Jinx's dictionaries in enchant/. A copy
;; others install (_friends.nix) also has what your machines get from Nix
;; and Home Manager: Typst's notes package and fonts, and on Windows the
;; packages, the Typst grammar and the programs.
;;
;;; Code:

(defconst my-root (file-name-directory load-file-name)
  "The folder Emacs starts from.")

(defun my-root-file (name)
  "NAME in or beside the folder Emacs starts from, if it's there."
  (let ((file (expand-file-name name my-root)))
    (and (file-exists-p file) file)))

(defun my-xdg (variable default)
  "The folder the XDG VARIABLE names, else DEFAULT."
  (let ((dir (getenv variable)))
    (if (and dir (file-name-absolute-p dir)) dir default)))

(load (expand-file-name "helheim/early-init.el" my-root) nil t)

;; Helheim keeps Emacs's own files (history, caches) in its folder, which
;; Nix builds read-only: they go here instead.
(setq user-emacs-directory
      (file-name-as-directory
       (pcase system-type
         ('windows-nt (expand-file-name "Notes" (getenv "APPDATA")))
         ('darwin (expand-file-name "~/Library/Application Support/Notes"))
         (_ (expand-file-name "emacs" (my-xdg "XDG_STATE_HOME" "~/.local/state")))))
      package-user-dir (locate-user-emacs-file "elpa/"))
(when (native-comp-available-p)
  (startup-redirect-eln-cache (locate-user-emacs-file "eln-cache/")))

(defvar my-snippets-directory (locate-user-emacs-file "snippets/")
  "Where SPC i n saves your own snippets (_init.el).")

;; Jinx's dictionaries, linked into the folder Enchant reads them from and
;; keeps your words in. Enchant runs inside Emacs, which `setenv' doesn't
;; reach.
(when-let* ((enchant (my-root-file "enchant")))
  (let ((dir (expand-file-name "enchant" (my-xdg "XDG_CONFIG_HOME" "~/.config"))))
    (make-directory dir t)
    (dolist (name (directory-files enchant nil "\\`[^.]"))
      (let ((link (expand-file-name name dir))
            (target (expand-file-name name enchant)))
        (unless (or (equal (file-symlink-p link) target)
                    (and (file-exists-p link) (not (file-symlink-p link))))
          (make-symbolic-link target link t))))))

;;;; A copy others install

;; Typst's notes package and fonts, for the preview and the language server.
(when-let* ((packages (my-root-file "typst-packages")))
  (setenv "TYPST_PACKAGE_PATH" packages))
(when-let* ((fonts (my-root-file "fonts")))
  (setenv "TYPST_FONT_PATHS" fonts))

;; Without Nix: the packages, the grammars and the programs.
(when-let* ((site (my-root-file "site-lisp")))
  (push site load-path)
  (setq package-directory-list (list (expand-file-name "elpa" site))))
(when-let* ((grammars (my-root-file "tree-sitter")))
  (setq treesit-extra-load-path (list grammars)))
(when-let* ((bin (my-root-file "../bin")))
  (push bin exec-path)
  (setenv "PATH" (concat bin path-separator (getenv "PATH"))))

;;; early-init.el ends here
