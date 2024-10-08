;;; process-history-consult.el --- Process history consult integration -*- lexical-binding: t -*-

;; Copyright (C) 2023  Free Software Foundation, Inc.

;; Author: Daniel Pettersson
;; Maintainer: Daniel Pettersson <daniel@dpettersson.net>
;; Created: 2023
;; License: GPL-3.0-or-later
;; Version: 0.0.1
;; Homepage: https://github.com/svaante/process-history
;; Package-Requires: ((emacs "29.1") (consult))

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; To enable usage of consult backed completing-read interface, set
;; the default completing read function for process-history.

;; (setopt process-history-completing-read-fn
;;   'process-history-consult-completing-read)

;;; Code:

(require 'process-history)
(require 'consult)

(defun process-history-consult-completing-read (prompt &optional predicate)
  "Read a string in the minibuffer, with completion.
PROMPT is a string to prompt with; normally it ends in a colon and a
space.
PREDICATE is an optional function taking command string and
`process-history--item'.
Completes from collection based on `process-history'."
  (let* ((alist
          (seq-filter (or predicate 'identity)
                      (process-history--collection)))
         (annotate-fn-1
          (process-history--make-annotation alist))
         (annotate-fn (lambda (cand)
                        ;; HACK Don't slide annotation of the edge of
                        ;;      the world just because of one long
                        ;;      command string.
                        (setq consult--annotate-align-width 0)
                        (funcall annotate-fn-1 cand)))
         (directory (abbreviate-file-name default-directory))
         (sources
          `((:name "Active" :narrow ?a :items
                   ,(lambda ()
                      (cl-loop for (str . item) in alist
                               unless (process-history--item-exit-code item)
                               collect str)))
            (:name "Exited" :narrow ?e :items
                   ,(lambda ()
                      (cl-loop for (str . item) in alist
                               when (process-history--item-exit-code item)
                               collect str)))
            (:name "Unique" :narrow ?u :hidden t :items
                   ,(lambda ()
                      (cl-loop with table = (make-hash-table :test 'equal)
                               for (str . item) in alist
                               for key = (cons (process-history--item-command item)
                                               (process-history--item-directory item))
                               unless (gethash key table) collect
                               str and do (puthash key t table))))
            (:name "Project" :narrow ?p :hidden t :items
                   ,(lambda ()
                      (when-let* ((root (consult--project-root))
                                  (root (abbreviate-file-name root)))
                        (cl-loop for (str . item) in alist
                                 when (equal root (process-history--item-directory item))
                                 collect str))))
            (:name ,(format "Directory (%s)" directory) :narrow ?d :hidden t :items
                   ,(lambda ()
                      (cl-loop for (str . item) in alist
                               when (equal directory (process-history--item-directory item))
                               collect str)))))
         (sources
          (cl-loop for source in sources collect
                   (append source
                           `(:category process-history :annotate ,annotate-fn))))
         (match (car (consult--multi sources
                                     :prompt prompt
                                     :require-match t
                                     :sort nil))))
    (alist-get match alist nil nil 'equal)))

(setq process-history-completing-read-fn
      #'process-history-consult-completing-read)

(provide 'process-history-consult)
;;; process-history-consult.el ends here
