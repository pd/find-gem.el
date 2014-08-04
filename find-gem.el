;;; find-gem.el --- Open Ruby gem contents from Emacs  -*- lexical-binding: t; -*-

;; Copyright (C) 2014  Kyle Hargraves

;; Author: Kyle Hargraves <khargraves@enova-khargraves.enova.com>
;; Keywords: tools, convenience
;; Version: 0.9.0
;; URL: https://github.com/pd/find-gem.el
;; Package-Requires: ((dash "1.0.3") (s "1.0.0") (f "0.16.0"))
;; License: MIT

;;; Commentary:

;; TODO

;;; Code:

(require 'dash)
(require 's)
(require 'f)

(defgroup find-gem nil
  "Open Ruby gem contents"
  :group 'tools)

(defcustom find-gem-strategies
  '(find-gem-strategy-gem-env
    find-gem-strategy-env)
  "Functions used to determine your active gem path. These should
return a list of directories in which to find gems. The first to
return a non-NIL value will be used."
  :type 'list
  :group 'find-gem)

(defcustom find-gem-action 'find-file
  "Operation to perform once a gem has been selected."
  :type '(choice (symbol :tag "Open dired" 'dired)
                 (symbol :tag "Find file in directory" 'find-file))
  :group 'find-gem)

(defcustom find-gem-completing-read
  (if (fboundp 'ido-completing-read)
      'ido-completing-read
    'completing-read)
  "The `completing-read' function to use. Defaults to `ido-completing-read' if available."
  :type 'function
  :group 'find-gem)

(defcustom find-gem-find-file-in-dir
  (if (fboundp 'ido-find-file-in-dir)
      'ido-find-file-in-dir
    (lambda (dir)
      (let ((default-directory dir))
        (call-interactively 'find-file))))
  "The function to use to find a file, when `find-gem-action' is set to find-file."
  :type 'function
  :group 'find-gem)

(defvar find-gem-gem-env-cache '()
  "Cache for the results of `find-gem-strategy-gem-env' per directory.
If you are using a ruby version manager (chruby, rbenv, rvm, etc), it
can be expensive to shell out to 'gem'; this makes it a one-time cost.")

(defun find-gem--gem-dirs-in (dir)
  "Returns 'DIR/gems' and 'DIR/bundler/gems' iff those directories exist."
  (let ((join    (lambda (subdir) (f-join dir subdir)))
        (subdirs '("gems" "bundler/gems")))
    (-select #'f-exists? (mapcar join subdirs))))

(defun find-gem--gems-in (dir)
  "Given a directory DIR, returns a list whose elements are (GEM-AND-VERSION . PATH)
naming all gems in 'DIR/gems' and 'DIR/bundler/gems'."
  (-map (lambda (path) (cons (f-filename path) path))
        (-mapcat #'f-directories (find-gem--gem-dirs-in dir))))

(defun find-gem--split-path (path)
  "Split FOO_PATH into individual directories."
  (s-split path-separator (s-chomp path) 'omit-nulls))

(defun find-gem--find-dir-containing (path filename)
  "From PATH, traverse upwards looking for a file named FILENAME. Returns the
expand path to the file, else NIL."
  (locate-dominating-file path filename))

(defun find-gem--ruby-version-path (path)
  "From PATH, traverse upwards looking for a .ruby-version file. Returns the
expanded path to the file, else NIL."
  (let ((dir (find-gem--find-dir-containing (f-expand path) ".ruby-version")))
    (when dir
      (f-join dir ".ruby-version"))))

;; Strategies
(defun find-gem-strategy-env ()
  "Uses $GEM_PATH or, if unset, $GEM_HOME to retrieve the gem path."
  (let ((path (or (getenv "GEM_PATH") (getenv "GEM_HOME"))))
    (when path (find-gem--split-path path))))

(defun find-gem-strategy-gem-env (&optional dir)
  "Uses the 'gem env' shell command to retrieve the gem path.
The command will be run with `default-directory' set to the first directory
above DIR containing a .ruby-version file, or DIR itself if none."
  (let* ((dir  (f-slash (f-expand (or dir default-directory))))
         (path (let ((default-directory (or (find-gem--ruby-version-path dir) dir)))
                 (shell-command-to-string "gem env gempath"))))
    (when path
      (find-gem--split-path path))))

(defun find-gem-list ()
  "Runs `find-gem-strategies' successively until one returns a list
specifying what directories to search for gems in. Returns a list of
cons pairs (GEM-AND-VERSION . PATH) specifying all gems located. Returns
nil if no strategy succeeded."
  (-mapcat #'find-gem--gems-in
           (run-hook-with-args-until-success 'find-gem-strategies)))

;;;###autoload
(defun find-gem ()
  "Runs `find-gem-strategies' successively until one returns a list
specifying what directories to search for gems in. Uses `ido-completing-read'
to choose a gem, and then uses `find-gem-action' to determine what to do
with the chosen gem."
  (interactive)
  (let* ((gems   (find-gem-list))
         (choice (funcall find-gem-completing-read "find-gem: " (mapcar #'car gems)))
         (entry  (and choice (assoc choice gems)))
         (dir    (and entry  (cdr entry))))
    (when dir
      (cond
       ((eq 'dired find-gem-action)
        (dired dir))

       ((eq 'find-file find-gem-action)
        (funcall find-gem-find-file-in-dir dir))

       ((functionp find-gem-action)
        (funcall find-gem-action dir))

       (t (message "Unknown find-gem-action: %s" find-gem-action))))))

(provide 'find-gem)
;;; find-gem.el ends here
