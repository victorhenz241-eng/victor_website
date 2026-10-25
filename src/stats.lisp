;;;; stats.lisp — the numbers on the footer's last line, measured while the site builds.
;;;;
;;;; Nothing here is typed in by hand. Every number is measured at build time:
;;;;   - the Lisp version     asked from the Lisp that runs the build
;;;;   - lines of Lisp        counted in src/*.lisp (this file included)
;;;;   - render time          timed around rendering every page (see BUILD)
;;;;   - this page's size     the byte count of the very file it's written in
;;;;   - the build date       today's date, in UTC
;;;; Render time and page size have a catch: they are *inside* the pages they
;;;; describe, so they can only be known once those pages are finished. The pages
;;;; get a marker in their place, and BUILD fills the markers in afterwards.

(in-package #:victor-site)

(defvar *build-stats* nil
  "A plist of the numbers that are known before rendering starts, like
(:lisp \"SBCL 2.6.8\" :lines 1312 :pages 4 :date \"2026-10-25\").
BUILD binds it while it renders. Otherwise it is NIL, and LAYOUT leaves the stats
line out (handy when you call a page function by hand in the REPL).
DEFVAR makes it a *special* (dynamic) variable: a LET around a function call gives
it a new value for everything that call does, then puts the old value back.")

;;; The markers. They are HTML comments, put in the page with (:raw ...).
;;; Normal text always goes through ESCAPE, which turns "<" into "&lt;", so no text
;;; on the site can ever contain a real "<!--". The markers can't clash with anything.
(defparameter *render-ms-marker* "<!--render-ms-->")
(defparameter *page-bytes-marker* "<!--page-bytes-->")

;;; ------------------------------------------------------------------
;;; Measuring
;;; ------------------------------------------------------------------

(defun lisp-version ()
  "The Lisp running this build, e.g. \"SBCL 2.6.8\"."
  (format nil "~a ~a" (lisp-implementation-type) (lisp-implementation-version)))

(defun lines-of-lisp ()
  "How many lines the src/*.lisp files have, all together."
  (loop for file in (directory (merge-pathnames "src/*.lisp" (project-root)))
        sum (length (uiop:read-file-lines file :external-format :utf-8))))

(defun today-utc ()
  "Today's date in UTC as an ISO date, e.g. \"2026-10-25\".
DECODE-UNIVERSAL-TIME splits a time into several values (second, minute, hour,
day, month, year...). Its second argument is the time zone: 0 means UTC."
  (multiple-value-bind (second minute hour day month year)
      (decode-universal-time (get-universal-time) 0)
    (declare (ignore second minute hour))   ; "I don't need these", no warning
    (format nil "~d-~2,'0d-~2,'0d" year month day)))

(defun milliseconds-since (start)
  "Milliseconds since START, a value returned by GET-INTERNAL-REAL-TIME.
That clock counts in \"internal time units\", whose size depends on the Lisp.
INTERNAL-TIME-UNITS-PER-SECOND says how many make one second (1,000,000 in SBCL),
so units x 1000 / units-per-second = milliseconds. ROUND with two arguments
divides and rounds to the nearest whole number."
  (round (* 1000 (- (get-internal-real-time) start))
         internal-time-units-per-second))

(defun utf-8-length (string)
  "How many bytes STRING takes once saved as UTF-8, the encoding WRITE-FILE uses.
LENGTH counts characters, not bytes: \"é\" is 1 character but 2 bytes."
  (loop for c across string
        sum (let ((code (char-code c)))
              (cond ((< code #x80) 1)       ; plain ASCII: a-z, digits, < > ...
                    ((< code #x800) 2)      ; é, ×, ·, λ
                    ((< code #x10000) 3)    ; →, ⌘, €
                    (t 4)))))               ; emoji and other rare characters

;;; ------------------------------------------------------------------
;;; Filling in the markers
;;; ------------------------------------------------------------------

(defun fill-in (page marker value)
  "PAGE with its MARKER replaced by the string VALUE. Each marker appears once."
  (let ((at (search marker page)))
    (if at
        (concatenate 'string (subseq page 0 at) value (subseq page (+ at (length marker))))
        page)))

(defun fill-in-page-size (page)
  "PAGE with its size marker replaced by the size, in bytes, of the result.
The chicken-and-egg problem: writing the number changes the size. \"19,482\" is
shorter than the marker it replaces, and a 5-digit number is shorter than a
6-digit one. So we guess, measure, and guess again with what we measured:
  guess 0       -> with \"0\" written in, the page is, say, 19,477 bytes
  guess 19,477  -> with \"19,477\" written in, it is 19,482 bytes
  guess 19,482  -> still 19,482 bytes: the number now describes itself. Done.
It settles in two or three rounds, since only the number of digits matters."
  (loop for round from 1 to 10
        for guess = 0 then size
        for filled = (fill-in page *page-bytes-marker* (format nil "~:d" guess))
        for size = (utf-8-length filled)
        when (= size guess)
          do (return filled)
        finally (error "The page size didn't settle after 10 rounds.")))
