;;; my-typst.el --- Typst files, with a live preview  -*- lexical-binding: t -*-
;;; Commentary:
;;
;; .typ files open in typst-ts-mode, with tinymist (through Eglot) for
;; completion and errors; ] d and [ d go to the next and previous one.
;; Tinymist's actions are on SPC l (Helheim's): SPC l r renames, SPC l f
;; formats, SPC l a offers code actions; SPC r and SPC a too, as in Helix.
;;
;; The Typst file you're in shows tinymist's live preview, in a bare window,
;; without tabs, of a browser of Chromium's kind (Helium, Chrome, Edge...;
;; without one, a tab of the default browser), which niri puts beside Emacs
;; before Emacs takes the focus back: opening a file, or coming back to it,
;; moves the preview there. It changes as you type, without saving, and
;; follows the cursor; a click in it moves the cursor there. It closes with
;; its file, or with the last Emacs window showing it. SPC c p stops or
;; starts it; one stopped that way, or closed, stays off until SPC c p. It's
;; in the palette's colours, or as the PDF looks, black on white: SPC t p
;; switches. SPC SPC writes the PDF next to the file.
;;
;; $ types a pair of dollars, the cursor between them, and on the dollar
;; that ends math steps past it. Between the two, a space brings one after
;; the cursor too ($ x $, an equation set apart), Enter puts each dollar on
;; a line of its own with the cursor on a line between, and Backspace takes
;; back the pair. In such an equation Enter ends the line with a line break,
;; \, and starts the next under the line's first &; Enter on the empty line
;; takes them back and steps out. Shift+Enter is a new line alone. With a
;; Hebrew layout on, keys type the Latin layout's characters in math and
;; code, and Hebrew in their strings and in text in brackets; in the text,
;; labels (<eq>) and references (@eq) type Latin as they're named.
;;
;;; Code:

(require 'browse-url)
(require 'treesit)
(require 'typst-preview)
(require 'my-stylix)

(defvar eglot-mode-map)
(defvar eglot-server-programs)
(defvar typst-ts-mode-map)
(declare-function adaptive-wrap-prefix-mode "adaptive-wrap")
(declare-function eglot-code-actions "eglot")
(declare-function eglot-rename "eglot")
(declare-function hel-keymap-set "hel-core")

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '(typst-ts-mode . ("tinymist")))
  (keymap-set eglot-mode-map "C-c r" #'eglot-rename)
  (keymap-set eglot-mode-map "C-c a" #'eglot-code-actions))

;; Tinymist asks for what Eglot doesn't do, each time it starts.
(add-to-list 'inhibit-message-regexps
             "unsupported capability .workspace/didChangeConfiguration.")

(defun my-typst--text ()
  "Wrap long lines at the window's edge, list items' under their text."
  (visual-line-mode)
  (adaptive-wrap-prefix-mode))

(add-hook 'typst-ts-mode-hook #'eglot-ensure)
(add-hook 'typst-ts-mode-hook #'my-typst--text)

;;;; The preview's window

(setq typst-preview-ask-if-pin-main nil
      ;; Notes draw it in the palette's colours themselves (_typst/notes.typ).
      typst-preview-invert-colors "never")

(defcustom my-typst-preview-print nil
  "Non-nil shows the preview as the PDF looks: black on white.
Else the notes are drawn in the palette's colours there."
  :type 'boolean
  :group 'typst-preview)

(defun my-typst--preview-options ()
  "What tinymist's preview is told: the palette's colours, unless print's."
  (unless my-typst-preview-print
    (append '("--input" "preview=true")
            (mapcan (lambda (color)
                      (list "--input" (format "%s=%s" (car color) (cdr color))))
                    my-stylix-colors))))

(defconst my-typst--app-id "chrome-127.0.0.1__"
  "How the preview window's app ID starts, from its address.")

(defun my-typst--focus-back ()
  "Give the focus back to the window before, if a preview has it."
  (when-let* ((niri (executable-find "niri"))
              (window (ignore-errors
                        (json-parse-string
                         (with-output-to-string
                           (call-process niri nil standard-output nil
                                         "msg" "--json" "focused-window"))
                         :object-type 'alist)))
              ((consp window))
              ((string-prefix-p my-typst--app-id
                                (format "%s" (alist-get 'app_id window)))))
    (call-process niri nil 0 nil "msg" "action" "focus-window-previous")
    t))

(defun my-typst--keep-focus ()
  "Give the focus back when a preview window takes it, as it opens.
Niri opens it beside the focused window and moves the view to show both."
  (when-let* ((niri (executable-find "niri")))
    (let* ((pending "")
           (watcher
            (make-process
             :name "typst-preview-focus"
             :noquery t
             :connection-type 'pipe
             :command (list niri "msg" "--json" "event-stream")
             :filter
             (lambda (process output)
               (setq pending (concat pending output))
               (while (string-match "\n" pending)
                 (let ((event (substring pending 0 (match-beginning 0))))
                   (setq pending (substring pending (match-end 0)))
                   (when (and (process-live-p process)
                              (or (string-search "\"WindowFocusChanged\"" event)
                                  (string-search my-typst--app-id event))
                              (my-typst--focus-back))
                     (delete-process process))))))))
      (run-at-time 15 nil (lambda ()
                            (when (process-live-p watcher)
                              (delete-process watcher)))))))

(defvar-local my-typst--window nil
  "The browser showing this buffer's preview.")
(put 'my-typst--window 'permanent-local t)

(defvar-local my-typst--off nil
  "Whether this buffer's preview was turned off: by SPC c p, or closed.")

(defconst my-typst--browsers
  '("helium" "chromium" "chromium-browser" "google-chrome-stable"
    "google-chrome" "brave" "brave-browser" "microsoft-edge-stable"
    "microsoft-edge" "vivaldi")
  "Browsers of Chromium's kind, which show a page in a window of its own
without tabs, by their commands.")

(defun my-typst--browser ()
  "The first of `my-typst--browsers' installed, or nil; on macOS and
Windows, looked for where they install themselves too."
  (or (seq-some #'executable-find my-typst--browsers)
      (seq-find
       #'file-executable-p
       (pcase system-type
         ('darwin
          (mapcar (lambda (app)
                    (format "/Applications/%s.app/Contents/MacOS/%s" app app))
                  '("Helium" "Google Chrome" "Chromium" "Brave Browser"
                    "Microsoft Edge" "Vivaldi")))
         ('windows-nt
          (mapcan (lambda (folder)
                    (mapcar (lambda (file) (expand-file-name file folder))
                            '("Google/Chrome/Application/chrome.exe"
                              "Microsoft/Edge/Application/msedge.exe"
                              "BraveSoftware/Brave-Browser/Application/brave.exe")))
                  (delq nil (mapcar #'getenv '("ProgramFiles" "ProgramFiles(x86)"
                                               "LOCALAPPDATA")))))))))

(defun my-typst--open (url &rest _)
  "Show the preview at URL in a bare window of its own: a browser's of
Chromium's kind (`my-typst--browser'), with a profile of its own. Without
one, in the default browser: xdg-open's on Linux, as in any desktop or
window manager, else the system's (on Windows, as `start' finds it if
Emacs's way fails)."
  (unless (process-live-p my-typst--window)
    (if-let* ((browser (my-typst--browser)))
        (let ((buffer (current-buffer))
              (profile (make-temp-file "typst-preview-" t)))
          (my-typst--keep-focus)
          (setq my-typst--window
                (make-process
                 :name "typst-preview-window"
                 :noquery t
                 :connection-type 'pipe
                 :command (list browser (concat "--app=" url)
                                (concat "--user-data-dir=" profile)
                                "--no-first-run" "--no-default-browser-check")
                 :sentinel
                 (lambda (process _)
                   (unless (process-live-p process)
                     ;; Its helpers write to it a little longer.
                     (run-at-time 10 nil (lambda ()
                                           (ignore-errors
                                             (delete-directory profile t))))
                     ;; Closing the window stops the preview, and keeps it
                     ;; off; one closed for another to start doesn't.
                     (when (buffer-live-p buffer)
                       (with-current-buffer buffer
                         (when (eq process my-typst--window)
                           (setq my-typst--window nil)
                           (when typst-preview-mode
                             (setq my-typst--off t)
                             (typst-preview-mode -1))))))))))
      (cond ((executable-find "xdg-open")
             (browse-url-xdg-open url))
            ((eq system-type 'windows-nt)
             (condition-case nil
                 (browse-url-default-browser url)
               (error (call-process "cmd" nil 0 nil "/c" "start" "" url))))
            (t (browse-url-default-browser url))))))

(defun my-typst--close (&rest _)
  "Close this buffer's preview window."
  (when-let* ((window my-typst--window))
    (setq my-typst--window nil)
    (when (process-live-p window)
      ;; Windows has no SIGTERM: Emacs ends the process there.
      (signal-process window (if (eq system-type 'windows-nt) 'SIGKILL 'SIGTERM)))))

(advice-add 'typst-preview-stop :after #'my-typst--close)

(defun my-typst--message (parse socket frame)
  "Take a message from the preview server in the buffer it previews,
not in whichever buffer is current when it comes: this one as its
preview starts, else one with a preview. One that comes after its
preview stopped, maybe as another starts, has no buffer left: it's
dropped."
  (when-let* ((buffer
               (seq-find (lambda (buffer)
                           (ignore-errors
                             (eq socket (typst-preview--master-socket
                                         (buffer-local-value
                                          'typst-preview--local-master buffer)))))
                         (cons (current-buffer) typst-preview--active-buffers))))
    (with-current-buffer buffer
      (funcall parse socket frame))))

(advice-add 'typst-preview--parse-message :around #'my-typst--message)

(defun my-typst--jumped (jump &rest args)
  "Move the cursor where the preview was clicked; the typing goes on here."
  (let ((inhibit-message t))
    (apply jump args))
  (my-typst--focus-back))

(advice-add 'typst-preview--editor-scroll-to :around #'my-typst--jumped)

;;;; Starting and stopping

(defun my-typst-preview ()
  "Start the preview beside this file, or stop it."
  (interactive)
  (cond (typst-preview-mode
         (setq my-typst--off t)
         (typst-preview-mode -1))
        ((not buffer-file-name) (user-error "Not visiting a file"))
        (t
         (setq my-typst--off nil)
         ;; Tinymist reads the file, then the changes from here.
         (unless (file-exists-p buffer-file-name)
           (save-buffer))
         (dolist (buffer typst-preview--active-buffers)
           (unless (eq buffer (current-buffer))
             (with-current-buffer buffer
               (typst-preview-mode -1))))
         (setq typst-preview--master-file (file-truename buffer-file-name)
               typst-preview-cmd-options (my-typst--preview-options))
         (condition-case err
             (let ((browse-url-handlers '(("" . my-typst--open))))
               (typst-preview-mode))
           (error
            ;; A start that failed (tinymist slower than the 3 s
            ;; typst-preview waits) left the mode on and tinymist running.
            (when typst-preview--local-master
              (ignore-errors
                (delete-process
                 (typst-preview--master-process typst-preview--local-master)))
              (kill-local-variable 'typst-preview--local-master))
            (setq typst-preview-mode nil)
            (force-mode-line-update)
            (user-error "The preview didn't start: %s" (error-message-string err)))))))

;;;; Its colours

(defun my-typst--restart (&rest _)
  "Start the previews again, for the colours they're given to change."
  (dolist (buffer (copy-sequence typst-preview--active-buffers))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (when typst-preview-mode
          (typst-preview-mode -1)
          (my-typst-preview))))))

(defun my-typst-preview-print ()
  "Show the preview as the PDF looks, or in the palette's colours again."
  (interactive)
  (customize-save-variable 'my-typst-preview-print (not my-typst-preview-print))
  (my-typst--restart)
  (message "The preview in %s" (if my-typst-preview-print
                                   "the PDF's colours"
                                 "the palette's colours")))

(defun my-typst--palette (&rest _)
  "Start the previews again in the palette Emacs switched to."
  (unless my-typst-preview-print
    (my-typst--restart)))

(keymap-set mode-specific-map "t p" #'my-typst-preview-print)
(add-hook 'my-look-palette-functions #'my-typst--palette)

;; The preview follows the Typst file in the selected window: opened, or
;; come back to (from the start page, another buffer, a new Emacs window),
;; or saved for the first time. It starts once the window is drawn, outside
;; the mode's hooks, which a failed start used to cut short.
(defvar my-typst--follow-timer nil
  "The timer that looks for a file to preview, once the command is done.")

(defun my-typst--follow ()
  "Start the preview of the Typst file in the selected window, if it has none."
  (setq my-typst--follow-timer nil)
  (unless (active-minibuffer-window)
    (with-current-buffer (window-buffer (selected-window))
      (when (and (derived-mode-p 'typst-ts-mode)
                 buffer-file-name
                 (file-exists-p buffer-file-name)
                 (not typst-preview-mode)
                 (not my-typst--off))
        (condition-case err
            (my-typst-preview)
          (error (message "%s" (error-message-string err))))))))

(defun my-typst--follow-soon (&rest _)
  "Look for a file to preview, once the command is done."
  (unless my-typst--follow-timer
    (setq my-typst--follow-timer (run-at-time 0 nil #'my-typst--follow))))

(add-hook 'window-buffer-change-functions #'my-typst--follow-soon)
(add-hook 'window-selection-change-functions #'my-typst--follow-soon)

(defun my-typst--follow-saves ()
  "Look for a preview to start after each save: a new file's."
  (add-hook 'after-save-hook #'my-typst--follow-soon nil t))

(add-hook 'typst-ts-mode-hook #'my-typst--follow-saves)

(defun my-typst--frame-closed (frame)
  "Stop the previews of files that no window but FRAME's shows."
  (with-demoted-errors "Stopping previews: %S"
    (dolist (buffer typst-preview--active-buffers)
      (when (and (buffer-live-p buffer)
                 (not (seq-some (lambda (window)
                                  (not (eq (window-frame window) frame)))
                                (get-buffer-window-list buffer nil t))))
        (with-current-buffer buffer
          (typst-preview-mode -1))))))

(add-hook 'delete-frame-functions #'my-typst--frame-closed)

;; A preview that stops says so, each time the preview moves.
(add-to-list 'inhibit-message-regexps "\\`Typst-preview-mode websocket closed")
(add-to-list 'set-message-functions #'inhibit-message)

;;;; Following the cursor

(defvar-local my-typst--line nil
  "The line the preview last scrolled to.")

(defconst my-typst--text
  (rx bol (* blank) (not (any "#" blank "\n")) (*? nonl) alnum)
  "A line of text rather than code, up to its first letter.")

(defun my-typst--follow-cursor ()
  "Scroll the preview to the cursor when it moves to another line."
  (let ((line (line-number-at-pos)))
    (unless (eql line my-typst--line)
      (setq my-typst--line line)
      (when (typst-preview-connected-p)
        (save-excursion
          ;; Tinymist finds only text in the document: this line's, else
          ;; the nearest above, or below.
          (beginning-of-line)
          (when (or (looking-at my-typst--text)
                    (re-search-backward my-typst--text nil t)
                    (re-search-forward my-typst--text nil t))
            (goto-char (match-end 0))
            (let ((inhibit-message t)
                  (message-log-max nil))
              (ignore-errors (typst-preview-send-position)))))))))

(defun my-typst--preview-mode ()
  "Have the preview follow the cursor while it runs."
  (setq my-typst--line nil)
  (if typst-preview-mode
      (add-hook 'post-command-hook #'my-typst--follow-cursor nil t)
    (remove-hook 'post-command-hook #'my-typst--follow-cursor t)))

(add-hook 'typst-preview-mode-hook #'my-typst--preview-mode)

;;;; Typing math

(defun my-typst--in-p (types)
  "Whether the cursor is in a node of one of TYPES: past its start, and before
its end, or at it for a comment that runs to the line's end."
  (let ((pos (point))
        (node (and (> (point) (point-min)) (treesit-node-at (1- (point))))))
    (while (and node
                (not (and (member (treesit-node-type node) types)
                          (< (treesit-node-start node) pos)
                          (or (< pos (treesit-node-end node))
                              (and (= pos (treesit-node-end node))
                                   (string-prefix-p "//" (treesit-node-text node t)))))))
      (setq node (treesit-node-parent node)))
    node))

(defun my-typst--math-ends-at (pos)
  "The math whose last dollar is at POS, if any."
  (let ((math (and (eq (char-after pos) ?$)
                   (treesit-node-parent (treesit-node-at pos)))))
    (and math
         (equal (treesit-node-type math) "math")
         (= (treesit-node-end math) (1+ pos))
         math)))

(defun my-typst--empty-math-p (pad)
  "Whether the cursor is in math with just PAD, a string, before it and after it."
  (let* ((before (- (point) (length pad) 1))
         (math (and (>= before (point-min))
                    (my-typst--math-ends-at (+ (point) (length pad))))))
    (and math
         (= (treesit-node-start math) before)
         (equal (buffer-substring (1+ before) (point)) pad)
         (equal (buffer-substring (point) (+ (point) (length pad))) pad))))

(defun my-typst-dollar ()
  "Type a dollar: after a backslash, just the one it escapes; on the one that
ends math, or before it with only spaces and line breaks between, step past
it; where math can start, type two, the cursor between them."
  (interactive)
  ;; An odd run of backslashes escapes it.
  (let ((escaped (= 1 (% (- (save-excursion (skip-chars-backward "\\\\"))) 2))))
    (cond ((and (not escaped)
                (my-typst--math-ends-at
                 (save-excursion (skip-chars-forward " \t\n") (point))))
           (skip-chars-forward " \t\n")
           (forward-char))
          ((or escaped
               (my-typst--in-p '("math" "raw_span" "raw_blck" "string" "comment"))
               (not (or (eolp)
                        (memq (char-after) '(?\s ?\t ?\) ?\] ?\} ?, ?. ?\; ?: ?! ??)))))
           (self-insert-command 1 ?$))
          (t
           (self-insert-command 1 ?$)
           (save-excursion (insert "$"))))))

(defun my-typst--space ()
  "After a space typed between the dollars of empty math, type one after the
cursor too: $ x $ sets the equation apart."
  (when (and (eq (char-before) ?\s)
             (eq (char-before (1- (point))) ?$)
             (when-let* ((math (my-typst--math-ends-at (point))))
               (= (treesit-node-start math) (- (point) 2))))
    (save-excursion (insert " "))))

(defun my-typst--math-around ()
  "The math the cursor is in, past its first dollar and before its last."
  (let ((node (and (> (point) (point-min)) (treesit-node-at (1- (point))))))
    (while (and node
                (not (and (equal (treesit-node-type node) "math")
                          (< (treesit-node-start node) (point) (treesit-node-end node)))))
      (setq node (treesit-node-parent node)))
    node))

(defun my-typst--align-column (math)
  "The column of the first & on this line that lines up MATH's lines, or nil."
  (let ((bol (pos-bol))
        (eol (pos-eol))
        (formula (treesit-node-child math 0 t)))
    (seq-some (lambda (node)
                (and (equal (treesit-node-type node) "align")
                     (<= bol (treesit-node-start node) eol)
                     (save-excursion
                       (goto-char (treesit-node-start node))
                       (current-column))))
              (and formula (treesit-node-children formula t)))))

(defun my-typst--line-break-p (math)
  "Whether a line break, \\, can go at the cursor in MATH: after text on this
line, and outside brackets."
  (let ((last (save-excursion (skip-chars-backward " \t") (point))))
    (and (> last (pos-bol))
         (let ((node (treesit-node-at (1- last)))
               (formula (treesit-node-child math 0 t))
               (outside t))
           (while (and node outside
                       (not (treesit-node-eq node formula))
                       (not (treesit-node-eq node math)))
             (setq outside (<= (treesit-node-end node) last)
                   node (treesit-node-parent node)))
           outside))))

(defun my-typst--new-line (indent)
  "Break the line at the cursor, the new one INDENT deep."
  (delete-horizontal-space)
  (insert "\n")
  (indent-to indent))

(defun my-typst--math-return (math)
  "Enter in MATH set on lines of its own: a new line of it. The line before
ends with a line break, \\, and the new one starts as deep, or at a line's
end, with & under the line's first & if it has one. On the empty line that
made, take both back, and step past MATH's last dollar if it comes next. In
brackets, or with no text before the cursor, just a new line as deep."
  (cond
   ((and (save-excursion (forward-line 0) (looking-at-p "[ \t]*&?[ \t]*$"))
         (save-excursion (forward-line -1) (looking-at-p ".*\\\\[ \t]*$")))
    (delete-region (save-excursion
                     (forward-line -1)
                     (end-of-line)
                     (skip-chars-backward " \t")
                     (backward-char)
                     (skip-chars-backward " \t")
                     (point))
                   (pos-eol))
    (when (save-excursion
            (forward-line 1)
            (skip-chars-forward " \t")
            (my-typst--math-ends-at (point)))
      (forward-line 1)
      (end-of-line)
      (my-typst--new-line (current-indentation))))
   ((my-typst--line-break-p math)
    (let ((indent (current-indentation))
          (column (and (looking-at-p "[ \t]*$") (my-typst--align-column math))))
      (delete-horizontal-space)
      (unless (eq (char-before) ?\\)
        (insert " \\"))
      (my-typst--new-line (or column indent))
      (when column
        (insert "&"))))
   (t
    (my-typst--new-line (current-indentation)))))

(defun my-typst--return (return &rest args)
  "Between the dollars of empty math, put the last one two lines down and the
cursor on the line between, both as deep as this line. In math set on lines
of its own, `my-typst--math-return'. Else RETURN."
  (let ((math (my-typst--math-around)))
    (cond ((my-typst--empty-math-p "")
           (let ((indent (current-indentation)))
             (insert "\n")
             (indent-to indent)
             (save-excursion
               (insert "\n")
               (indent-to indent))))
          ((and math
                (< (treesit-node-start math) (pos-bol))
                (> (treesit-node-end math) (pos-eol)))
           (my-typst--math-return math))
          (t (apply return args)))))

(advice-add 'typst-ts-editing-return :around #'my-typst--return)

(defun my-typst-newline ()
  "Start a new line, without a list's next item or a line break in math: in
math as deep as this line, elsewhere as typst-ts-mode indents it."
  (interactive)
  (if (my-typst--math-around)
      (my-typst--new-line (current-indentation))
    (newline-and-indent)))

(defun my-typst--electric-indent (_char)
  "Leave math's lines as deep as they're typed: typst-ts-mode would indent one
further as & or a bracket is typed on it."
  (and (my-typst--math-around) 'no-indent))

;;;; Pairs

(defconst my-typst--pairs
  '((?\( . ?\)) (?\[ . ?\]) (?\{ . ?\}) (?\" . ?\") (?* . ?*) (?_ . ?_) (?` . ?`))
  "Characters that can bring the one that closes them, and it.")

(defconst my-typst--marks '((?* . "strong") (?_ . "emph") (?` . "raw_span"))
  "The text's marks, and the syntax tree's names for what they mark.")

(defun my-typst--escaped-p ()
  "Whether a character typed at the cursor is escaped: after an odd run of
backslashes."
  (= 1 (% (- (save-excursion (skip-chars-backward "\\\\"))) 2)))

(defun my-typst--before-end-p ()
  "Whether nothing but a space, the line's end, a closing bracket, a dollar or
punctuation comes after the cursor: a pair typed there wraps nothing."
  (or (eolp)
      (memq (char-after) '(?\s ?\t ?\) ?\] ?\} ?$ ?, ?. ?\; ?: ?! ??))))

(defun my-typst--ends-here (type)
  "The node of TYPE whose last character is the one after the cursor, if it
starts before the cursor."
  (let ((node (treesit-node-at (point))))
    (while (and node (not (and (equal (treesit-node-type node) type)
                               (= (treesit-node-end node) (1+ (point))))))
      (setq node (treesit-node-parent node)))
    (and node (< (treesit-node-start node) (point)) node)))

(defun my-typst-open ()
  "Type an opening bracket; in math and code, with the one that closes it after
the cursor, unless it would wrap what follows."
  (interactive)
  (let* ((char last-command-event)
         (pair (and (not (my-typst--escaped-p))
                    (my-typst--before-end-p)
                    (or (memq (my-typst--context) '(math code))
                        ;; Text in brackets after a call: #figure(…)[…].
                        (and (eq char ?\[)
                             (memq (char-before) '(?\) ?\]))
                             (my-typst--code-ends-at (point)))))))
    (self-insert-command 1 char)
    (when pair
      (save-excursion (insert (alist-get char my-typst--pairs))))))

(defun my-typst-close ()
  "Type a closing bracket; on the same one, in math, code or text in brackets,
step past it."
  (interactive)
  (if (and (eq (char-after) last-command-event)
           (not (my-typst--escaped-p))
           (memq (my-typst--context) '(math code content)))
      (forward-char)
    (self-insert-command 1 last-command-event)))

(defun my-typst-mark ()
  "Type a quote, *, _ or `. On the one that closes what it opened, step past
it. Where it opens something, the one that closes it comes too, the cursor
between: a quote in math and code (a string), and in the text * (strong), _
(emphasis) and ` (raw text) at a word's start, unless the pair would wrap
what follows; three backticks at a line's start stay three."
  (interactive)
  (let* ((char last-command-event)
         (context (my-typst--context))
         (closes (and (eq (char-after) char)
                      (not (my-typst--escaped-p))
                      (my-typst--ends-here
                       (if (eq char ?\") "string" (alist-get char my-typst--marks)))))
         (pair (and (not closes)
                    (not (my-typst--escaped-p))
                    (my-typst--before-end-p)
                    (if (eq char ?\")
                        (memq context '(math code))
                      (and (memq context '(nil content))
                           (not (string-match-p "[[:alnum:]]"
                                                (string (or (char-before) ?\s))))
                           (not (and (eq char ?`)
                                     (looking-back "^[ \t`]*\\|``" (pos-bol)))))))))
    (if closes
        (forward-char)
      (self-insert-command 1 char)
      (when pair
        (save-excursion (insert char))))))

;;;; Latin in math and code

(defvar my-hebrew-latin-function)

(defconst my-typst--line-keywords
  '("let" "set" "show" "import" "include" "if" "for" "while" "context")
  "Keywords whose code runs on to the line's end.")

(defun my-typst--scan (start end context)
  "What END is in, reading unfinished Typst from START, which is in CONTEXT:
math, code (a name after #), args (brackets in code), line (code to the
line's end), string, content (text in brackets in code), or nil for text."
  (let ((stack (list context)))
    (save-excursion
      (goto-char start)
      (while (< (point) end)
        (let ((char (char-after))
              (top (car stack))
              (again nil))
          (pcase top
            ('string (pcase char
                       (?\\ (forward-char))
                       (?\" (pop stack))))
            ('math (pcase char
                     (?\\ (forward-char))
                     (?$ (pop stack))
                     (?\" (push 'string stack))
                     (?# (push 'code stack))))
            ('code (cond ((memq char '(?\( ?\{)) (push 'args stack))
                         ((eq char ?\[) (push 'content stack))
                         ((or (memq (char-syntax char) '(?w ?_)) (eq char ?.)))
                         (t (pop stack)
                            (setq again t))))
            ((or 'args 'line)
             (pcase char
               ((or ?\( ?\{) (push 'args stack))
               ((or ?\) ?\}) (when (eq top 'args) (pop stack)))
               (?\[ (push 'content stack))
               (?\" (push 'string stack))
               (?$ (push 'math stack))
               (?\n (when (eq top 'line) (pop stack)))))
            (_ (pcase char
                 (?\\ (forward-char))
                 (?# (push (if (looking-at-p
                                (concat "#" (regexp-opt my-typst--line-keywords) "\\_>"))
                               'line
                             'code)
                           stack))
                 (?$ (push 'math stack))
                 (?\] (when (eq top 'content) (pop stack)))
                 ;; Raw text, to as many backticks as it starts with.
                 (?` (let* ((run (- (save-excursion (skip-chars-forward "`") (point))
                                    (point)))
                            (close (save-excursion
                                     (forward-char run)
                                     (search-forward (make-string run ?`) end t))))
                       (unless close
                         (push 'raw stack))
                       (goto-char (or close end))
                       (setq again t))))))
          (unless again
            (forward-char)))))
    (car stack)))

(defun my-typst--context ()
  "What the cursor is in: math, code, string, content (text in brackets in
code), raw, comment, or nil for text. Unfinished code or math, which the
syntax tree has as an error, is read from where it starts."
  (let ((pos (point))
        (node (and (> (point) (point-min)) (treesit-node-at (1- (point)))))
        context)
    (while (and node (not context))
      (let ((start (treesit-node-start node))
            (end (treesit-node-end node)))
        (when (< start pos)
          (setq context
                (pcase (treesit-node-type node)
                  ("math" (and (< pos end) 'math))
                  ((or "group" "block") (and (< pos end) 'code))
                  ;; Typing at its end goes on with a name.
                  ("code" (and (or (< pos end)
                                   (memq (char-syntax (char-before)) '(?w ?_))
                                   (eq (char-before) ?.))
                               'code))
                  ("content" (and (< pos end) 'content))
                  ("string" (and (< pos end) 'string))
                  ((or "raw_span" "raw_blck") (and (< pos end) 'raw))
                  ;; A line's comment runs to its end.
                  ("comment" (and (or (< pos end) (eq (char-after (1+ start)) ?/))
                                  'comment))
                  ("ERROR"
                   (and (string-match-p "\\`[ \t\n]*\\'"
                                        (buffer-substring-no-properties (min pos end) pos))
                        (let ((outer (save-excursion (goto-char start) (my-typst--context))))
                          (if (memq outer '(raw comment))
                              outer
                            (pcase (my-typst--scan start pos (if (eq outer 'code) 'args outer))
                              ((or 'code 'args 'line) 'code)
                              ('nil 'text)
                              (inner inner)))))))))
        (setq node (treesit-node-parent node))))
    (cond ((eq context 'text) nil)
          (context)
          ;; A raw block not closed yet, which the tree has as text.
          ((my-typst--open-fence-p) 'raw))))

(defun my-typst--open-fence-p ()
  "Whether the cursor is in a raw block not closed yet: after an odd number
of lines that start with three backticks, not counting a block on one line."
  (save-excursion
    (forward-line 0)
    (let ((fences 0))
      (while (re-search-backward "^[ \t]*```" nil t)
        (unless (looking-at-p "[ \t]*```.*```")
          (setq fences (1+ fences))))
      (= 1 (% fences 2)))))

(defun my-typst--naming-p (&optional opener)
  "Whether the cursor is in a name as it's typed: a label's, after <, or a
reference's, after @, neither escaped (\\@) nor right after a letter; with
OPENER, only after that character."
  (save-excursion
    (skip-chars-backward "A-Za-z0-9_:.-")
    (and (memq (char-before) (if opener (list opener) '(?< ?@)))
         (progn (backward-char)
                (and (not (string-match-p "[[:alnum:]]" (string (or (char-before) ?\s))))
                     (= 0 (% (- (save-excursion (skip-chars-backward "\\\\"))) 2)))))))

(defun my-typst--code-ends-at (pos)
  "Whether code, such as a call (#figure(…)), ends at POS."
  (let ((node (and (> pos (point-min)) (treesit-node-at (1- pos)))))
    (while (and node (not (and (equal (treesit-node-type node) "code")
                               (= (treesit-node-end node) pos))))
      (setq node (treesit-node-parent node)))
    node))

(defun my-typst--label-place-p ()
  "Whether a label can start at the cursor: at a line's end, after math set
apart from the text ($ x $, or on lines of its own), a call's closing bracket
or a heading's text."
  (and (looking-at-p "[ \t]*$")
       (save-excursion
         (skip-chars-backward " \t")
         (let ((end (point)))
           (or (when-let* ((math (my-typst--math-ends-at (1- end))))
                 (and (memq (char-after (1+ (treesit-node-start math))) '(?\s ?\t ?\n))
                      (memq (char-before (1- end)) '(?\s ?\t ?\n))))
               (and (memq (char-before) '(?\) ?\]))
                    (my-typst--code-ends-at end))
               (progn (forward-line 0)
                      (looking-at-p "[ \t]*=+[ \t]")))))))

(defun my-typst--latin-p (char)
  "Whether a key typed at the cursor should type CHAR, the Latin layout's:
any in math and code; in the text, a label's or a reference's name as it's
typed, the > that ends a label, and the < that starts one where it can go.
A mark that can't be in a name stays the Hebrew layout's: @eq. ends with a
full stop."
  (let ((context (my-typst--context)))
    (or (memq context '(math code))
        (and (memq context '(nil content))
             (pcase char
               (?> (my-typst--naming-p ?<))
               (?< (my-typst--label-place-p))
               ;; The ] that ends text in brackets: the key steps past it.
               (?\] (and (eq context 'content) (eq (char-after) ?\])))
               (_ (and (string-match-p "\\`[A-Za-z0-9_:.-]\\'" (string char))
                       (my-typst--naming-p))))))))

(defun my-typst--typing ()
  "Have a space between empty dollars bring its pair, and a Hebrew layout type
Latin in math and code."
  (add-hook 'post-self-insert-hook #'my-typst--space nil t)
  (add-hook 'electric-indent-functions #'my-typst--electric-indent nil t)
  (setq-local my-hebrew-latin-function #'my-typst--latin-p))

(add-hook 'typst-ts-mode-hook #'my-typst--typing)

;; Named as Corfu's list of commands that bring completion back expects.
(defun my-typst-delete-backward-char ()
  "Delete the character before the cursor. In the middle of empty math, take
back the pair: the two dollars, the spaces either side, or the lines."
  (interactive)
  (let ((pad (buffer-substring
              (save-excursion (skip-chars-backward " \t\n") (point))
              (point))))
    (cond ((my-typst--empty-math-p pad)
           (delete-region (- (point) (max 1 (length pad)))
                          (+ (point) (max 1 (length pad)))))
          ;; An empty pair: (), "", **, and the like.
          ((and (char-before)
                (eq (alist-get (char-before) my-typst--pairs) (char-after))
                (not (save-excursion (backward-char) (my-typst--escaped-p))))
           (delete-region (1- (point)) (1+ (point))))
          (t (call-interactively #'delete-backward-char)))))

;; At each cursor, when there are several.
(dolist (command '(my-typst-dollar my-typst-delete-backward-char my-typst-newline
                   my-typst-open my-typst-close my-typst-mark))
  (put command 'multiple-cursors t))

(with-eval-after-load 'typst-ts-mode
  (keymap-set typst-ts-mode-map "C-c C-p" #'my-typst-preview)
  (hel-keymap-set typst-ts-mode-map :state 'insert
    "$" #'my-typst-dollar
    "(" #'my-typst-open "[" #'my-typst-open "{" #'my-typst-open
    ")" #'my-typst-close "]" #'my-typst-close "}" #'my-typst-close
    "\"" #'my-typst-mark "*" #'my-typst-mark "_" #'my-typst-mark "`" #'my-typst-mark
    "DEL" #'my-typst-delete-backward-char
    "S-<return>" #'my-typst-newline))

(provide 'my-typst)
;;; my-typst.el ends here
