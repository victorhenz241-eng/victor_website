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

(defmacro defpage (path (&key title description base) &body body)
  "Define a page written to PATH. Each BODY form is evaluated (at build time) and must
return an HTML tree, so quote literal HTML: '(:p \"hi\") or `(:p ,*name*).
BASE is only for pages that need absolute links (the 404 page); see LAYOUT.

Try (macroexpand-1 '(defpage \"x.html\" (:title \"X\") '(:p \"hi\"))) in the REPL
to see what this macro actually writes for you."
  `(setf (gethash ,path *pages*)
         (lambda ()
           (layout :title ,title
                   :description ,description
                   :base ,base
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

(defun site-header (home)
  ;; HOME is the address of the home page: "./" on normal pages.
  `(:header :class "site-header"
     (:div :class "page header-inner"
      ;; "./#about" instead of "#about": from a project page, "#about" would look
      ;; for an #about on *that* page. "./" always means the home page.
      (:a :class "wordmark" :href ,home ,*name*)
      (:nav
       (:a :href ,(format nil "~a#about" home) "About")
       (:a :href ,(format nil "~a#work" home) "Work")
       (:a :href ,(format nil "~a#projects" home) "Projects")
       (:a :href ,(format nil "~a#contact" home) "Contact")))))

(defun layout (&key title description base body)
  "The HTML shared by every page. BASE is NIL for normal pages, which keeps every
link relative (\"style.css\"), so the site works at any address. Given a BASE like
\"/victor_website/\", links become absolute (\"/victor_website/style.css\")."
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
      ;; ~@[...~] in FORMAT prints its contents only when the argument isn't NIL.
      (:link :rel "stylesheet" :href ,(format nil "~@[~a~]style.css" base))
      ;; defer = download now, run after the HTML is parsed.
      (:script :src ,(format nil "~@[~a~]motion.js" base) :defer t))
     (:body :id "top"
      ,(site-header (or base "./"))
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

(defun case-study-path (slug)
  "The file a project's page is written to: \"internship-radar\" -> \"internship-radar.html\"."
  (format nil "~a.html" slug))

(defun project-card (i project)
  ;; &allow-other-keys: the plist also has :stats, :sections... that the card ignores.
  (destructuring-bind (&key name slug url summary tags &allow-other-keys) project
    `(:li :class "card" :data-reveal t :style ,(stagger i)
       (:h3 ,(cond (slug `(:a :href ,(case-study-path slug) ,name (:span :class "arrow" " →")))
                   (url `(:a :href ,url ,name (:span :class "arrow" " ↗")))
                   (t name)))
       (:p ,summary)
       (:ul :class "tags"
        ,@(mapcar (lambda (tag) `(:li ,tag)) tags)))))

(defun case-study (project)
  "A full page for one project: a header with its numbers and links, then one
numbered section per part of the story. Returns a list of trees, one per block."
  (destructuring-bind (&key name summary tags links stats sections &allow-other-keys) project
    `((:div :class "hero case-hero"
        (:p :class "eyebrow" :data-reveal t :style ,(stagger 0)
         (:a :class "back" :href "./#projects" "← All work"))
        (:h1 :data-reveal t :style ,(stagger 1) ,name)
        (:p :class "intro" :data-reveal t :style ,(stagger 2) ,summary)
        (:div :data-reveal t :style ,(stagger 3)
         (:ul :class "tags" ,@(mapcar (lambda (tag) `(:li ,tag)) tags))
         (:ul :class "links"
          ,@(loop for (label url) in links
                  collect `(:li (:a :class "pill" :href ,url ,label " ↗")))))
        (:ul :class "stats" :data-reveal t :style ,(stagger 4)
         ,@(loop for (value label) in stats
                 collect `(:li (:strong ,value) (:span ,label)))))
      ;; (heading . paragraphs) splits ("How it works" "p1" "p2") into the
      ;; first element and the rest of the list.
      ,@(loop for (heading . paragraphs) in sections
              for n from 1
              collect (section (format nil "part-~d" n) n heading
                               `(:div :class "prose" :data-reveal t
                                  ,@(mapcar (lambda (p) `(:p ,p)) paragraphs)))))))

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

;;; One page per project that has a :slug.
;;;
;;; MAPC, not DOLIST: DOLIST reuses one variable, so every page's stored lambda would
;;; see the *last* project. Each MAPC call gets its own fresh PROJECT to remember.

(mapc (lambda (project)
        (let ((slug (getf project :slug)))
          (when slug
            (defpage (case-study-path slug) (:title (getf project :name)
                                             :description (getf project :summary))
              (case-study project)))))
      *projects*)

;;; GitHub Pages serves 404.html for *any* missing address, even a deep one like
;;; /victor_website/a/b. From there a relative link such as "style.css" would point
;;; to /victor_website/a/style.css, which doesn't exist, so this one page uses
;;; absolute links that start with *base-path* (see content.lisp).

(defpage "404.html" (:title "Not found" :base *base-path*)
  `(:div :class "hero"
     (:p :class "eyebrow" "404")
     (:h1 "Nothing " (:em "here") ".")
     (:p :class "intro" (:a :href ,*base-path* "Back home →"))))
