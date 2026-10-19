;;; my-spelling.el --- Spelling, in English and Hebrew  -*- lexical-binding: t -*-
;;; Commentary:
;;
;; Jinx checks the words of text (notes, Markdown, commit messages) as they
;; show, against Hunspell's US English and Hebrew dictionaries (notes.nix),
;; and underlines those neither has. ] s and [ s select the next and
;; previous one (with Vim's keys, go to them); z = corrects the ones
;; selected, else the nearest, and can save a word to your own dictionary;
;; SPC t S turns checking off and on in a buffer.
;;
;;; Code:

(require 'hel)
(require 'jinx)

(setopt jinx-languages "en_US he_IL"
        global-jinx-modes '(text-mode))

;; In Typst, code, math, raw text, labels, references and addresses aren't
;; prose.
(setf (alist-get 'typst-ts-mode jinx-exclude-faces)
      '(font-lock-builtin-face
        font-lock-constant-face
        font-lock-function-call-face
        font-lock-function-name-face
        font-lock-keyword-face
        font-lock-number-face
        font-lock-property-name-face
        font-lock-property-use-face
        font-lock-string-face
        font-lock-variable-name-face
        font-lock-variable-use-face
        typst-ts-markup-label-face
        typst-ts-markup-raw-blob-face
        typst-ts-markup-rawblock-blob-face
        typst-ts-markup-rawblock-lang-face
        typst-ts-markup-rawspan-blob-face
        typst-ts-markup-reference-face
        typst-ts-markup-url-face))

;; Nor is the code in raw blocks, which takes its language's faces.
(defun my-spelling--raw-block (start)
  "The end of the Typst raw block around START, to skip to; else nil."
  (when-let* ((block (treesit-parent-until
                      (treesit-node-at start)
                      (lambda (node) (equal (treesit-node-type node) "raw_blck"))
                      t)))
    (treesit-node-end block)))

(defun my-spelling--typst ()
  "Leave out the code in raw blocks."
  (add-hook 'jinx--predicates #'my-spelling--raw-block nil t))

(add-hook 'typst-ts-mode-hook #'my-spelling--typst)

;; Jinx needs its add-on, which Nix builds: on Windows there's no checking.
(when (and module-file-suffix
           (locate-file "jinx-mod" load-path (list module-file-suffix)))
  (global-jinx-mode))

(defun my-spelling-correct ()
  "Correct the misspelled words in the selection, else the nearest one."
  (interactive "*")
  (unless (and (use-region-p)
               (ignore-error user-error
                 (jinx--force-overlays (region-beginning) (region-end) :check t)))
    (deactivate-mark))
  (jinx-correct))

(defun my-spelling--next (next &optional n)
  "Select the Nth next misspelled word, as Hel's ] and [ motions select.
NEXT, Jinx's `jinx-next', goes to its end, and from before the first
one would skip that one."
  (if (minibufferp)
      (funcall next n)
    (let ((first (car (jinx--force-overlays (point-min) (point-max)))))
      (if (and (> (or n 1) 0) (< (point) (overlay-start first)))
          (goto-char (overlay-end first))
        (funcall next n))
      (when (and (bound-and-true-p hel-local-mode) hel-normal-state
                 (not hel--extend-selection))
        (when-let* ((word (car (jinx--get-overlays (1- (point)) (point)))))
          (hel-set-region (overlay-start word) (overlay-end word)))))))

(advice-add 'jinx-next :around #'my-spelling--next)

(keymap-global-set "<remap> <ispell-word>" #'my-spelling-correct)
(keymap-set mode-specific-map "t S" #'jinx-mode)
(hel-keymap-global-set :state 'normal
  "z =" #'my-spelling-correct
  "] s" #'jinx-next
  "[ s" #'jinx-previous)

(provide 'my-spelling)
;;; my-spelling.el ends here
