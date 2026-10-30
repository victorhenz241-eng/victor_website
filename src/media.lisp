;;;; media.lisp — photos and videos, only when the file really exists.
;;;;
;;;; content.lisp names media files ("media/portrait.jpg"). Before the build
;;;; writes an <img> or a <video>, it checks the file is in static/ (PROBE-FILE).
;;;; No file, no tag: the page never shows a broken image, and it never shows a
;;;; grey placeholder pretending to be a picture. So the site is "true by
;;;; construction": drop a file in static/media/, rebuild, and it appears.
;;;;
;;;; The build also opens each file and reads its width and height from the bytes.
;;;; With width and height on the tag, the browser reserves the right space before
;;;; the picture arrives, so the text below never jumps ("layout shift").
;;;;
;;;; The files themselves are made by scripts/prepare-media.sh (see README).

(in-package #:victor-site)

;;; ------------------------------------------------------------------
;;; Finding files
;;; ------------------------------------------------------------------

(defun static-path (file)
  "Where FILE sits in the static/ folder: \"media/x.jpg\" -> .../static/media/x.jpg."
  (merge-pathnames (concatenate 'string "static/" file) (project-root)))

(defun static-file-p (file)
  "True when FILE (relative to static/) exists. PROBE-FILE returns the file's full
name if it exists and NIL if it doesn't."
  (and file (probe-file (static-path file))))

(defun media-folder (folder &key (type "jpg"))
  "Every .TYPE file in static/FOLDER, sorted by name, as paths relative to static/
like \"media/cut-the-line/01.jpg\". An empty list if there are none (or no folder).
DIRECTORY lists the files matching a pattern; SORT with STRING< puts them in
alphabetical order, so name your files 01.jpg, 02.jpg... to choose the order."
  (let ((files (directory (merge-pathnames (format nil "*.~a" type) (static-path folder)))))
    (sort (mapcar (lambda (path) (format nil "~a~a.~a" folder (pathname-name path) type))
                  files)
          #'string<)))

(defun read-bytes (path &optional limit)
  "The bytes of the file at PATH (the first LIMIT of them, if given) as a vector of
numbers from 0 to 255. :ELEMENT-TYPE '(UNSIGNED-BYTE 8) opens the file as bytes
instead of characters."
  (with-open-file (in path :element-type '(unsigned-byte 8))
    (let* ((n (if limit (min limit (file-length in)) (file-length in)))
           (bytes (make-array n :element-type '(unsigned-byte 8))))
      (read-sequence bytes in)
      bytes)))

(defun u16 (bytes i)
  "The 2 bytes at I as one number, biggest byte first (\"big-endian\")."
  (if (<= (+ i 2) (length bytes))
      (logior (ash (aref bytes i) 8) (aref bytes (1+ i)))
      0))

(defun u32 (bytes i)
  "The 4 bytes at I as one number, biggest byte first."
  (if (and (>= i 0) (<= (+ i 4) (length bytes)))
      (logior (ash (u16 bytes i) 16) (u16 bytes (+ i 2)))
      0))

;;; ------------------------------------------------------------------
;;; Reading the size of a picture from its bytes
;;; ------------------------------------------------------------------

(defun png-size (bytes)
  "A PNG file starts with an 8-byte signature, then the IHDR block: its length (4
bytes), its name \"IHDR\" (4 bytes), then the width and the height, 4 bytes each.
So the width is at byte 16 and the height at byte 20."
  (when (and (> (length bytes) 24)
             (= (aref bytes 0) #x89)
             (string= "IHDR" (map 'string #'code-char (subseq bytes 12 16))))
    (list (u32 bytes 16) (u32 bytes 20))))

(defun jpeg-size (bytes)
  "A JPEG file is a chain of \"segments\". Each one starts with the byte #xFF, then
a byte saying what it is (its \"marker\"), then its length (2 bytes, the length
bytes included). We hop from segment to segment until we reach a \"start of frame\"
(SOF) segment: markers #xC0 to #xCF, except #xC4, #xC8 and #xCC, which are other
things. Inside it: 1 byte of precision, then the height (2 bytes), then the width.
#xD8 is the very first marker (start of image) and has no length."
  (when (and (> (length bytes) 4) (= (aref bytes 0) #xFF) (= (aref bytes 1) #xD8))
    (loop with i = 2
          while (< (+ i 9) (length bytes))
          do (let ((marker (aref bytes (1+ i))))
               (cond ((/= (aref bytes i) #xFF) (return nil))      ; lost: give up
                     ((= marker #xFF) (incf i))                    ; padding byte
                     ((and (<= #xC0 marker #xCF) (not (member marker '(#xC4 #xC8 #xCC))))
                      (return (list (u16 bytes (+ i 7)) (u16 bytes (+ i 5)))))
                     (t (incf i (+ 2 (u16 bytes (+ i 2))))))))))

(defun image-size (file)
  "The (width height) of the picture FILE (relative to static/), or NIL if it isn't a
JPEG or a PNG we can read. Note: a photo straight off a phone may be stored sideways
with an \"orientation\" note; prepare-media.sh turns it upright, so the size we read
is the size you see."
  (let ((bytes (read-bytes (static-path file) 65536)))   ; the size is near the start
    (or (png-size bytes) (jpeg-size bytes))))

(defun mp4-size (path)
  "The (width height) of the video in the .mp4 file at PATH, or NIL if we can't
tell. An .mp4 file is a list of \"boxes\", each one starting with its size (4 bytes)
and a 4-letter type. The \"tkhd\" box (track header) ends with the track's width
and height, 4 bytes each, as \"16.16 fixed point\" numbers: the top 16 bits are the
whole part, so (ASH n -16) drops the fraction. A sound track's width is 0, so we
keep the first track whose width isn't.
A phone video filmed upright is often stored sideways, with a \"rotate me 90°\"
note: the 3x3 matrix just before the width. Its first number is 0 when the video
is turned a quarter turn, and then the width and height we see are swapped."
  (let ((bytes (read-bytes path))
        (tag (map 'vector #'char-code "tkhd")))
    (loop for at = (search tag bytes) then (search tag bytes :start2 (1+ at))
          while at
          do (let* ((start (- at 4))
                    (size (u32 bytes start))
                    (width (ash (u32 bytes (+ start size -8)) -16))
                    (height (ash (u32 bytes (+ start size -4)) -16))
                    (turned (zerop (u32 bytes (+ start size -44)))))
               (when (and (>= start 0) (>= size 84) (plusp width) (plusp height))
                 (return (if turned (list height width) (list width height))))))))

;;; ------------------------------------------------------------------
;;; The tags
;;; ------------------------------------------------------------------

(defun picture (file alt &key class eager)
  "An <img> for FILE, or NIL when the file isn't there.
  loading=\"lazy\"    the browser fetches it only when it comes near the screen.
  decoding=\"async\"  it may decode it off the main thread, so scrolling stays smooth.
EAGER is for a picture visible as soon as the page opens (\"above the fold\"):
there, lazy loading would only make it arrive later.
ALT describes the picture for people who can't see it. It's required here, on
purpose: a picture with no description is a bug."
  (check-type alt string)
  (when (static-file-p file)
    (destructuring-bind (&optional width height) (image-size file)
      `(:img :src ,file :alt ,alt :class ,class
             :width ,width :height ,height
             :loading ,(if eager "eager" "lazy")
             :decoding ,(if eager nil "async")))))

(defun video-size (file)
  "The (width height) of the video FILE (relative to static/), or a 16:9 guess."
  (or (mp4-size (static-path file)) '(1280 720)))

(defun poster-or-nil (poster)
  (when (static-file-p poster) poster))

(defun loop-video (file poster &key (class "card-video") alt (preload "metadata"))
  "A short silent loop (a project card), or NIL when FILE isn't there.
muted + playsinline: phones only let a video play by itself when it is silent and
plays inside the page (not full screen). There is no `autoplay` attribute:
motion.js plays it while it's on screen, and only when the visitor hasn't asked
for less motion. Otherwise it simply shows its POSTER (or its first frame).
ALT, when given, describes the video for screen readers (role=\"img\" + aria-label:
\"read it like a picture\"). Without ALT the video is decoration and is hidden
from them, like on a project card, whose title and text already say everything.
PRELOAD is how much the browser fetches before the video plays: \"metadata\" (the
default, a few kilobytes: its size and length) or \"none\" (nothing at all, for a
video far down the page that most visitors may never reach)."
  (when (static-file-p file)
    (destructuring-bind (width height) (video-size file)
      `(:video :class ,class :data-loop-video t
               :width ,width :height ,height
               :poster ,(poster-or-nil poster)
               :muted t :loop t :playsinline t :preload ,preload
               :role ,(when alt "img") :aria-label ,alt
               :aria-hidden ,(unless alt "true") :tabindex "-1"
         (:source :src ,file :type "video/mp4")))))

(defun sound-video (file poster title)
  "A video with sound (a case-study demo), or NIL when FILE isn't there. The
browser's own controls, and preload=\"none\": not a byte of the video is
downloaded until the visitor presses play. The POSTER shows meanwhile."
  (when (static-file-p file)
    (destructuring-bind (width height) (video-size file)
      `(:video :class "demo-video" :width ,width :height ,height
               :poster ,(poster-or-nil poster)
               :controls t :preload "none" :playsinline t
               :aria-label ,title
         (:source :src ,file :type "video/mp4")))))
