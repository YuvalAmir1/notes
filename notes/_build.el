;;; _build.el --- Prepare Helheim's user-lisp as Nix builds it  -*- lexical-binding: t -*-
;;; Commentary:
;;
;; What Emacs 31 does at each start when `user-lisp-auto-scrape' is on:
;; index the autoloads and byte-compile. Here it happens once, as the result
;; is read-only. Files of Helheim modules that aren't in use can fail to
;; compile, for want of their packages; ours mustn't.
;;
;;; Code:

(package-activate-all)
(setq helheim-package-manager 'nix)

(let* ((root (expand-file-name (pop command-line-args-left)))
       (dirs (cons root (seq-filter #'file-directory-p
                                    (directory-files-recursively root "" t))))
       failed)
  (dolist (dir dirs)
    (add-to-list 'load-path dir))
  (loaddefs-generate dirs (expand-file-name ".user-lisp-autoloads.el" root))
  (dolist (file (directory-files-recursively root "\\.el\\'"))
    (unless (or (string-suffix-p "autoloads.el" file)
                (with-demoted-errors "Compiling: %S"
                  (byte-compile-file file)))
      (push file failed)))
  (when-let* ((ours (seq-filter (lambda (file) (string-search "/my/" file))
                                failed)))
    (error "Failed to compile: %S" ours)))

;;; _build.el ends here
