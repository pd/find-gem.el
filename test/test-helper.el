(require 'f)
(require 'dash)
(require 'mocker)

(add-to-list 'load-path (f-expand ".." (f-dirname load-file-name)))
(require 'find-gem)

(defvar fgt/sandbox-root
  (f-expand "sandbox" (f-dirname (f-this-file))))

(defun sandbox-path (path)
  (f-expand path fgt/sandbox-root))

(defmacro from-dir (dir &rest body)
  (declare (indent 1))
  `(let ((default-directory (f-expand ,dir)))
     ,@body))

(defmacro with-env (name value &rest body)
  (declare (indent 2))
  `(let ((original-value (getenv ,name)))
     (unwind-protect
         (progn
           (setenv ,name ,value)
           ,@body)
       (setenv ,name original-value))))

(defmacro with-sandbox (&rest body)
  `(from-dir fgt/sandbox-root
     (when (f-dir? fgt/sandbox-root)
       (f-delete fgt/sandbox-root :force))
     (f-mkdir fgt/sandbox-root)
     ,@body))
