;;; my-vim.el --- Helix's keys or Vim's  -*- lexical-binding: t -*-
;;; Commentary:
;;
;; Keys are Helix's (Hel, as Helheim sets it up) or Vim's (Evil, with
;; my-evil.el), as `my-keys' says. A copy others install asks once, at its
;; first start; SPC t k switches at any time, and Emacs keeps the choice.
;;
;;; Code:

(declare-function evil-mode "evil-core")
(declare-function hel-mode "hel-core")

(defcustom my-keys nil
  "The keys to edit with: `helix' (Hel's) or `vim' (Evil's); nil asks."
  :type '(choice (const :tag "Ask" nil)
                 (const :tag "Helix's" helix)
                 (const :tag "Vim's" vim))
  :group 'convenience)

;; Evil reads these as it loads.
(defvar evil-want-keybinding)
(defvar evil-want-C-u-scroll)
(defvar evil-want-Y-yank-to-eol)
(defvar evil-undo-system)
(defvar evil-respect-visual-line-mode)
(defvar evil-collection-key-blacklist)
(setq evil-want-keybinding nil
      evil-want-C-u-scroll t
      evil-want-Y-yank-to-eol t
      evil-undo-system 'undo-redo
      evil-respect-visual-line-mode t
      ;; SPC is the menu's, as with Helix's keys (my-evil.el).
      evil-collection-key-blacklist '("SPC"))

(defun my-keys-current ()
  "The keys in use: `helix' or `vim'."
  (if (bound-and-true-p evil-mode) 'vim 'helix))

(defun my-keys-use (keys)
  "Edit with KEYS, `helix' or `vim'."
  (if (eq keys 'vim)
      (progn
        (require 'my-evil)
        (hel-mode -1)
        (evil-mode 1))
    (when (bound-and-true-p evil-mode)
      (evil-mode -1))
    (hel-mode 1)))

(defun my-keys-switch ()
  "Switch between Helix's keys and Vim's, for now and later."
  (interactive)
  (let ((keys (if (eq (my-keys-current) 'vim) 'helix 'vim)))
    (my-keys-use keys)
    (customize-save-variable 'my-keys keys)
    (message "%s's keys" (if (eq keys 'vim) "Vim" "Helix"))))

(keymap-set mode-specific-map "t k" #'my-keys-switch)

(defun my-keys--ask ()
  "Ask once which keys to edit with."
  (unless (or my-keys noninteractive (daemonp))
    (condition-case nil
        (let ((keys (if (eq (car (read-multiple-choice
                                  "Edit with Helix's keys or Vim's? SPC t k switches later"
                                  '((?h "helix" "Helix's keys: select, then act")
                                    (?v "vim" "Vim's keys: act, then move"))))
                            ?v)
                        'vim
                      'helix)))
          (customize-save-variable 'my-keys keys)
          (when (eq keys 'vim)
            (my-keys-use 'vim)))
      (quit nil))))

;; The choice saved (custom.el) is there after init.
(add-hook 'after-init-hook
          (lambda ()
            (when (eq my-keys 'vim)
              (my-keys-use 'vim)))
          90)
(add-hook 'emacs-startup-hook
          (lambda () (run-with-idle-timer 0.5 nil #'my-keys--ask)))

(provide 'my-vim)
;;; my-vim.el ends here
