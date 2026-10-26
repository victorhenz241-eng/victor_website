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

;;; Private comments. Everything we slice is published, comments included. So a
;;; comment that starts with "private:" -- ;; private: ... or a trailing
;;; ; private: ... -- is a note for the author only: we cut it out here.
;;; A whole-line private comment takes its line with it; a trailing one only
;;; takes itself (and the spaces before it). The line numbers shown still name
;;; the real lines of the file, so the panel can be a few lines shorter.

(defun private-comment-p (text i)
  "Does the ; comment starting at index I of TEXT begin with \"private:\"?"
  (let ((j (or (position-if-not (lambda (c) (member c '(#\; #\Space #\Tab))) text :start i)
               (length text))))
    (and (<= (+ j 8) (length text))
         (string-equal "private:" text :start2 j :end2 (+ j 8)))))

(defun strip-private-comments (text)
  "TEXT without its private: comments. It walks the text like the reader would,
so a ; inside a \"string\", a |symbol| or a #\\; character is not a comment."
  ;; MAKE-STRING-OUTPUT-STREAM, not WITH-OUTPUT-TO-STRING: we need to take back
  ;; what we wrote so far (GET-OUTPUT-STREAM-STRING) to trim its spaces.
  (let ((out (make-string-output-stream)) (i 0) (n (length text)))
    (loop while (< i n)
          do (let ((c (char text i)))
               (cond
                 ;; A string or |symbol|: copy it whole, \ escapes included.
                 ((find c "\"|")
                  (let ((j (1+ i)))
                    (loop while (and (< j n) (char/= (char text j) c))
                          do (incf j (if (char= (char text j) #\\) 2 1)))
                    (setf j (min n (1+ j)))
                    (write-string text out :start i :end j)
                    (setf i j)))
                 ;; #\x is one character, whatever x is (even ; or ").
                 ((and (char= c #\#) (< (+ i 2) n) (char= (char text (1+ i)) #\\))
                  (write-string text out :start i :end (+ i 3))
                  (incf i 3))
                 ((char= c #\;)
                  (let ((eol (or (position #\Newline text :start i) n)))
                    (if (not (private-comment-p text i))
                        (write-string text out :start i :end eol)
                        ;; Drop the spaces we already wrote before the comment.
                        (let* ((so-far (get-output-stream-string out))
                               (kept (string-right-trim '(#\Space #\Tab) so-far))
                               (line-start (1+ (or (position #\Newline kept :from-end t) -1))))
                          (write-string kept out)
                          ;; Nothing left on the line: drop the line and its newline.
                          (when (and (= line-start (length kept)) (< eol n))
                            (incf eol))))
                    (setf i eol)))
                 (t (write-char c out) (incf i)))))
    (get-output-stream-string out)))

(defun chunk (file text start end &key role)
  "A plist describing the characters START..END of FILE (whose text is TEXT).
ROLE is a short word shown next to the file name: \"data\" or \"render\".
Private comments (see STRIP-PRIVATE-COMMENTS) never make it into the chunk."
  (let ((column (- start (1+ (or (position #\Newline text :end start :from-end t) -1)))))
    (list :file file
          :role role
          :from (line-number text start)
          :to (line-number text end)
          :text (dedent (strip-private-comments (subseq text start end)) column))))

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
                   ((and (char= c #\#) (< (+ i 2) n) (char= (char text (1+ i)) #\\))
                    ;; #\; or #\( is one character, not a comment or a paren.
                    (write-string text plain :start i :end (+ i 3))
                    (incf i 3))
                   ((char= c #\:)
                    (emit "c-key" (scan #'symbol-char-p (1+ i))))
                   ((and (symbol-char-p c) (plusp i) (char= (char text (1- i)) #\())
                    ;; A symbol right after "(" is what the form *does*: defun, loop...
                    (emit "c-op" (scan #'symbol-char-p i)))
                   (t (write-char c plain) (incf i)))))
      (flush)
      (nreverse nodes))))

;;; Long lines wrap on a phone. In a <pre>, the wrapped part would restart at the
;;; left edge, under the parens, and the shape of the code would be lost. So each
;;; line becomes its own block <span>, which the CSS gives a "hanging indent": the
;;; wrapped part lines up two characters further in than the line's own start.

(defun split-lines (nodes)
  "Cut the NODES that HIGHLIGHT returns into lines: a list with one list of nodes
per line of text. A string or a colored span that runs over several lines (like a
docstring) is cut at each newline, and every piece keeps its color."
  (let ((lines '())
        (line '()))
    (dolist (node nodes)
      ;; A node is either "plain text" or (:span :class "c-string" "text").
      (multiple-value-bind (text class)
          (if (stringp node) (values node nil) (values (fourth node) (third node)))
        (loop for (piece . more) on (uiop:split-string text :separator '(#\Newline))
              do (when (plusp (length piece))
                   (push (if class `(:span :class ,class ,piece) piece) line))
                 (when more              ; a newline came right after this piece
                   (push (nreverse line) lines)
                   (setf line '())))))
    (push (nreverse line) lines)
    (nreverse lines)))

(defun code-line (nodes)
  "One line of code as a <span> (style.css makes it a block). --n is how many
spaces the line starts with; the CSS turns it into the hanging indent. An empty
line gets one space, or its block would have no height."
  (let* ((start (first nodes))
         (n (if (stringp start)
                (or (position #\Space start :test-not #'char=) (length start))
                0)))
    `(:span :style ,(when (plusp n) (format nil "--n:~d" n))
       ,@(or nodes '(" ")))))

;;; ------------------------------------------------------------------
;;; 4. The panel
;;; ------------------------------------------------------------------

(defun source-panel (label chunks &key scroll heading)
  "A <figure> showing CHUNKS one under the other, each with its file name and lines.
LABEL names it for screen readers. With SCROLL, any chunk longer than 30 lines is
capped at a fixed height; its <pre> then gets tabindex 0 so keyboard users can
focus it and scroll it with the arrow keys.
HEADING is for the hero's panel: in source mode the page's real <h1> is hidden
with the rest of the hero, so the panel brings its own, visible only to screen
readers (.sr-only). HEADING is a list of nodes, like *HEADLINE*."
  `(:figure :class "source" :aria-label ,label
     ,@(when heading `((:h1 :class "sr-only" ,@heading)))
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
                        (:code ,@(mapcar #'code-line (split-lines (highlight text)))))))))))

;;; ------------------------------------------------------------------
;;; 5. Which source goes with which part of the page
;;; ------------------------------------------------------------------

(defun hero-source ()
  (source-panel "Lisp source of the introduction"
                (append (content-chunks '(*eyebrow* *intro*) '(*links* *repl*))
                        (list (pages-chunk (headed-by 'defun 'hero))))
                :heading *headline*))

(defun home-section-source (id)
  "The source panel for the home page section ID, or NIL if it has none."
  (flet ((panel (label groups &rest options)
           (apply #'source-panel
                  (format nil "Lisp source of the ~a section" label)
                  (append (apply #'content-chunks groups) (list (home-call-chunk id)))
                  options)))
    ;; STRING= compares text; CASE can't, because it compares with EQL.
    (cond ((string= id "about")     (panel "About" '((*about* *about-photo*))))
          ((string= id "work")      (panel "Experience" '((*experience*))))
          ((string= id "projects")  (panel "Projects" '((*projects-intro* *projects*)) :scroll t))
          ((string= id "education") (panel "Education" '((*education*))))
          ((string= id "contact")   (panel "Contact" '((*links*) (*contact-line*)))))))

(defun case-study-sources (project)
  "For a project page: (values hero-panel part-panels diagram-panel funnel-panel
gallery-panel). The hero shows the start of the project's plist in *projects*, up
to its :sections; each numbered part shows its own (heading paragraph ...) list
from :sections; the diagram, the funnel and the photos show their own data, then
the function that draws them (see FIELD-SOURCE)."
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
                         (pages-chunk (headed-by 'mapc)))
                   :heading (list (getf project :name)))
     ;; Each part is named by its heading, the first string of its list.
     (loop for part in (elements text sections)
           collect (source-panel (format nil "Lisp source of the part “~a”" (first (first part)))
                                 (list (chunk "src/content.lisp" text
                                              (second part) (third part) :role "data"))))
     (field-source text fields :diagram 'diagram-svg "the diagram")
     (field-source text fields :funnel 'funnel "the funnel")
     (field-source text fields :gallery 'gallery "the photos"))))

(defun field-source (text fields key renderer label)
  "The source panel of one field of a project, or NIL if the project doesn't have
KEY: its data in content.lisp, comments above it included, then RENDERER, the
function in pages.lisp that draws it."
  (let ((at (position key fields :key #'first)))
    (when at
      ;; The comment above the key sits between the previous value and the key.
      ;; It starts at the first character after that value that isn't a blank.
      (let ((start (position-if-not (lambda (c) (member c '(#\Space #\Tab #\Newline)))
                                    text :start (third (nth (1- at) fields))))
            (value (nth (1+ at) fields)))
        (source-panel (format nil "Lisp source of ~a" label)
                      (list (chunk "src/content.lisp" text start (third value) :role "data")
                            (pages-chunk (headed-by 'defun renderer)))
                      :scroll t)))))

(defun with-source (panel &rest content)
  "Wrap CONTENT so source-view.js can swap it with PANEL. The panel goes in a
<template>: the browser parses it but never displays it, and screen readers and
search engines skip it. Without JavaScript the page is exactly as before.
With no PANEL, CONTENT is returned untouched."
  (if panel
      `((:div :class "view-rendered" ,@content)
        (:template :class "view-source" ,panel))
      content))
