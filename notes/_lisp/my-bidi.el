;;; my-bidi.el --- Hebrew and English in the same text  -*- lexical-binding: t -*-
;;; Commentary:
;;
;; Emacs lays out each paragraph in the direction of its first letter, or
;; of a direction mark at its start (SPC t f puts one there, below).
;; Helheim fixes every paragraph left to right instead, for speed; this
;; undoes that, and tells Emacs where paragraphs start, so that all the
;; lines of one run the same way.
;;
;; In Typst files that's where Typst starts them, as checked against
;; Typst's own layout: after a blank line; at and after a heading, an
;; equation, a raw block, a figure, a table or another block; and at a
;; list, which goes the way of its first item, all of it, as notes lay it
;; out (_typst/notes.typ). An equation set apart on lines of its own after
;; text (text $, its lines, $) starts a paragraph too, and so does the line
;; after it. Comments and code that shows nothing go with the paragraph
;; around them. Typst finds a paragraph's first letter past math or code at
;; its start ($x$ and #emph[...]), and starts one after an equation's last
;; dollar on its line; Emacs takes the direction from the math or the code,
;; and starts paragraphs only at lines.
;;
;; Content in brackets over several lines (a box's, a table's cell) goes
;; with the call's line, as Typst lays one paragraph alone there as text, in
;; its own direction, left to right. Holding more (a blank line, a heading,
;; a list, a raw block, an equation or a block), it's paragraphs, which
;; start as anywhere else. A call alone on its line that starts a paragraph
;; is taken for a block of its own (but Typst's emph, link and the like):
;; the next line starts one, and so does the first of its content's
;; paragraphs, unless the call is to one of theorion's environments, which
;; start it with their name (Theorem 1.).
;;
;; In other text a paragraph starts after a blank line, and at a line that
;; starts with anything but a letter, a digit or a space (a heading, a list
;; item, a line of code), or with an indented list item.
;;
;; Math between dollars runs left to right. Left and right (arrows, and h
;; and l in Hel's normal state) move by the screen, whichever way the text
;; under the cursor runs.
;;
;;; Code:

(setq-default bidi-display-reordering t
              bidi-paragraph-direction nil)
(setq bidi-inhibit-bpa nil)

;; Typst's math runs left to right. Emacs took $ for a currency sign, which
;; goes with a number after it, so in a Hebrew line $5a = b$ showed as
;; $$5a = b; as a left-to-right letter, each $ stays at its end of the math.
(put-char-code-property ?$ 'bidi-class 'L)

(defun my-bidi-paragraphs ()
  "Start text paragraphs at blank lines and at lines that start with a mark."
  ;; Emacs works a direction out again only before a line where the first
  ;; regexp matches without taking a character (`\\B': a line that doesn't
  ;; start with a letter or a digit), from the first letter after the
  ;; nearest line above that the second one matches.
  (setq bidi-paragraph-separate-re "^\\B"
        bidi-paragraph-start-re
        (rx bol (or (seq (* blank) eol)
                    (not (any space word))
                    (seq (+ blank)
                         (or (any "-+/") (seq (+ digit) "."))
                         (or blank eol))))))

(add-hook 'text-mode-hook #'my-bidi-paragraphs)

;;;; Typst's paragraphs

;; In Typst files Emacs starts a paragraph only at a line marked here, as
;; one where Typst starts a paragraph, a heading, a list or another block:
;; its line break gets a space's syntax rather than a comment's end, or,
;; when a comment on the line needs that, a punctuation mark on it gets an
;; expression prefix's. Every line works its direction out again, from the
;; first letter of the marked line at or above it.

(defconst my-bidi--item
  (rx bol (* blank) (group (or (any "-+/") (seq (+ digit) "."))) (or blank eol))
  "A Typst list item; group 1 is its marker.")

(defconst my-bidi--aside
  (rx bol (* blank)
      (or "//" "/*"
          (seq "#" (or "let" "set" "show" "import" "include") symbol-end)
          (seq "<" (+ (not (any ">\n"))) ">" (* blank) eol)))
  "A line Typst shows nothing of: a comment, code that sets things, a label.")

(defconst my-bidi--block-call
  (rx "#" (or (seq (or "align" "block" "circle" "colbreak" "columns"
                       "ellipse" "figure" "grid" "image" "line"
                       "outline" "pad" "pagebreak" "parbreak" "place"
                       "polygon" "rect" "square" "stack" "table" "v")
                   symbol-end)
              (seq "quote(" (* (not (any ")\n"))) "block: true")))
  "Code that puts a figure, a table, space and the like between paragraphs.")

(defconst my-bidi--block
  (rx bol (* blank)
      (or (seq (+ "=") blank)
          (seq "$" (or blank eol))
          (seq "```" (* (not (any "`\n"))) eol)
          (regexp my-bidi--block-call)))
  "A line that starts a block of its own: a heading, an equation, a raw
block, or code that puts one between paragraphs.")

(defconst my-bidi--inline-call
  (rx bol (* blank) "#"
      (or "box" "cite" "emph" "footnote" "h" "highlight" "link" "lower"
          "overline" "raw" "ref" "smallcaps" "strike" "strong" "sub" "super"
          "text" "underline" "upper")
      symbol-end)
  "A line that starts with a call to one of Typst's functions that show
their content within the line.")

(defconst my-bidi--named
  (rx bol (* blank) "#"
      (or "theorem" "lemma" "corollary" "proposition" "conjecture"
          "definition" "axiom" "postulate" "assumption" "property" "remark"
          "note" "example" "exercise" "problem" "proof" "solution"
          "conclusion")
      symbol-end)
  "A call to one of theorion's environments, whose first paragraph starts
with the environment's name and number.")

(defun my-bidi--kind ()
  "The kind of list whose item the last `looking-at' found."
  (pcase (char-after (match-beginning 1)) (?- 'list) (?/ 'terms) (_ 'enum)))

(defvar my-bidi--math-query nil
  "A query for Typst's math, compiled when first used.")

(defun my-bidi--set-apart-p (node)
  "Whether NODE, math, is in the text with spaces inside both its dollars,
which Typst sets apart from the text (content in brackets is text too); in
code it shows where code puts it."
  (let ((start (treesit-node-start node))
        (end (treesit-node-end node))
        (code node))
    (while (and (setq code (treesit-node-parent code))
                (not (member (treesit-node-type code) '("code" "content")))))
    (and (not (equal (treesit-node-type code) "code"))
         (memq (char-after (1+ start)) '(?\s ?\t ?\n))
         (memq (char-before (1- end)) '(?\s ?\t ?\n)))))

(defun my-bidi--equations ()
  "The math that runs over more than a line, or is set apart at a line's end
(a label or a comment after it), as (START END SET-APART), in order."
  (let (equations)
    (dolist (capture (treesit-query-capture
                      'typst (or my-bidi--math-query
                                 (setq my-bidi--math-query
                                       (treesit-query-compile 'typst '((math) @math))))))
      (let* ((node (cdr capture))
             (start (treesit-node-start node))
             (end (treesit-node-end node))
             (apart (my-bidi--set-apart-p node)))
        (when (save-excursion
                (goto-char start)
                (or (< (pos-eol) end)
                    (and apart
                         (progn (goto-char end)
                                (looking-at-p
                                 "[ \t]*\\(?:<[^>\n]*>[ \t]*\\)?\\(?://.*\\)?$")))))
          (push (list start end apart) equations))))
    (nreverse equations)))

(defun my-bidi--paragraphs-p (open)
  "Whether the content that the bracket at OPEN opens is paragraphs to
Typst: a blank line, a heading, a list, a raw block, an equation set apart or
a block in it. Otherwise Typst lays it out as text, not as a paragraph."
  (let ((content (treesit-node-parent (treesit-node-at open 'typst))))
    (and (equal (treesit-node-type content) "content")
         (seq-some (lambda (child)
                     (pcase (treesit-node-type child)
                       ((or "parbreak" "section" "heading" "item" "term" "raw_blck") t)
                       ("math" (my-bidi--set-apart-p child))
                       ("code" (save-excursion
                                 (goto-char (treesit-node-start child))
                                 (looking-at-p my-bidi--block-call)))))
                   (treesit-node-children content)))))

(defun my-bidi--alone-p ()
  "Whether the code at the start of the line at point ends its line, there
or on a line below, but for a comment."
  (when-let* ((node (treesit-parent-until
                     (treesit-node-at (save-excursion (skip-chars-forward " \t") (point))
                                      'typst)
                     (lambda (node) (equal (treesit-node-type node) "code"))
                     t)))
    (save-excursion
      (goto-char (treesit-node-end node))
      (looking-at-p "[ \t]*\\(?://.*\\)?$"))))

(defun my-bidi--named-p ()
  "Whether the line at point calls one of theorion's environments, in a
file that imports theorion."
  (and (looking-at-p my-bidi--named)
       (save-excursion
         (goto-char (point-min))
         (search-forward "\"@preview/theorion:" nil t))))

(defvar my-bidi--found nil
  "The positions to mark found so far, the last first.")

(defvar my-bidi--math nil
  "The math that spans lines, ahead of those being read (`my-bidi--equations').")

(defvar my-bidi--content-query nil
  "A query for Typst's content in brackets, compiled when first used.")

(defun my-bidi--content (open close first)
  "Find the paragraphs of the content from OPEN, its bracket, to CLOSE.
With FIRST, the first starts one, if it starts a line of its own."
  (save-excursion
    (goto-char (1+ open))
    (let ((own (looking-at-p "[ \t]*\\(?://.*\\)?$")))
      (forward-line 1)
      (my-bidi--lines close (not (and first own))))))

(defun my-bidi--contents (open close)
  "Find the paragraphs of the content that code's arguments, from OPEN to
CLOSE, hold over several lines, as a table's cells: each its own block."
  (let ((pos open))
    (dolist (capture (and (save-excursion
                            (goto-char open)
                            ;; Content that goes on past a line's end.
                            (re-search-forward "\\[[^]\n]*\n" close t))
                          (treesit-query-capture
                           'typst (or my-bidi--content-query
                                      (setq my-bidi--content-query
                                            (treesit-query-compile
                                             'typst '((content) @content))))
                           open close)))
      (let ((start (treesit-node-start (cdr capture)))
            (end (treesit-node-end (cdr capture))))
        (when (and (>= start pos) (<= end close) (my-bidi--paragraphs-p start))
          (my-bidi--content start end t)
          (setq pos end))))))

(defun my-bidi--past (&optional block)
  "Move to the last line of what the line at point starts, if it goes on:
a raw block, or code with a bracket left open. With BLOCK, the code shows
where it is: `t' for a block of its own, else `inline'. Its content's
paragraphs, and those of content in its arguments (a table's cells), are
then found on the way; a block's first one starts one, but in theorion's
environments."
  (cond ((and (looking-at-p "[ \t]*```") (not (looking-at-p "[ \t]*```.*```")))
         (forward-line 1)
         (while (not (or (eobp) (looking-at-p "[ \t]*```")))
           (forward-line 1)))
        ((looking-at-p "[ \t]*#")
         ;; Arguments and then content, as #tip(title: …)[…], can each
         ;; leave a line.
         (let ((first (and (eq block t) (not (my-bidi--named-p))))
               (from (point)))
           (while-let ((open (save-excursion
                               (car (nth 9 (parse-partial-sexp from (pos-eol))))))
                       (close (ignore-errors (scan-lists open 1 0))))
             (cond ((not block))
                   ((/= (char-after open) ?\[)
                    (my-bidi--contents open close))
                   ((my-bidi--paragraphs-p open)
                    (my-bidi--content open close first)))
             (goto-char close)
             (setq from close))
           (forward-line 0)))))

(defun my-bidi--mark-position ()
  "Where to mark the line at point as a paragraph's start: its line break,
unless a comment on the line ends there; else its first punctuation (or a
symbol's character) other than a slash or an apostrophe."
  (save-excursion
    (let ((eol (pos-eol)))
      (if (and (< eol (point-max))
               (not (search-forward "//" eol t)))
          eol
        (forward-line 0)
        (while (and (progn (skip-syntax-forward "^._" eol) (< (point) eol))
                    (memq (char-after) '(?/ ?\')))
          (forward-char))
        (and (< (point) eol) (point))))))

(defun my-bidi--lines (end text)
  "Find where Typst starts paragraphs in the lines from point to END: after
a blank line, a heading, an equation, a list or a block, and at each of
these. TEXT says a paragraph goes on into the first line. A list goes the
way of its first item, all of it (_typst/notes.typ), and lines Typst shows
nothing of go with the paragraph around them."
  (let (list)
    ;; LIST: the list being read, as (INDENT . KIND); TEXT: whether a
    ;; paragraph goes on from the line above.
    (while (and (< (point) end) (not (eobp)))
      (while (and my-bidi--math (< (caar my-bidi--math) (point)))
        (pop my-bidi--math))
      (let ((first (save-excursion (skip-chars-forward " \t") (point)))
            (eol (pos-eol))
            (indent (current-indentation))
            (item (looking-at my-bidi--item))
            (math (and my-bidi--math (<= (caar my-bidi--math) (pos-eol))
                       (pop my-bidi--math))))
        (cond
         ((looking-at-p "[ \t]*$")
          (setq text nil))
         ((and list (or (> indent (car list))
                        (and item (= indent (car list))
                             (eq (my-bidi--kind) (cdr list)))
                        (looking-at-p my-bidi--aside)))
          (my-bidi--past))
         (t
          (setq list nil)
          (cond
           (item
            (setq list (cons indent (my-bidi--kind)) text nil)
            (push (my-bidi--mark-position) my-bidi--found))
           ((looking-at-p my-bidi--aside)
            (unless text
              (push (my-bidi--mark-position) my-bidi--found))
            (my-bidi--past))
           ((looking-at-p my-bidi--block)
            (push (my-bidi--mark-position) my-bidi--found)
            (my-bidi--past t)
            (setq text nil))
           (t
            ;; A call alone on its line, starting a paragraph, is a block.
            (let ((block (and (not text)
                              (looking-at-p "[ \t]*#")
                              (not (looking-at-p my-bidi--inline-call))
                              (my-bidi--alone-p))))
              (unless text
                (push (my-bidi--mark-position) my-bidi--found))
              (my-bidi--past (or block 'inline))
              (setq text (not block)))))))
        ;; Math the line leaves open takes the lines up to its last dollar.
        ;; Set apart, it ends the paragraph, at the line's end too; after
        ;; text, outside a list, its first line starts one, as math runs
        ;; left to right.
        (pcase math
          (`(,start ,end ,apart)
           (when (< (point) end)
             (when (and apart (not list) (> start first) (> end eol))
               (save-excursion
                 (goto-char start)
                 (forward-line 1)
                 (push (my-bidi--mark-position) my-bidi--found)))
             (goto-char end)
             (forward-line 0))
           (when apart
             (setq text nil)))))
      (forward-line 1))))

(defun my-bidi--starts ()
  "The positions to mark, one on each line where Typst starts a paragraph."
  (save-excursion
    (goto-char (point-min))
    (let ((my-bidi--math (my-bidi--equations))
          (my-bidi--found nil))
      (my-bidi--lines (point-max) nil)
      (sort (delete-dups (delq nil my-bidi--found)) #'<))))

(defun my-bidi--mark ()
  "Mark the lines where Typst starts paragraphs, for `bidi-paragraph-start-re'."
  (with-demoted-errors "Marking paragraphs: %S"
    (save-restriction
      (widen)
      (let ((starts (my-bidi--starts))
            (marked nil)
            (pos (point-min)))
        (while (setq pos (text-property-not-all pos (point-max) 'syntax-table nil))
          (push pos marked)
          (setq pos (1+ pos)))
        (unless (equal starts (nreverse marked))
          (with-silent-modifications
            (remove-text-properties (point-min) (point-max) '(syntax-table nil))
            (dolist (pos starts)
              (put-text-property pos (1+ pos) 'syntax-table
                                 (string-to-syntax
                                  (if (eq (char-after pos) ?\n) " " "'"))))))))))

(defvar-local my-bidi--changed nil
  "Whether the text changed since its paragraphs were marked.")

(defun my-bidi--changed (&rest _)
  "Have the paragraphs marked again once the command ends."
  (setq my-bidi--changed t))

(defun my-bidi--mark-again ()
  "Mark the paragraphs again if the command changed the text."
  (when my-bidi--changed
    (setq my-bidi--changed nil)
    (my-bidi--mark)))

(defun my-bidi-typst ()
  "Start paragraphs where Typst does, each in the direction Typst gives it."
  (setq-local parse-sexp-lookup-properties t
              ;; Emacs keeps where it found paragraphs starting until the
              ;; text changes there; a mark moved alone left lines in the
              ;; paragraph they had been in.
              cache-long-scans nil)
  (setq bidi-paragraph-separate-re "^"
        ;; A line whose line break is a space, or with a prefix on it. (`$'
        ;; is the end of a line only before `\\)'.)
        bidi-paragraph-start-re "[^\n]*\\(?:\\(?:$\\)\\s-\\|\\s'\\)")
  (my-bidi--mark)
  (add-hook 'after-change-functions #'my-bidi--changed nil t)
  (add-hook 'post-command-hook #'my-bidi--mark-again nil t))

(add-hook 'typst-ts-mode-hook #'my-bidi-typst)

;;;; A paragraph's direction by hand

;; A Hebrew paragraph that starts with an English word, or the other way
;; round, takes that word's direction. A direction mark at its start, RLM
;; (U+200F) or LRM (U+200E), is the first strong character Emacs finds, and
;; counts as the paragraph's first letter in the notes package too
;; (_typst/notes.typ). SPC t f puts one there, against the paragraph's
;; direction, or takes it away; the marks show as their names.

(set-char-table-range glyphless-char-display '(#x200E . #x200F) 'acronym)

(defun my-bidi--paragraph-text ()
  "Move to where the text of the paragraph at point starts: past the
indentation, and a heading's or list item's marker, of its first line.
The value is whether there was a marker."
  (forward-line 0)
  (while (and bidi-paragraph-start-re
              (not (bobp))
              (not (looking-at-p bidi-paragraph-start-re)))
    (forward-line -1))
  (skip-chars-forward " \t")
  (when (looking-at (rx (or (+ "=") (any "-+/") (seq (+ digit) ".")) blank))
    (goto-char (match-end 0))))

(defun my-bidi-flip ()
  "Turn the paragraph at point the other way, with a direction mark at its
start; where there's one, take it away, back to its first letter's way."
  (interactive)
  (save-excursion
    (let ((marker (my-bidi--paragraph-text)))
      (cond ((memq (char-after) '(#x200E #x200F))
             (delete-char 1))
            ;; Before a box or an equation, a mark would be a paragraph
            ;; of its own in Typst.
            ((and (derived-mode-p 'typst-ts-mode)
                  (not marker)
                  (save-excursion
                    (forward-line 0)
                    (or (looking-at-p my-bidi--block)
                        (and (looking-at-p "[ \t]*#")
                             (not (looking-at-p my-bidi--inline-call))
                             (my-bidi--alone-p)))))
             (user-error "Not a paragraph: set the direction inside it, with #set text(dir: rtl)"))
            (t
             (insert (if (eq (current-bidi-paragraph-direction) 'right-to-left)
                         #x200E
                       #x200F)))))))

(keymap-set mode-specific-map "t f" #'my-bidi-flip)

;;;; Left and right

(defvar hel--extend-selection)
(declare-function hel-maybe-deactivate-mark "hel-lib")
(declare-function hel-keymap-global-set "hel-core")

(setq visual-order-cursor-movement t)

(defun my-bidi-left-char (count)
  "Move COUNT characters left on the screen."
  (interactive "p")
  (hel-maybe-deactivate-mark)
  (left-char count))

(defun my-bidi-right-char (count)
  "Move COUNT characters right on the screen."
  (interactive "p")
  (hel-maybe-deactivate-mark)
  (right-char count))

;; As Hel's own motions: for every cursor, merging selections that meet.
(dolist (command '(my-bidi-left-char my-bidi-right-char))
  (put command 'multiple-cursors t)
  (put command 'merge-selections 'hel--extend-selection))

(with-eval-after-load 'hel
  (hel-keymap-global-set :state 'normal
    "h" #'my-bidi-left-char  "<left>" #'my-bidi-left-char
    "l" #'my-bidi-right-char "<right>" #'my-bidi-right-char)
  (eldoc-add-command 'my-bidi-left-char 'my-bidi-right-char))

(provide 'my-bidi)
;;; my-bidi.el ends here
