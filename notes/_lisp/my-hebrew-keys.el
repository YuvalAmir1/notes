;;; my-hebrew-keys.el --- Commands from a Hebrew layout  -*- lexical-binding: t -*-
;;; Commentary:
;;
;; With a Hebrew layout on, keys still give commands, as the Latin layout's
;; keys in the same places would: keys held with Ctrl, Alt or Super
;; everywhere, and plain keys where keys are commands (Hel's normal state,
;; or Evil's normal and visual states and the motion after an operator,
;; read-only buffers such as Magit's and Dired's, Space's menu, and after a
;; prefix such as C-x). Text typed in insert state, and the character a
;; command asks for (f, t, r and the like), stay Hebrew; where a mode says
;; the text is Latin by nature, as Typst's math, code, labels and references
;; are (my-typst.el), keys type the Latin layout's characters there too.
;;
;; The add-on my-keyboard (_keyboard/my-keyboard.c) asks the system which
;; layout a key came from and what the same key types in the Latin layout,
;; whichever that is (QWERTY, Dvorak, Colemak...): nothing is set up for a
;; layout, on Wayland, X11, Windows or macOS.
;;
;;; Code:

(defvar hel-state)
(defvar evil-state)
(declare-function my-keyboard-latin "my-keyboard")
(declare-function my-keyboard-start "my-keyboard")

(defvar my-hebrew--in-leader nil
  "Non-nil while Hel's Space menu reads keys.")

(defvar pgtk-keysym-table)

;; Held with Ctrl, Alt or Super, a Hebrew letter would reach Emacs as its
;; keysym's name (C-hebrew_kuf) rather than as the letter (C-ק).
(when (boundp 'pgtk-keysym-table)
  (dotimes (i 27)
    (puthash (+ #xce0 i) (+ #x5d0 i) pgtk-keysym-table)))

(defconst my-hebrew--chars
  (append (number-sequence ?! ?~) (number-sequence ?א ?ת))
  "The characters a key may type in a Hebrew layout: Hebrew letters, and
what Latin layouts type, which a Hebrew one can put on other keys.")

(defconst my-hebrew--modifiers
  '(nil (control) (meta) (super) (control meta) (control super) (meta super)
        (control meta super))
  "The modifiers a key is translated with; nil is the plain key.")

(defun my-hebrew--after-prefix-p (event)
  "Return non-nil if EVENT, being read, follows other keys of its sequence.
While the first key of a sequence is translated, the keys read so far are
that key; while a later one is, the keys before it."
  (not (equal (this-command-keys-vector) (vector event))))

(defun my-hebrew--state ()
  "The state keys are read in, Evil's or Hel's: `normal', `insert' or nil."
  (cond ((bound-and-true-p evil-local-mode)
         (pcase evil-state
           ((or 'normal 'visual 'motion 'operator) 'normal)
           ((or 'insert 'replace) 'insert)))
        ((bound-and-true-p hel-local-mode)
         (pcase hel-state
           ('normal 'normal)
           ('insert 'insert)))))

(defun my-hebrew--commanding-p (event)
  "Return non-nil if EVENT, a plain key being read, is a command: also a
motion Evil reads for an operator (d w)."
  (and (or my-hebrew--in-leader
           (null this-command)
           (eq (bound-and-true-p evil-state) 'operator))
       (or (my-hebrew--after-prefix-p event)
           (and (not (minibufferp))
                (pcase (my-hebrew--state)
                  ('normal t)
                  ('insert nil)
                  (_ buffer-read-only))))))

(defvar-local my-hebrew-latin-function nil
  "A function that says whether a key typed at the cursor types the Latin
layout's character, which it's given, or nil.")

(defun my-hebrew--latin-p (event latin)
  "Return non-nil if EVENT, a plain key being read, types LATIN instead."
  (and (null this-command)
       (not (my-hebrew--after-prefix-p event))
       (eq (my-hebrew--state) 'insert)
       (not (minibufferp))
       my-hebrew-latin-function
       (ignore-errors (funcall my-hebrew-latin-function latin))))

(defun my-hebrew--key (modifiers char)
  "CHAR with MODIFIERS, as Emacs reads it from the keyboard."
  (if (and (memq 'control modifiers) (<= ?A char ?Z))
      (event-convert-list (append modifiers (list 'shift (downcase char))))
    (event-convert-list (append modifiers (list char)))))

(defun my-hebrew--translation (char modifiers)
  "The `key-translation-map' entry for CHAR typed with MODIFIERS."
  (let ((event (my-hebrew--key modifiers char)))
    (lambda (_prompt)
      (let ((latin (ignore-errors (my-keyboard-latin char))))
        (vector (if (and latin (or modifiers
                                   (my-hebrew--commanding-p event)
                                   (my-hebrew--latin-p event latin)))
                    (my-hebrew--key modifiers latin)
                  event))))))

(defun my-hebrew--start (&optional frame)
  "Follow the keyboard of FRAME, if it's graphical."
  (when (display-graphic-p frame)
    (ignore-errors
      (my-keyboard-start (symbol-name (window-system frame))
                         (frame-parameter frame 'display)))))

(when (require 'my-keyboard nil t)
  (dolist (char my-hebrew--chars)
    (dolist (modifiers my-hebrew--modifiers)
      (let* ((key (vector (my-hebrew--key modifiers char)))
             (code (logand (aref key 0) #x3fffff)))
        ;; Ctrl with a letter is a control character, which every layout's
        ;; letter gives; Ctrl with [ is ESC, which the Escape key gives too.
        (unless (or (< code 32) (= code 127) (lookup-key key-translation-map key))
          (define-key key-translation-map key (my-hebrew--translation char modifiers))))))
  (add-hook 'after-make-frame-functions #'my-hebrew--start)
  (my-hebrew--start))

(defun my-hebrew--in-leader-a (fn &rest args)
  "Let FN, Hel's Space menu, read Hebrew keys as commands."
  (let ((my-hebrew--in-leader t))
    (apply fn args)))

(with-eval-after-load 'hel-leader
  (advice-add 'hel-leader-start :around #'my-hebrew--in-leader-a))

(provide 'my-hebrew-keys)
;;; my-hebrew-keys.el ends here
