;;;; build.lisp — writes every page plus the static/ folder into public/.

(in-package #:victor-site)

(defun project-root ()
  (asdf:system-source-directory "victor-site"))

(defun output-path (name)
  (merge-pathnames name (merge-pathnames "public/" (project-root))))

(defun write-file (path string)
  (ensure-directories-exist path)
  (with-open-file (out path :direction :output
                            :if-exists :supersede
                            :external-format :utf-8)
    (write-string string out)))

(defun copy-file (from to)
  "Byte-for-byte copy, so images and PDFs survive too."
  (ensure-directories-exist to)
  (with-open-file (in from :element-type '(unsigned-byte 8))
    (with-open-file (out to :direction :output
                            :if-exists :supersede
                            :element-type '(unsigned-byte 8))
      (let ((buffer (make-array 8192 :element-type '(unsigned-byte 8))))
        (loop for n = (read-sequence buffer in)
              while (plusp n)
              do (write-sequence buffer out :end n))))))

(defun build ()
  "Generate the whole site into public/. Call this from the REPL after every change."
  ;; Start from an empty public/, so a page you renamed or removed doesn't linger.
  ;; :validate is a safety net: delete only a folder named "public" that sits inside
  ;; this project. :if-does-not-exist :ignore makes the very first build fine.
  (let ((public (output-path "")))
    (uiop:delete-directory-tree public
                                :validate (lambda (dir)
                                            (and (equal (car (last (pathname-directory dir))) "public")
                                                 (uiop:subpathp dir (project-root))))
                                :if-does-not-exist :ignore))
  (maphash (lambda (path page)
             (write-file (output-path path) (html (funcall page))))
           *pages*)
  (let ((static (merge-pathnames "static/" (project-root))))
    (dolist (file (directory (merge-pathnames "**/*.*" static)))
      (unless (uiop:directory-pathname-p file)
        (copy-file file (output-path (enough-namestring file static))))))
  (when *domain*
    (write-file (output-path "CNAME") *domain*))
  (format t "~&Built ~d pages into ~a~%"
          (hash-table-count *pages*) (namestring (output-path "")))
  t)
