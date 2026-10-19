;;; my-look.el --- Colours, fonts, shading and room  -*- lexical-binding: t -*-
;;; Commentary:
;;
;; The palette (my-stylix.el, made by _package.nix), dark or light: SPC t l
;; switches, and Emacs keeps the choice. base16-theme draws it, as Stylix's
;; Emacs template has it draw its colours, and my-colors.el puts Helix's
;; choices over that. Also the windows' opacity and the main font; fonts
;; for icons and Hebrew; panels and pop-ups a shade darker than files
;; (solaire-mode); room around text and windows (spacious-padding); and
;; Ctrl and the wheel zooming over a window's margins too.
;;
;;; Code:

(require 'cl-lib)
(require 'my-stylix)
(require 'base16-theme)

(defvar base16-theme-256-color-source)
(setq base16-theme-256-color-source 'colors)

;;;; The palette

(defcustom my-look-palette nil
  "The palette, `dark' or `light'; nil for the one this setup starts with."
  :type '(choice (const :tag "As set up" nil) (const dark) (const light))
  :group 'faces)

(defvar my-look-palette-functions nil
  "Functions called with the palette, an alist by base16 name, as it changes.")

(deftheme base16-stylix "The palette, drawn as Stylix draws base16 schemes.")

(defun my-look--draw (colors)
  "Draw COLORS, an alist by base16 name."
  (base16-theme-define
   'base16-stylix
   (cl-loop for (name . color) in colors
            when (string-match-p "\\`base0" (symbol-name name))
            append (list (intern (format ":%s" name)) color)))
  (enable-theme 'base16-stylix)
  ;; The `user' theme outlasts `load-theme'.
  (let-alist colors
    (custom-theme-set-faces
     'user
     `(solaire-default-face ((t :background ,.base10)))
     `(solaire-fringe-face ((t :background ,.base10)))
     `(solaire-line-number-face ((t :inherit line-number :background ,.base10)))
     `(solaire-hl-line-face ((t :background ,.base01)))))
  (run-hook-with-args 'my-look-palette-functions colors))

(defun my-look-set-palette (name)
  "Use the palette NAME, `dark' or `light'."
  (setq my-stylix-colors (alist-get name my-stylix-palettes))
  (my-look--draw my-stylix-colors))

(defun my-look-palette ()
  "The palette in use: `dark' or `light'."
  (car (rassq my-stylix-colors my-stylix-palettes)))

(defun my-look-light ()
  "Switch between the dark palette and the light one, for now and later."
  (interactive)
  (let ((name (if (eq (my-look-palette) 'dark) 'light 'dark)))
    (my-look-set-palette name)
    (customize-save-variable 'my-look-palette name)
    (message "The %s palette" name)))

(keymap-set mode-specific-map "t l" #'my-look-light)

(my-look-set-palette my-stylix-polarity)
(add-to-list 'default-frame-alist `(alpha-background . ,my-stylix-opacity))

;; The palette saved (custom.el) is there after init.
(add-hook 'after-init-hook
          (lambda ()
            (when (and my-look-palette (not (eq my-look-palette (my-look-palette))))
              (my-look-set-palette my-look-palette)))
          90)

;;;; Fonts

(defconst my-look--icon-fonts
  '(("Symbols Nerd Font Mono"
     (#xe5fa . #xe6b7) ; Seti-UI + Custom
     (#xe700 . #xe8ef) ; Devicons
     (#xed00 . #xf2ff) ; Font Awesome
     (#xe200 . #xe2a9) ; Font Awesome Extension
     (#xe300 . #xe3e3) ; Weather
     (#xf400 . #xf533) #x2665 #x26A1 ; Octicons
     (#x23fb . #x23fe) #x2b58 ; IEC Power Symbols
     (#xf300 . #xf381) ; Font Logos
     (#xe000 . #xe00a) ; Pomicons
     (#xea60 . #xec1e) ; Codicons
     (#x276c . #x2771) ; Heavy Angle Brackets
     (#xee00 . #xee0b) ; Progress
     (#xf0001 . #xf1af0)) ; Material Design Icons
    ;; The modeline isn't held to a grid: proportional Powerline symbols
    ;; look better.
    ("Symbols Nerd Font"
     (#xe0a0 . #xe0a2) (#xe0b0 . #xe0b3) ; Powerline Symbols
     (#xe0b4 . #xe0c8) (#xe0cc . #xe0d7) ; Powerline Extra Symbols
     #xe0a3 #xe0ca))
  "Helheim's fonts for icons (from its init.example.el), and their code points.")

(defun my-look-fonts (&optional frame)
  "Set Stylix's main font, and the fonts for icons, Hebrew and U+2000.
They take once there's a window (FRAME) that can show them; the main font,
if it's installed."
  (when (display-graphic-p frame)
    (when (find-font (font-spec :family my-stylix-mono) frame)
      (set-face-attribute 'default nil
                          :font (font-spec :family my-stylix-mono :size my-stylix-size)))
    (pcase-dolist (`(,font . ,code-points) my-look--icon-fonts)
      (dolist (code-point code-points)
        (set-fontset-font t code-point font)))
    (set-fontset-font t 'hebrew "Noto Sans Hebrew")
    ;; Hel draws extra cursors with U+2000, which needs a proportional font.
    (set-fontset-font t #x2000 my-stylix-sans)))

;; The Emacs that keeps running starts with no window: it sets them for each
;; new one, before laying anything out in it.
(if (daemonp)
    (add-hook 'after-make-frame-functions #'my-look-fonts)
  (my-look-fonts))

(custom-theme-set-faces
 'user
 `(variable-pitch ((t :family ,my-stylix-sans))))

(solaire-global-mode)
(spacious-padding-mode)

;;;; Zooming

;; Emacs binds Ctrl and the wheel over text only; a window whose text is
;; narrower than it (Helheim's line wrapping) has margins beside it.
(dolist (area '("left-margin" "right-margin" "left-fringe" "right-fringe"))
  (dolist (wheel '("wheel-up" "wheel-down"))
    (keymap-global-set (format "<%s> C-<%s>" area wheel)
                       #'mouse-wheel-text-scale)
    (keymap-global-set (format "<%s> C-M-<%s>" area wheel)
                       #'mouse-wheel-global-text-scale)))

(provide 'my-look)
;;; my-look.el ends here
