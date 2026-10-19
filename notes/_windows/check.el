;;; check.el --- Whether the Windows copy works  -*- lexical-binding: t -*-
;;; Commentary:
;;
;; For GitHub (.github/workflows/notes.yml), after install.ps1:
;; emacs.exe --batch -l check.el starts the copy as its shortcut would, then
;; checks the add-on, the grammar, the theme, the templates and the programs,
;; and that a note made from a template compiles, with one of Typst's
;; libraries from the folder. It exits with 1 if not.
;;
;;; Code:

(let* ((config (expand-file-name "Notes/config/" (getenv "LOCALAPPDATA")))
       (note (expand-file-name "check.typ" temporary-file-directory))
       failed)
  (setq user-init-file (expand-file-name "init.el" config))
  (load (expand-file-name "early-init.el" config) nil t)
  (prepare-user-lisp t)
  (load user-init-file nil t)
  (pcase-dolist (`(,name . ,ok)
                 `((keyboard . ,(fboundp 'my-keyboard-latin))
                   (grammar . ,(treesit-language-available-p 'typst))
                   (theme . ,(memq 'base16-stylix custom-enabled-themes))
                   (templates . ,(file-exists-p
                                  (expand-file-name "templates/note.typ" my-notes-directory)))
                   (typst . ,(executable-find "typst"))
                   (tinymist . ,(executable-find "tinymist"))
                   (rg . ,(executable-find "rg"))
                   (fd . ,(executable-find "fd"))))
    (unless ok (push name failed)))
  (with-temp-file note
    (insert "#import \"@local/notes:0.1.0\": note\n"
            (nth 2 (assoc "physica" my-typst-libraries)) "\n"
            "#show: note.with(title: \"בדיקה\", date: \"2026-01-01\")\n\n"
            "שלום, world. $dv(f, x)$\n"))
  ;; The library from the folder, not from the web.
  (let ((cache (make-temp-file "typst-cache" t)))
    (setenv "TYPST_PACKAGE_CACHE_PATH" cache)
    (with-temp-buffer
      (let ((status (condition-case err
                        (call-process "typst" nil t nil "compile" note)
                      (error err))))
        (unless (eq status 0)
          (push (list 'compile status (buffer-string)) failed))))
    (when (directory-files cache nil "\\`[^.]")
      (push 'library-downloaded failed)))
  (princ (if failed (format "Failed: %S\n" failed) "All well.\n"))
  (kill-emacs (if failed 1 0)))

;;; check.el ends here
