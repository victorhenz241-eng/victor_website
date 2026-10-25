;;;; source.lisp — the "view source" mode: show the real Lisp behind each section.
;;;;
;;;; Click "(λ) source" in the header and every section swaps its content for the
;;;; Lisp that produced it. Nothing here is retyped: at build time we open
;;;; src/content.lisp and src/pages.lisp *as text* and cut out the exact characters
;;;; of each form, comments and spacing included.
;;;;
;;;; How do we know where a form starts and ends? We let the Lisp reader do it:
;;;;   1. FILE-POSITION tells us where the stream is now  -> start of the form
;;;;   2. READ-PRESERVING-WHITESPACE reads one whole form, however deeply nested
;;;;   3. FILE-POSITION again                              -> end of the form
;;;; SUBSEQ between the two numbers is the form's original text. (We read from a
;;;; *string* stream: on a file stream FILE-POSITION counts bytes, and "é" is two
;;;; bytes in UTF-8, so the numbers wouldn't match the characters of the string.)
;;;;
;;;; Then a small tokenizer (HIGHLIGHT) colors the text, and SOURCE-PANEL wraps it
;;;; in a <figure>. pages.lisp puts that figure in a <template>, which the browser
;;;; never shows; static/source-view.js copies it onto the page when you ask.

(in-package #:victor-site)

;;; ------------------------------------------------------------------
;;; 1. Finding forms in a file
;;; ------------------------------------------------------------------

(defun source-text (name)
  "The whole text of src/NAME as one string, e.g. (source-text \"content.lisp\")."
  (uiop:read-file-string (merge-pathnames (concatenate 'string "src/" name) (project-root))
                         :external-format :utf-8))

(defun skip-blanks (stream)
  "Move STREAM past spaces, newlines and ; comments, so it sits on the next form's
first character. (READ would skip them too, but then the comment above a form
would end up inside our slice.) PEEK-CHAR looks at the next character without
taking it; with NIL NIL it returns NIL at the end instead of signalling an error."
  (loop for c = (peek-char nil stream nil nil)
        while c
        do (cond ((member c '(#\Space #\Tab #\Newline #\Return)) (read-char stream))
                 ((char= c #\;) (read-line stream nil))
                 (t (return)))))

(defun form-slices (text start)
  "Read forms from TEXT, beginning at index START, until the end of the text or a
closing paren. Returns a list of (form start end), START and END being indices
into TEXT. To slice the elements of a list, pass the index just after its \"(\"."
  ;; WITH-STANDARD-IO-SYNTAX resets the reader to its defaults; *READ-EVAL* NIL
  ;; forbids #.(...) tricks; *PACKAGE* makes symbols like *about* mean ours.
  (with-standard-io-syntax
    (let ((*package* (find-package '#:victor-site))
          (*read-eval* nil)
          (stream (make-string-input-stream text))
          (slices '()))
      (file-position stream start)                ; jump straight to START
      (loop
        (skip-blanks stream)
        (let ((c (peek-char nil stream nil nil)))
          (when (or (null c) (char= c #\)))
            (return (nreverse slices))))
        ;; READ-PRESERVING-WHITESPACE, not READ: plain READ may swallow the space
        ;; after the form, and our END would be one character too far.
        (let* ((from (file-position stream))
               (form (read-preserving-whitespace stream))
               (to (file-position stream)))
          (push (list form from to) slices))))))

(defun elements (text slice)
  "The slices of the elements inside the list that SLICE covers. Works for a
quoted list too: '(a b) starts with a quote, so we look for the first \"(\"."
  (form-slices text (1+ (position #\( text :start (second slice)))))

(defun find-slice (slices test)
  "The first (form start end) in SLICES whose form passes TEST."
  (find-if (lambda (slice) (funcall test (first slice))) slices))

(defun headed-by (operator &optional name)
  "A test for FIND-SLICE: is the form (OPERATOR NAME ...)? (headed-by 'defun 'hero)
matches (defun hero () ...). Without NAME, any (OPERATOR ...) matches."
  (lambda (form)
    (and (consp form)
         (eq (first form) operator)
         (or (null name) (equal (second form) name)))))

;;; ------------------------------------------------------------------
;;; 2. Chunks: a piece of a file, ready to show
;;; ------------------------------------------------------------------

(defun line-number (text index)
  "Which line of TEXT the character at INDEX is on, counting from 1."
  (1+ (count #\Newline text :end index)))

(defun dedent (text column)
  "A form cut out of the middle of a line loses the spaces before its first line,
but its other lines keep theirs. Remove COLUMN spaces from those other lines so
the form sits flush left, as it would in an editor."
  (with-output-to-string (out)
    (loop for (line . more) on (uiop:split-string text :separator '(#\Newline))
          for first = t then nil
          do (write-string (if first
                               line
                               (subseq line (min column
                                                 (or (position #\Space line :test-not #'char=)
                                                     (length line)))))
                           out)
             (when more (terpri out)))))

(defun chunk (file text start end &key role)
  "A plist describing the characters START..END of FILE (whose text is TEXT).
ROLE is a short word shown next to the file name: \"data\" or \"render\"."
  (let ((column (- start (1+ (or (position #\Newline text :end start :from-end t) -1)))))
    (list :file file
          :role role
          :from (line-number text start)
          :to (line-number text end)
          :text (dedent (subseq text start end) column))))

(defun content-chunks (&rest groups)
  "Chunks from src/content.lisp. Each group is a list of DEFPARAMETER names that sit
next to each other in the file; one chunk covers the first to the last, with any
blank lines and comments between them, exactly as written."
  (let* ((text (source-text "content.lisp"))
         (slices (form-slices text 0)))
    (loop for names in groups
          for first = (find-slice slices (headed-by 'defparameter (first names)))
          for last = (find-slice slices (headed-by 'defparameter (car (last names))))
          collect (chunk "src/content.lisp" text (second first) (third last) :role "data"))))

(defun pages-chunk (test)
  "One chunk from src/pages.lisp: the first top-level form passing TEST."
  (let* ((text (source-text "pages.lisp"))
         (slice (find-slice (form-slices text 0) test)))
    (chunk "src/pages.lisp" text (second slice) (third slice) :role "render")))

(defun home-call-chunk (id)
  "The SECTION call for section ID inside (defpage \"index.html\" ...)."
  (let* ((text (source-text "pages.lisp"))
         (page (find-slice (form-slices text 0) (headed-by 'defpage "index.html")))
         (call (find-slice (elements text page) (headed-by 'section id))))
    (chunk "src/pages.lisp" text (second call) (third call) :role "render")))

;;; ------------------------------------------------------------------
;;; 3. The tokenizer: text -> colored spans
;;;
;;; It walks the text one character at a time and decides what each run of
;;; characters is. It doesn't need to understand Lisp, only to recognise:
;;;   ; comment        "string"        :keyword        ( ) ' ` , #'
;;;   (operator        anything-else  (plain symbols, numbers)
;;; Every piece stays a Lisp string, so the renderer escapes it like any text.
;;; ------------------------------------------------------------------

(defun symbol-char-p (c)
  "Can C be part of a symbol? Anything but blanks and Lisp's special characters."
  (not (find c '(#\Space #\Tab #\Newline #\Return #\( #\) #\" #\; #\' #\` #\,))))

(defun highlight (text)
  "Split TEXT into a list of HTML nodes: plain strings, and (:span :class ...) for
the parts that get a color."
  (let ((nodes '())
        (plain (make-string-output-stream))   ; collects uncolored characters
        (i 0)
        (n (length text)))
    (labels ((flush ()                          ; LABELS = local helper functions
               (let ((s (get-output-stream-string plain)))
                 (when (plusp (length s)) (push s nodes))))
             (emit (class end)                  ; color TEXT[i..end) and move on
               (flush)
               (push `(:span :class ,class ,(subseq text i end)) nodes)
               (setf i end))
             (scan (test start)                 ; first index from START failing TEST
               (or (position-if-not test text :start start) n)))
      (loop while (< i n)
            do (let ((c (char text i)))
                 (cond
                   ((char= c #\;)
                    (emit "c-comment" (or (position #\Newline text :start i) n)))
                   ((char= c #\")
                    ;; Walk to the closing quote, hopping over \" escapes.
                    (let ((j (1+ i)))
                      (loop while (and (< j n) (char/= (char text j) #\"))
                            do (incf j (if (char= (char text j) #\\) 2 1)))
                      (emit "c-string" (min n (1+ j)))))
                   ((find c "()")
                    (emit "c-paren" (scan (lambda (x) (find x "()")) i)))
                   ((find c "'`")
                    (emit "c-paren" (1+ i)))
                   ((char= c #\,)                ; , or ,@
                    (emit "c-paren" (if (and (< (1+ i) n) (char= (char text (1+ i)) #\@))
                                        (+ i 2)
                                        (1+ i))))
                   ((and (char= c #\#) (< (1+ i) n) (char= (char text (1+ i)) #\'))
                    (emit "c-paren" (+ i 2)))   ; #'function
                   ((char= c #\:)
                    (emit "c-key" (scan #'symbol-char-p (1+ i))))
                   ((and (symbol-char-p c) (plusp i) (char= (char text (1- i)) #\())
                    ;; A symbol right after "(" is what the form *does*: defun, loop...
                    (emit "c-op" (scan #'symbol-char-p i)))
                   (t (write-char c plain) (incf i)))))
      (flush)
      (nreverse nodes))))

;;; ------------------------------------------------------------------
;;; 4. The panel
;;; ------------------------------------------------------------------

(defun source-panel (label chunks &key scroll)
  "A <figure> showing CHUNKS one under the other, each with its file name and lines.
LABEL names it for screen readers. With SCROLL, any chunk longer than 30 lines is
capped at a fixed height; its <pre> then gets tabindex 0 so keyboard users can
focus it and scroll it with the arrow keys."
  `(:figure :class "source" :aria-label ,label
     ,@(loop for (i c) in (numbered chunks)
             collect
             (destructuring-bind (&key file role from to text) c
               `(:div :class "source-chunk" :style ,(stagger i)
                  (:p :class "source-meta"
                   (:span :class "source-role" ,role)
                   (:span :class "source-file" ,file)
                   (:span :class "source-lines"
                    ,(if (= from to)
                         (format nil "line ~d" from)
                         (format nil "lines ~d–~d" from to))))
                  ,(let ((long (and scroll (> (- to from) 30))))
                     `(:pre :class ,(when long "source-scroll") :tabindex ,(when long "0")
                        (:code ,@(highlight text)))))))))

;;; ------------------------------------------------------------------
;;; 5. Which source goes with which part of the page
;;; ------------------------------------------------------------------

(defun hero-source ()
  (source-panel "Lisp source of the introduction"
                (append (content-chunks '(*eyebrow* *intro*) '(*links* *repl*))
                        (list (pages-chunk (headed-by 'defun 'hero))))))

(defun home-section-source (id)
  "The source panel for the home page section ID, or NIL if it has none."
  (flet ((panel (label groups &rest options)
           (apply #'source-panel
                  (format nil "Lisp source of the ~a section" label)
                  (append (apply #'content-chunks groups) (list (home-call-chunk id)))
                  options)))
    ;; STRING= compares text; CASE can't, because it compares with EQL.
    (cond ((string= id "about")     (panel "About" '((*about*))))
          ((string= id "work")      (panel "Experience" '((*experience*))))
          ((string= id "projects")  (panel "Projects" '((*projects*)) :scroll t))
          ((string= id "education") (panel "Education" '((*education*))))
          ((string= id "contact")   (panel "Contact" '((*links*) (*contact-line*)))))))

(defun case-study-sources (project)
  "For a project page: (values hero-panel part-panels). The hero shows the start of
the project's plist in *projects*, up to its :sections; each numbered part shows
its own (heading paragraph ...) list from :sections."
  (let* ((text (source-text "content.lisp"))
         (param (find-slice (form-slices text 0) (headed-by 'defparameter '*projects*)))
         ;; The 3rd element of (defparameter *projects* '(...) "doc") is the list.
         (plist (find-slice (elements text (third (elements text param)))
                            (lambda (form) (equal (getf form :name) (getf project :name)))))
         (fields (elements text plist))
         ;; In a plist, the value comes right after its key.
         (key (position :sections fields :key #'first))
         (sections (nth (1+ key) fields)))
    (values
     (source-panel "Lisp source of this project's header"
                   (list (chunk "src/content.lisp" text
                                (second plist) (third (nth (1- key) fields)) :role "data")
                         (pages-chunk (headed-by 'mapc))))
     (loop for part in (elements text sections)
           for n from 1
           collect (source-panel (format nil "Lisp source of part ~d" n)
                                 (list (chunk "src/content.lisp" text
                                              (second part) (third part) :role "data")))))))

(defun with-source (panel &rest content)
  "Wrap CONTENT so source-view.js can swap it with PANEL. The panel goes in a
<template>: the browser parses it but never displays it, and screen readers and
search engines skip it. Without JavaScript the page is exactly as before.
With no PANEL, CONTENT is returned untouched."
  (if panel
      `((:div :class "view-rendered" ,@content)
        (:template :class "view-source" ,panel))
      content))
