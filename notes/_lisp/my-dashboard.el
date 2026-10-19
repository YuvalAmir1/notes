;;; my-dashboard.el --- The start page  -*- lexical-binding: t -*-
;;; Commentary:
;;
;; Emacs opens on a dashboard: its logo, a new note from each template and
;; today's note, and the files opened last (notes by their titles), with the
;; cursor on the first template. So does every window of the Emacs that keeps running (the
;; launcher's, emacsclient's). `emacs FILE' opens just the file.
;;
;;; Code:

(require 'my-notes)

(defvar dashboard-icon-type)
(defvar dashboard-set-heading-icons)
(defvar dashboard-set-file-icons)
(defvar recentf-list)
(defvar server-client-instructions)

;; Set before the dashboard loads, which picks its icons then.
(setq dashboard-icon-type 'nerd-icons
      dashboard-set-heading-icons t
      dashboard-set-file-icons t)

(require 'dashboard)

(setq dashboard-startup-banner 'logo
      ;; Emacs fills a picture's see-through parts with the background
      ;; colour, opaque, where the window's own background is translucent:
      ;; a mask leaves them out.
      dashboard-image-extra-props '(:mask heuristic)
      dashboard-banner-logo-title "Notes"
      dashboard-center-content t
      dashboard-vertically-center-content t
      dashboard-items '((templates . 12) (recents . 6))
      dashboard-startupify-list '(dashboard-insert-banner
                                  dashboard-insert-newline
                                  dashboard-insert-banner-title
                                  dashboard-insert-newline
                                  dashboard-insert-items))

(setf (alist-get 'templates dashboard-item-shortcuts) "n"
      (alist-get 'templates dashboard-heading-icons) "nf-oct-file_added")

;;;; New notes

(defun my-dashboard--templates (list-size)
  "Insert a new note from each template, up to LIST-SIZE of them, then
today's note."
  (dashboard-insert-section
   "New note:"
   (append (my-notes-templates) (list (cons "Today's note" (my-notes-today-file))))
   list-size
   'templates
   (dashboard-get-shortcut 'templates)
   (lambda (&rest _)
     (if (equal (car el) "Today's note")
         (my-notes-today)
       (my-notes-new (cdr el) (read-string "Title: "))))
   (propertize (car el) 'dashboard-path (cdr el))))

(setf (alist-get 'templates dashboard-item-generators) #'my-dashboard--templates)

;;;; Files by their titles

(defun my-dashboard--recents (list-size)
  "Insert the LIST-SIZE files opened last, notes by their titles."
  (dashboard-insert-section
   "Recent files:"
   recentf-list
   list-size
   'recents
   (dashboard-get-shortcut 'recents)
   (lambda (&rest _) (find-file-existing el))
   (propertize (if (string-suffix-p ".typ" el)
                   (my-notes-title el)
                 (abbreviate-file-name el))
               'dashboard-path el)))

(setf (alist-get 'recents dashboard-item-generators) #'my-dashboard--recents)

;;;; Laid out for its window

(defun my-dashboard--resize (window)
  "Center the dashboard again in WINDOW if the window's height changed."
  (let ((height (window-body-height window t)))
    (unless (eql height (window-parameter window 'my-dashboard-height))
      (set-window-parameter window 'my-dashboard-height height)
      (with-selected-window window
        (dashboard-open)))))

(defun my-dashboard--setup ()
  "Put the cursor on the first item, and follow the windows' heights.
A new window takes its size from the compositor after Emacs lays it out."
  (ignore-errors (widget-forward 1))
  (dolist (window (get-buffer-window-list nil nil t))
    (set-window-point window (point))
    (set-window-parameter window 'my-dashboard-height
                          (window-body-height window t)))
  (add-hook 'window-size-change-functions #'my-dashboard--resize nil t))

(add-hook 'dashboard-mode-hook #'my-dashboard--setup)

;;;; Where it opens

(defun my-dashboard--client ()
  "The dashboard, for a window of the Emacs that keeps running."
  (if (frame-parameter nil 'client)
      (dashboard-open)
    (get-scratch-buffer-create)))

(if (daemonp)
    (setq initial-buffer-choice #'my-dashboard--client
          server-client-instructions nil)
  (dashboard-setup-startup-hook))

(provide 'my-dashboard)
;;; my-dashboard.el ends here
