;;;; pages.lisp — the page layout, the building blocks, and the pages themselves.
;;;;
;;;; Every function here returns plain Lisp data (an HTML tree). Nothing is
;;;; printed until build.lisp calls HTML on the finished tree. That means you can
;;;; call any of these in the REPL and look at what comes back.

(in-package #:victor-site)

;;; ------------------------------------------------------------------
;;; Registering pages
;;; ------------------------------------------------------------------

(defvar *pages* (make-hash-table :test #'equal)
  "Maps an output file name (\"index.html\") to a function that returns its HTML tree.")

(defmacro defpage (path (&key title description) &body body)
  "Define a page written to PATH. Each BODY form is evaluated (at build time) and must
return an HTML tree, so quote literal HTML: '(:p \"hi\") or `(:p ,*name*).

Try (macroexpand-1 '(defpage \"x.html\" (:title \"X\") '(:p \"hi\"))) in the REPL
to see what this macro actually writes for you."
  `(setf (gethash ,path *pages*)
         (lambda ()
           (layout :title ,title
                   :description ,description
                   :body (list ,@body)))))

;;; ------------------------------------------------------------------
;;; Motion helpers
;;;
;;; The animation itself lives in static/style.css and static/motion.js.
;;; Lisp's only job is to *mark* elements:
;;;   data-reveal      -> "fade this in when it scrolls into view"
;;;   style="--i: 3"   -> "you're the 4th item, wait a little longer"
;;; ------------------------------------------------------------------

(defun stagger (i)
  "A CSS custom property telling the stylesheet this element's position in a sequence."
  (format nil "--i: ~d" i))

(defun numbered (list)
  "Pair each element with its index: (a b) -> ((0 a) (1 b))."
  (loop for item in list
        for i from 0
        collect (list i item)))

;;; ------------------------------------------------------------------
;;; Layout: the HTML shared by every page
;;; ------------------------------------------------------------------

(defparameter *font-url*
  "https://fonts.googleapis.com/css2?family=Geist:wght@400;500;600&family=Geist+Mono:wght@400;500&family=Literata:ital,wght@0,400;0,500;1,400&display=swap")

(defun site-header ()
  `(:header :class "site-header"
     (:div :class "page header-inner"
      (:a :class "wordmark" :href "#top" ,*name*)
      (:nav
       (:a :href "#about" "About")
       (:a :href "#work" "Work")
       (:a :href "#projects" "Projects")
       (:a :href "#contact" "Contact")))))

(defun layout (&key title description body)
  `(:html :lang "en"
     (:head
      (:meta :charset "utf-8")
      (:meta :name "viewport" :content "width=device-width, initial-scale=1")
      (:title ,title)
      ,(when description
         `(:meta :name "description" :content ,description))
      (:link :rel "preconnect" :href "https://fonts.googleapis.com")
      (:link :rel "preconnect" :href "https://fonts.gstatic.com" :crossorigin t)
      (:link :rel "stylesheet" :href ,*font-url*)
      (:link :rel "stylesheet" :href "style.css")
      ;; defer = download now, run after the HTML is parsed.
      (:script :src "motion.js" :defer t))
     (:body :id "top"
      ,(site-header)
      (:main :class "page" ,@body)
      (:footer :class "page footer"
       (:span "© " ,*name*)
       (:span "Built with " (:a :href "https://lisp-lang.org" "Common Lisp")
              " and a little CSS")))))

;;; ------------------------------------------------------------------
;;; Building blocks
;;; ------------------------------------------------------------------

(defun section (id number heading &rest content)
  "A page section with a numbered label, e.g. 01 — About."
  `(:section :id ,id :class "section"
     (:h2 :class "label" :data-reveal t
      (:span :class "label-num" ,(format nil "~2,'0d" number))
      ,heading)
     ,@content))

(defun link-list ()
  `(:ul :class "links"
     ,@(loop for (label url) in *links*
             when url
               collect `(:li (:a :class "pill" :href ,url ,label)))))

(defun terminal ()
  "The animated REPL window. The full text is already in the HTML, so the page
makes sense even with JavaScript off; motion.js just replays it."
  `(:figure :class "terminal" :data-terminal t :data-reveal t :style ,(stagger 4)
     (:div :class "terminal-bar"
      (:span :class "dots" (:i) (:i) (:i))
      (:span :class "terminal-title" "sbcl — victor")
      (:button :class "terminal-toggle" :type "button" :data-terminal-toggle t
       :aria-label "Pause animation" "Pause"))
     (:pre :class "terminal-body" :aria-hidden "true"
      ,@(loop for (kind text) in *repl*
              collect `(:span :class ,(format nil "line ~(~a~)" kind)
                         ,(when (eq kind :in) '(:span :class "prompt" "CL-USER> "))
                         (:span :class "text" ,text))))))

(defun hero ()
  `(:div :class "hero"
     (:p :class "eyebrow" :data-reveal t :style ,(stagger 0) ,*eyebrow*)
     (:h1 :data-reveal t :style ,(stagger 1) ,@*headline*)
     (:p :class "intro" :data-reveal t :style ,(stagger 2) ,*intro*)
     (:div :data-reveal t :style ,(stagger 3) ,(link-list))
     ,(terminal)))

(defun timeline (items)
  "Experience or education as a vertical timeline. The line draws itself and the
entries arrive one after another (that's what the index in STAGGER is for)."
  `(:ol :class "timeline" :data-reveal t
     ,@(loop for (i item) in (numbered items)
             collect
             (destructuring-bind (&key role org place dates summary) item
               `(:li :class "entry" :style ,(stagger i)
                  (:span :class "dot")
                  (:div :class "entry-head"
                   (:h3 ,role)
                   (:span :class "dates" ,dates))
                  (:p :class "meta" ,org ,(when place (list " · " place)))
                  ,(when summary `(:p ,summary)))))))

(defun project-card (i project)
  (destructuring-bind (&key name url summary tags) project
    `(:li :class "card" :data-reveal t :style ,(stagger i)
       (:h3 ,(if url `(:a :href ,url ,name (:span :class "arrow" " ↗")) name))
       (:p ,summary)
       (:ul :class "tags"
        ,@(mapcar (lambda (tag) `(:li ,tag)) tags)))))

;;; ------------------------------------------------------------------
;;; Pages
;;; ------------------------------------------------------------------

(defpage "index.html" (:title *name* :description *intro*)
  (hero)
  (section "about" 1 "About"
           `(:div :class "prose" :data-reveal t
              ,@(mapcar (lambda (paragraph) `(:p ,paragraph)) *about*)))
  (section "work" 2 "Experience"
           (timeline *experience*))
  (section "projects" 3 "Projects"
           `(:ul :class "cards"
              ,@(loop for (i project) in (numbered *projects*)
                      collect (project-card i project))))
  (section "education" 4 "Education"
           (timeline *education*))
  (section "contact" 5 "Contact"
           `(:div :class "contact" :data-reveal t
              (:p :class "contact-line" ,*contact-line*)
              ,(link-list))))

(defpage "404.html" (:title "Not found")
  `(:div :class "hero"
     (:p :class "eyebrow" "404")
     (:h1 "Nothing " (:em "here") ".")
     (:p :class "intro" (:a :href "/" "Back home →"))))
