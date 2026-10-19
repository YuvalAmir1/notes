;;; my-notes.el --- Notes in Typst, made from templates  -*- lexical-binding: t -*-
;;; Commentary:
;;
;; Notes are Typst files in ~/notes (on Windows, notes in your user
;; folder). A new note starts as a copy of a template, any .typ file in
;; ~/notes/templates: {{title}}, {{date}} and {{author}} (your name) are
;; filled in, and the cursor goes where {{cursor}} was, ready to type. The
;; start page lists the templates; SPC n n finds a note by its title or
;; makes one, SPC n t makes one from a template, SPC n / searches them.
;; SPC n d opens today's note, in ~/notes/daily, made from daily.typ the
;; first time.
;;
;; SPC n l links another note, picked by its title; g f follows a link (an
;; #include, a picture) to its file, and SPC n b lists the notes that link
;; to this one. A notebook (the Notebook template) is one PDF of the notes
;; it includes: SPC n i adds one. SPC i p puts the picture on the clipboard
;; beside the note, and #image(...) where the cursor is. SPC i l sets the note
;; up for one of Typst's libraries installed (_package.nix): physics
;; notation, units, plots, diagrams, theorems, pseudocode and more.
;;
;;; Code:

(require 'treesit)
(require 'my-typst-libraries)

(declare-function consult-ripgrep "consult")
(declare-function evil-insert-state "evil-states")
(declare-function hel-insert-state "hel-core")
(declare-function hel-keymap-set "hel-core")
(declare-function my-typst--context "my-typst")
(declare-function which-key-add-key-based-replacements "which-key")
(defvar my-root)
(defvar typst-ts-mode-map)

(defvar my-notes-directory
  (if (eq system-type 'windows-nt)
      (expand-file-name "notes/" (getenv "USERPROFILE"))
    (expand-file-name "~/notes/"))
  "Where notes are kept.")

(defvar my-notes-template-directory
  (expand-file-name "templates/" my-notes-directory)
  "Where the templates for new notes are kept.")

;;;; The templates this setup comes with

(defun my-notes--copied-file ()
  "The list of the templates put in the notes' folder, one name a line."
  (expand-file-name "notes/templates-copied"
                    (if (memq system-type '(windows-nt darwin))
                        user-emacs-directory
                      (let ((state (getenv "XDG_STATE_HOME")))
                        (if (and state (file-name-absolute-p state))
                            state
                          "~/.local/state")))))

(defun my-notes-seed ()
  "Put each template this setup comes with (_typst/templates) in the
notes' templates folder once, unless one of its name is there: after that
it's yours, and one you delete stays deleted. Without the folder, all come
back."
  (let ((from (and (boundp 'my-root) (expand-file-name "templates/" my-root)))
        (list (my-notes--copied-file)))
    (when (and from (file-directory-p from))
      (unless (file-directory-p my-notes-template-directory)
        (make-directory my-notes-template-directory t)
        (when (file-exists-p list)
          (delete-file list)))
      (let ((copied (and (file-readable-p list)
                         (with-temp-buffer
                           (insert-file-contents list)
                           (split-string (buffer-string) "\n" t)))))
        (dolist (template (directory-files from t "\\`[^.].*\\.typ\\'"))
          (let* ((name (file-name-nondirectory template))
                 (to (expand-file-name name my-notes-template-directory)))
            (unless (member name copied)
              (unless (file-exists-p to)
                (copy-file template to)
                (set-file-modes to #o644))
              (make-directory (file-name-directory list) t)
              (write-region (concat name "\n") nil list t 'silent))))))))

(my-notes-seed)

;;;; Notes and templates

(defun my-notes-title (file)
  "FILE's title: its `title:' or its first heading, else its name."
  (or (with-temp-buffer
        (ignore-errors (insert-file-contents file nil 0 4096))
        (goto-char (point-min))
        (cond ((re-search-forward
                "title: *\"\\(\\(?:[^\"\\\n]\\|\\\\.\\)+\\)\"" nil t)
               ;; A Typst string, its \" and \\ as " and \.
               (string-trim (replace-regexp-in-string
                             "\\\\\\(.\\)" "\\1" (match-string 1))))
              ((re-search-forward "^= +\\(.+\\)$" nil t)
               (string-trim (match-string 1)))))
      (file-name-base file)))

(defun my-notes-files ()
  "The notes, the last changed first."
  (sort (directory-files-recursively
         my-notes-directory "\\.typ\\'" nil
         (lambda (dir)
           (not (or (string-prefix-p "." (file-name-nondirectory dir))
                    (file-equal-p dir my-notes-template-directory)))))
        :key (lambda (file) (file-attribute-modification-time (file-attributes file)))
        :reverse t))

(defun my-notes-templates ()
  "The templates, as (NAME . FILE); not daily.typ, today's note's."
  (mapcar (lambda (file) (cons (capitalize (file-name-base file)) file))
          (and (file-directory-p my-notes-template-directory)
               (seq-remove (lambda (file) (equal (file-name-nondirectory file) "daily.typ"))
                           (directory-files my-notes-template-directory t
                                            "\\`[^.].*\\.typ\\'")))))

(defun my-notes--read-template ()
  "Ask which template to use, if there's more than one; return its file."
  (let ((templates (my-notes-templates)))
    (cond ((null templates)
           (user-error "No templates in %s" my-notes-template-directory))
          ((null (cdr templates)) (cdar templates))
          (t (cdr (assoc (completing-read "Template: " templates nil t)
                         templates))))))

;;;; A new note

(defun my-notes--file (title)
  "A file name in `my-notes-directory' for TITLE that isn't taken."
  (let* ((slug (string-trim (replace-regexp-in-string
                             "[^[:alnum:]]+" "-" (downcase title))
                            "-+" "-+"))
         (base (if (string-empty-p slug) "note" slug))
         (file (expand-file-name (concat base ".typ") my-notes-directory))
         (n 1))
    (while (file-exists-p file)
      (setq n (1+ n)
            file (expand-file-name (format "%s-%d.typ" base n)
                                   my-notes-directory)))
    file))

(defun my-notes--string (text)
  "TEXT as the inside of a Typst string."
  (replace-regexp-in-string "[\\\"]" (lambda (char) (concat "\\" char)) text t t))

(defun my-notes-new (template title)
  "Make a note called TITLE from TEMPLATE, a file, and open it."
  (interactive (list (my-notes--read-template) (read-string "Title: ")))
  (my-notes--make template title (my-notes--file title)))

(defun my-notes--make (template title file)
  "Make the note FILE, called TITLE, from TEMPLATE, and open it."
  (let ((cursor nil))
    ;; Written before it opens, for the preview to read.
    (with-temp-buffer
      (insert-file-contents template)
      (dolist (field `(("{{date}}" . ,(format-time-string "%F"))
                       ;; As Typst strings, which the templates put them in.
                       ("{{title}}" . ,(my-notes--string title))
                       ("{{author}}" . ,(my-notes--string
                                         (if (string-empty-p user-full-name)
                                             (user-login-name)
                                           user-full-name)))))
        (goto-char (point-min))
        (while (search-forward (car field) nil t)
          (replace-match (cdr field) t t)))
      (goto-char (point-min))
      (setq cursor (if (search-forward "{{cursor}}" nil t)
                       (progn (replace-match "" t t) (point))
                     (point-max)))
      (make-directory (file-name-directory file) t)
      (let ((coding-system-for-write 'utf-8-unix))
        (write-region nil nil file nil 'silent)))
    (find-file file)
    (goto-char cursor)
    (cond ((bound-and-true-p evil-local-mode) (evil-insert-state))
          ((fboundp 'hel-insert-state) (hel-insert-state 1)))))

;;;; Finding notes

(defun my-notes-find ()
  "Open a note by its title, or make a note with a title not taken."
  (interactive)
  (let* ((notes (mapcar (lambda (file) (cons (my-notes-title file) file))
                        (my-notes-files)))
         (title (completing-read "Note: " notes)))
    (if-let* ((file (cdr (assoc title notes))))
        (find-file file)
      (my-notes-new (my-notes--read-template) title))))

(defun my-notes-search ()
  "Search the notes' text."
  (interactive)
  (consult-ripgrep my-notes-directory))

;;;; Today's note

(defvar my-notes-daily-directory (expand-file-name "daily/" my-notes-directory)
  "Where the daily notes are kept, each named by its date.")

(defun my-notes-today-file ()
  "Today's note's file."
  (expand-file-name (format-time-string "%F.typ") my-notes-daily-directory))

(defun my-notes-today ()
  "Open today's note; the first time, make it from the template daily.typ."
  (interactive)
  (let ((file (my-notes-today-file))
        (template (expand-file-name "daily.typ" my-notes-template-directory)))
    (if (file-exists-p file)
        (find-file file)
      (my-notes--make (if (file-exists-p template) template (my-notes--read-template))
                      (format-time-string "%A, %-d %B %Y")
                      file))))

;;;; Links, includes and pictures

(defun my-notes--read-note (prompt)
  "Ask, with PROMPT, for another note by its title; return its file."
  (let* ((notes (mapcar (lambda (file) (cons (my-notes-title file) file))
                        (seq-remove (lambda (file)
                                      (and buffer-file-name
                                           (file-equal-p file buffer-file-name)))
                                    (my-notes-files))))
         (title (completing-read prompt notes nil t)))
    (cdr (assoc title notes))))

(defun my-notes--relative (file)
  "FILE's name from this note's folder, inside a Typst string."
  (my-notes--string (file-relative-name file)))

(defun my-notes--code ()
  "What starts code where the cursor is: # in text and math, nothing in code."
  (if (eq (my-typst--context) 'code) "" "#"))

(defun my-notes-link (file)
  "Link to the note FILE, picked by its title: the selected text, without
the spaces around it, or else the note's title, is the link's."
  (interactive (list (my-notes--read-note "Link to: ")))
  (let ((text nil))
    (when (use-region-p)
      (let ((start (region-beginning))
            (end (region-end)))
        (goto-char end)
        (skip-chars-backward " \t\n" start)
        (setq end (point))
        (goto-char start)
        (skip-chars-forward " \t\n" end)
        (setq text (delete-and-extract-region (point) end)))
      (deactivate-mark))
    (insert (format "%slink(\"%s\")[%s]" (my-notes--code) (my-notes--relative file)
                    (if (member text '(nil ""))
                        ;; As text in Typst's brackets.
                        (replace-regexp-in-string "[][\\#*_$<@`~]" "\\\\\\&"
                                                  (my-notes-title file))
                      text)))))

(defun my-notes-include (file)
  "Put the note FILE, picked by its title, in this one, on a line of its
own: in a notebook, its next note."
  (interactive (list (my-notes--read-note "Include: ")))
  (end-of-line)
  (unless (bolp)
    (insert "\n"))
  (insert (format "%sinclude \"%s\"" (my-notes--code) (my-notes--relative file))))

(defun my-notes-backlinks ()
  "Open a note that links to this one, or includes it, at that link; one
picked by its title if there are several."
  (interactive)
  (unless buffer-file-name
    (user-error "Not visiting a file"))
  (let* ((pattern (concat "[\"/]" (regexp-quote (file-name-nondirectory buffer-file-name))
                          "\""))
         (notes (seq-keep (lambda (file)
                            (and (not (file-equal-p file buffer-file-name))
                                 ;; An open note as it stands, saved or not.
                                 (if-let* ((buffer (find-buffer-visiting file)))
                                     (with-current-buffer buffer
                                       (save-excursion
                                         (goto-char (point-min))
                                         (re-search-forward pattern nil t)))
                                   (with-temp-buffer
                                     (insert-file-contents file)
                                     (re-search-forward pattern nil t)))
                                 (cons (my-notes-title file) file)))
                          (my-notes-files))))
    (unless notes
      (user-error "No note links here"))
    (find-file (cdr (if (cdr notes)
                        (assoc (completing-read "Linked from: " notes nil t) notes)
                      (car notes))))
    (goto-char (point-min))
    (when (re-search-forward pattern nil t)
      (goto-char (match-beginning 0))
      (when (re-search-backward "\\(?:link\\|include\\)\\_>" (line-beginning-position) t)
        (when (eq (char-before) ?#)
          (backward-char))))))

(defun my-notes--path (node)
  "The file NODE, a Typst string, names, unless it's a web address."
  (when (equal (treesit-node-type node) "string")
    (let ((name (replace-regexp-in-string
                 "\\\\\\(.\\)" "\\1" (substring (treesit-node-text node t) 1 -1))))
      (unless (string-match-p "\\`[[:alpha:]][[:alnum:]+.-]*:" name)
        name))))

(defun my-notes--file-at-point (&optional pos)
  "The file the link, include or picture at POS names, or nil: at the
cursor, else just before it."
  (let ((node (treesit-node-at (or pos (point))))
        file)
    (while (and node (not file))
      (setq file
            (pcase (treesit-node-type node)
              ("include" (my-notes--path (treesit-node-child node 0 t)))
              ("call"
               ;; link("…")[…] is a call of a call.
               (let ((call node))
                 (while (equal (treesit-node-type (treesit-node-child-by-field-name call "item"))
                               "call")
                   (setq call (treesit-node-child-by-field-name call "item")))
                 (when (member (treesit-node-text (treesit-node-child-by-field-name call "item") t)
                               '("link" "image"))
                   (my-notes--path (treesit-node-child (treesit-node-child call 1 t) 0 t))))))
            node (treesit-node-parent node)))
    (or file
        (and (not pos) (> (point) (point-min))
             (my-notes--file-at-point (1- (point)))))))

(defun my-notes-follow ()
  "Open the file the link, include or picture at the cursor names; else
the file named at the cursor, as g f does elsewhere."
  (interactive)
  (if-let* ((file (my-notes--file-at-point)))
      (find-file (expand-file-name file))
    (call-interactively #'find-file-at-point)))

(defun my-notes--picture (type data)
  "Save DATA, a picture of the MIME TYPE, beside the note, and show it here."
  (unless buffer-file-name
    (user-error "Save the note first"))
  (let ((base (file-name-sans-extension buffer-file-name))
        (extension (if (equal type "image/jpeg") "jpg" "png"))
        (n 1)
        file)
    (while (file-exists-p (setq file (format "%s-%d.%s" base n extension)))
      (setq n (1+ n)))
    (let ((coding-system-for-write 'no-conversion))
      (write-region data nil file nil 'silent))
    (insert (format "%simage(\"%s\")" (my-notes--code)
                    (my-notes--string (file-name-nondirectory file))))))

(defun my-notes-picture ()
  "Put the picture on the clipboard beside the note, and show it here."
  (interactive)
  (condition-case err
      (yank-media)
    (user-error
     (if (string-prefix-p "No handler" (cadr err))
         (user-error "No picture on the clipboard")
       (signal (car err) (cdr err))))))

(add-hook 'typst-ts-mode-hook
          (lambda () (yank-media-handler "image/\\(?:png\\|jpeg\\)" #'my-notes--picture)))

;;;; Typst's libraries

(defun my-notes--preamble-end ()
  "Where the lines that set the note up end: its imports, show and set
rules and definitions, at its top, blank lines between them or not."
  (let ((end (point-min)))
    (catch 'done
      (dolist (node (treesit-node-children (treesit-buffer-root-node)))
        (pcase (treesit-node-type node)
          ("parbreak")
          ("code" (if (string-match-p "\\`#\\(?:import\\|show\\|set\\|let\\)\\_>"
                                      (treesit-node-text node t))
                      (setq end (treesit-node-end node))
                    (throw 'done nil)))
          (_ (throw 'done nil)))))
    end))

(defun my-notes--set-up-p (line)
  "Whether LINE, of a library's setup, is in the note already: an import,
if the note imports that package."
  (save-excursion
    (goto-char (point-min))
    (search-forward (if (string-match "\\`#import \"@[^\"]+\"" line)
                        (match-string 0 line)
                      line)
                    nil t)))

(defun my-notes-library (name)
  "Set the note up for the Typst library NAME, one installed
\(`my-typst-libraries'): the lines of its setup the note lacks go after
those at its top."
  (interactive
   (list (completing-read
          "Library: "
          (lambda (string predicate action)
            (if (eq action 'metadata)
                `(metadata (annotation-function
                            . ,(lambda (name)
                                 (concat "  " (nth 1 (assoc name my-typst-libraries))))))
              (complete-with-action action my-typst-libraries string predicate)))
          nil t)))
  (let ((missing (seq-remove #'my-notes--set-up-p
                             (split-string (nth 2 (assoc name my-typst-libraries)) "\n"))))
    (if (null missing)
        (message "%s is set up already" name)
      (save-excursion
        (let ((end (my-notes--preamble-end))
              (lines (string-join missing "\n")))
          (goto-char end)
          (if (= end (point-min))
              (insert lines "\n")
            (insert "\n" lines))))
      (message "%s is set up" name))))

;;;; Keys

(keymap-set mode-specific-map "n n" #'my-notes-find)
(keymap-set mode-specific-map "n t" #'my-notes-new)
(keymap-set mode-specific-map "n /" #'my-notes-search)
(keymap-set mode-specific-map "n d" #'my-notes-today)
(keymap-set mode-specific-map "n b" #'my-notes-backlinks)
(with-eval-after-load 'typst-ts-mode
  (keymap-set typst-ts-mode-map "C-c n l" #'my-notes-link)
  (keymap-set typst-ts-mode-map "C-c n i" #'my-notes-include)
  (keymap-set typst-ts-mode-map "C-c i p" #'my-notes-picture)
  (keymap-set typst-ts-mode-map "C-c i l" #'my-notes-library)
  (hel-keymap-set typst-ts-mode-map :state 'normal "g f" #'my-notes-follow))
(with-eval-after-load 'which-key
  (which-key-add-key-based-replacements "C-c n" "notes"))

(provide 'my-notes)
;;; my-notes.el ends here
