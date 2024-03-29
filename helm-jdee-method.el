;;; helm-jdee-method.el --- JDEE method complation for helm.
;; Filename: helm-jdee-method.el
;; Description: JDEE method complation for helm.
;; URL: https://github.com/mikio/emacs-helm-jdee-method
;; Author: mikio_kun https://twitter.com/mikio_kun
;; Maintainer: mikio_kun
;; Copyright (C) :2012 mikio_kun all rights reserved.
;; Created: :2012-12-22
;; Version: 0.1.0
;; Package-Requires: ()
;; Package-Requires: ((helm "20120811")(yasnippet "20120822"))
;; Keywords: convenience

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING. If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 0:110-1301, USA.

;;; Commentary:

;; Installation:
;; Put the helm-jdee-method.el to your load-path.
;; And add to .emacs:
;;  (require 'helm-jdee-method) 
;;  (define-key jde-mode-map (kbd "C-c C-v C-i") 'helm-jdee-method)

;;; Changelog:


;;; Code:
(require 'helm)
(require 'jde)

(defvar helm-jdee-method-args-separator ", ")

(defun hjm-get-pair- ()
  (let* ((pair (jde-parse-java-variable-at-point)))
    ;;(message pair)
    (if pair
        (condition-case err
            (setq pair (jde-complete-get-pair pair nil))
          (error (condition-case err
                     (setq pair (jde-complete-get-pair pair t)))
                 (error (message "%s" (error-message-string err)))))
      (message "No completion at this point"))
    pair))

(defun hjm-get-methods- (type pair)
  (let ((access (jde-complete-get-access pair)) ; get Constant access level ("this." or "super.")
        (obj (car pair))
        completion-list)
    (progn
      (if access
          (setq completion-list
                (hjm-get-methods2- type access)) ; When, private or protect level
        (setq completion-list (hjm-get-methods2- type))) ; When public leve

      ;;if the completion list is nil check if the method is in the current
      ;;class(this)
      (if (null completion-list)
          (setq completion-list (hjm-get-methods2-
                                 (list (concat "this." obj) "")
                                 jde-complete-private)))
      ;;if completions is still null check if the method is in the
      ;;super class
      (if (null completion-list)
          (setq completion-list (hjm-get-methods2-
                                 (list (concat "super." obj) "")
                                 jde-complete-protected)))

      (if completion-list
          completion-list
        (error "No completion at this point")))))

(defun hjm-get-methods2- (type &optional access-level)
  (if type
      (cond ((member type jde-parse-primitive-types)
             (error "Cannot complete primitive type: %s" type))
            ((string= type "void")
             (error "Cannot complete return type of %s is void." type))
            (t
             (let (l
                   (method-list (jde-complete-get-classinfo type access-level)))
               (dolist (v method-list)
                 ;;(setq l (cons (format "\"%s\"" (cdr v)) l))
                 ;; (setq l (cons (cdr v) l)))
                 (setq l (cons (car v) l)))
               l)
             )
            )
    nil))

(defun hjm-debug ()
  (interactive)
  (message "%s" (hjm-get-methods))
  )

(defun hjm-get-methods ()
  (let* ((pair (hjm-get-pair-))
         (type (jde-parse-eval-type-of (car pair)))
         (methods (hjm-get-methods- type pair)))
    methods))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; http://d.hatena.ne.jp/tuto0621/20090217/1234888531
(defun hjm-copy-at-point (thing)
  (kill-new (thing-at-point thing))
  (end-of-thing thing)
  (car kill-ring)
  )

(defun hjm-kill-at-point (thing)
  (let (start end)
    (beginning-of-thing thing)
    (setq start (point))
    (end-of-thing thing)
    (setq end (point))
    (kill-region start end)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(require 'cl)

(defun hjm-method-split (s)
  (let ((ss (replace-regexp-in-string " +" "" (car (split-string s ":")))))
    ;;(message (concat "split ss:" ss))
    ss))

(defun hjm-method-list (s)
  ;;(message (concat "s:" s))
  (let ((ss (hjm-method-split s)))
    ;;(message (concat "ss:" ss))
    (when (string-match "\\(.*\\)(\\(.*\\))" ss)
      (list (match-string 1 ss) (match-string 2 ss)))))

(defun hjm-method-name (l)
  (car l))

(defun hjm-method-args (l)
  (let ((arg (car (cdr l))))
    (split-string arg ",")))

(defun hjm-method-create-snippet (l)
  (let ((len (length l)))
    (loop for i from 1 to len
          for x in l
          collect (format "${%s:%s}" i x))))

(defun hjm-join-list-stirng (l sep)
  (mapconcat 'identity l sep))

(defun hjm-method-action (s)
  "Create dynamic templete for yasnippet."
  (let* ((l (hjm-method-list s))
         (name (hjm-method-name l))
         (args (hjm-method-args l))
         (snip (hjm-method-create-snippet args))
         (sig (hjm-join-list-stirng snip helm-jdee-method-args-separator))
         (snippet (concat name "(" sig ")")))
    ;;(message snippet)
    (if (not (null (thing-at-point 'symbol)))
             (hjm-kill-at-point 'symbol))
    (yas/expand-snippet snippet)
    ))

(defun hjm-init-query ()
  (if (not (null (thing-at-point 'symbol)))
      (hjm-copy-at-point 'symbol)
    ""))

(defun ac-source-jdee-candidates ()
  (with-current-buffer helm-current-buffer
    (setq bsh-eval-timeout 5)
    (let ((l (hjm-get-methods)))
      ;;(message "end..%s" l)
      l
      )))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(eval-when-compile (require 'cl))
(require 'helm)

(defgroup helm-jdee-method nil
  "JDEE method complation for helm"
  :group 'helm)

(defvar helm-c-source-jdee-method
  '((name . "jdee-method")
    (candidates . (lambda () (ac-source-jdee-candidates)))
    (action ("Insert" . hjm-method-action))))

(defun helm-jdee-method ()
  ""
  (interactive)
  (helm
   :input (hjm-init-query) 
   :sources 'helm-c-source-jdee-method
   :buffer "*helm-jdee-method*"))

(provide 'helm-jdee-method)

;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:

;;; helm-jdee-method.el ends here
