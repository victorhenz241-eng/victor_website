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

(defmacro defpage (path (&key title description base home-page) &body body)
  "Define a page written to PATH. Each BODY form is evaluated (at build time) and must
return an HTML tree, so quote literal HTML: '(:p \"hi\") or `(:p ,*name*).
BASE is only for pages that need absolute links (the 404 page); see LAYOUT.
HOME-PAGE is T only for index.html, so its section links can stay on the page.

Try (macroexpand-1 '(defpage \"x.html\" (:title \"X\") '(:p \"hi\"))) in the REPL
to see what this macro actually writes for you."
  `(setf (gethash ,path *pages*)
         (lambda ()
           (layout :title ,title
                   :description ,description
                   :base ,base
                   :home-page ,home-page
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

(defparameter *home-sections*
  '(("about" "About")
    ("work" "Work" "experience")   ; an optional 3rd item: extra search words
    ("projects" "Projects")
    ("education" "Education")
    ;; Keep Contact last: on phones the CSS hides every nav link but the last one.
    ("contact" "Contact"))
  "(id label [search-words]) for each section of the home page. Two things are built from this
one list: the links in the header and the \"Pages\" group of the command menu.
The ids must match the SECTION calls in the index.html page below.")

(defun home-link (home)
  "Where a \"go to the home page\" link points. HOME is the prefix that leads to the
home page (see LAYOUT). On the home page itself it is \"\", and an empty href would
reload the page, so we jump to the top of the page instead (<body id=\"top\">)."
  (if (equal home "") "#top" home))

(defun site-header (home)
  ;; HOME is the prefix that leads to the home page (see LAYOUT):
  ;;   ""         on the home page itself -> links like "#about" just scroll;
  ;;   "./"       on a project page       -> "./#about" goes back home first;
  ;;   a base path on the 404 page         -> "/victor_website/#about".
  `(:header :class "site-header"
     (:div :class "page header-inner"
      (:a :class "wordmark" :href ,(home-link home) ,*name*)
      (:div :class "header-end"
       ;; aria-label names this nav for screen readers, which list every landmark.
       (:nav :aria-label "Sections"
        ,@(loop for (id label) in *home-sections*
                collect `(:a :href ,(format nil "~a#~a" home id) ,label)))
       ,(source-toggle)
       ,(command-button)))))

(defun source-toggle ()
  "The \"(λ) source\" switch (see source.lisp). A <button> with aria-pressed is
a toggle button: screen readers say \"Source, toggle button, not pressed\".
Hidden until static/source-view.js shows it, and it stays hidden on pages with
nothing to show (the 404)."
  `(:button :type "button" :class "source-toggle" :hidden t
            :aria-pressed "false" :data-source-toggle t
            :title "Show the Lisp that generates this page"
     (:span :class "source-toggle-glyph" :aria-hidden "true"
      (:span :class "c-paren" "(") "λ" (:span :class "c-paren" ")"))
     (:span :class "source-toggle-text" "source")))

;;; ------------------------------------------------------------------
;;; The command menu (press ⌘K or Ctrl+K, or click "Search" in the header)
;;;
;;; Lisp writes every entry into the HTML at build time, from the same data as the
;;; rest of the site: add a project to content.lisp and it gets a command too.
;;; static/command-menu.js only opens the menu, filters it and moves the selection.
;;; ------------------------------------------------------------------

(defun command-button ()
  ;; `hidden` until command-menu.js removes it: without JavaScript the button
  ;; would do nothing, so it's better not to show it at all.
  ;; aria-keyshortcuts tells screen readers about the shortcut; the <kbd> chip
  ;; shows it to everyone else, so it's aria-hidden to avoid saying it twice.
  `(:button :type "button" :class "cmdk-button" :hidden t
            :aria-haspopup "dialog" :aria-controls "cmdk"
            :aria-keyshortcuts "Meta+K /"   ; command-menu.js swaps in Control+K off a Mac
            :data-cmdk-open t
     (:span :class "cmdk-button-text" "Search")
     (:kbd :aria-hidden "true" :data-cmdk-key t "⌘K")))

(defun link-hint (url)
  "A short, readable version of URL, shown in grey next to a command:
\"https://www.linkedin.com/in/x\" -> \"linkedin.com\", \"mailto:me@x.com\" -> \"me@x.com\".
Anything else (a relative link like \"cv.pdf\") is returned as it is."
  (let ((slashes (search "//" url)))
    (cond ((uiop:string-prefix-p "mailto:" url) (subseq url (length "mailto:")))
          (slashes
           ;; LET* (with a star) lets each variable use the ones defined above it.
           (let* ((start (+ slashes 2))
                  (start (if (uiop:string-prefix-p "www." (subseq url start))
                             (+ start 4)
                             start)))
             ;; POSITION returns NIL when there's no "/" after the host,
             ;; and (subseq url start nil) means "up to the end".
             (subseq url start (position #\/ url :start start))))
          (t url))))

(defun commands (home)
  "Every entry of the command menu, as a list of plists. HOME plays the same role
as in SITE-HEADER, so the links work from the home page, a project page and the 404."
  (append
   (list `(:group "Pages" :label "Home" :href ,(home-link home) :hint "top"))
   ;; A missing 3rd item just makes WORDS NIL.
   (loop for (id label words) in *home-sections*
         collect `(:group "Pages" :label ,label :keywords ,(when words (list words))
                   :href ,(format nil "~a#~a" home id) :hint ,(format nil "#~a" id)))
   ;; LOOP can name a value with FOR ... = and then test it with WHEN.
   (loop for project in *projects*
         for slug = (getf project :slug)
         when slug
           collect `(:group "Pages" :label ,(getf project :name)
                     :href ,(format nil "~a~a" home (case-study-path slug))
                     :hint "case study" :keywords ,(getf project :tags)))
   (loop for project in *projects*
         for url = (getf project :url)
         when url
           collect `(:group "Projects" :label ,(getf project :name)
                     :href ,url :hint ,(link-hint url) :keywords ,(getf project :tags)))
   (loop for (label url) in *links*
         when url
           collect `(:group "Links" :label ,label
                     :href ,url :hint ,(link-hint url)))
   ;; An action instead of a link: no :href, and command-menu.js runs it.
   ;; Only pages that have a source view get it. The 404 is the one page whose
   ;; HOME is the base path (see LAYOUT), and it has nothing to show.
   (unless (equal home *base-path*)
     (list '(:group "Actions" :label "Toggle source view" :action "toggle-source"
             :hint "(λ)" :keywords ("view source" "lisp" "code"))))))

(defun command-menu (home)
  "The <dialog> holding the command menu. It follows the ARIA \"combobox\" pattern:
a text box that controls a list box of options, grouped under small mono labels."
  (let ((commands (commands home))
        (n -1))                         ; counts options, so each gets a unique id
    `(:dialog :id "cmdk" :class "cmdk" :aria-label "Command menu"
       (:div :class "cmdk-panel"
        (:div :class "cmdk-search"
         ;; autofocus: when the dialog opens, the cursor lands in this box.
         (:input :type "text" :class "cmdk-input" :role "combobox"
                 :aria-label "Search pages, projects and links"
                 :placeholder "Jump to a page, project or link…"
                 :aria-expanded "true" :aria-controls "cmdk-list" :aria-autocomplete "list"
                 :autocomplete "off" :spellcheck "false" :autofocus t)
         (:kbd :class "cmdk-esc" :aria-hidden "true" "esc"))
        (:div :id "cmdk-list" :class "cmdk-list" :role "listbox" :aria-label "Results"
         ,@(loop for group in '("Pages" "Projects" "Links" "Actions")
                 ;; REMOVE-IF-NOT keeps the commands of this group only.
                 for items = (remove-if-not (lambda (c) (equal (getf c :group) group)) commands)
                 when items
                   collect
                   `(:div :class "cmdk-group" :role "group" :aria-label ,group
                      (:div :class "cmdk-group-label" :aria-hidden "true" ,group)
                      ,@(loop for item in items
                              collect
                              (destructuring-bind (&key label href hint keywords action
                                                   &allow-other-keys) item
                                ;; tabindex -1: options are reached with the arrow
                                ;; keys, not Tab. The focus stays in the text box.
                                `(:a :class "cmdk-item" :role "option" :href ,href
                                     :data-cmdk-action ,action
                                     :id ,(format nil "cmdk-~d" (incf n))
                                     :tabindex "-1" :aria-selected "false"
                                     ;; ~{~a~^ ~} joins a list with spaces.
                                     :data-keywords ,(when keywords
                                                       (format nil "~{~a~^ ~}" keywords))
                                   (:span :class "cmdk-label" ,label
                                          ;; ↗ marks links that leave the site.
                                          ,(when (and href (uiop:string-prefix-p "http" href))
                                             '(:span :class "arrow" " ↗")))
                                   (:span :class "cmdk-hint" ,hint)))))))
        ;; Outside the list box on purpose: a listbox may only contain options.
        (:p :class "cmdk-empty" :hidden t "No matches.")
        ;; A live region: screen readers announce its text whenever it changes.
        (:p :class "sr-only" :aria-live "polite" :data-cmdk-status t)
        (:p :class "cmdk-footer" :aria-hidden "true"
         (:span (:kbd "↑") (:kbd "↓") " move")
         (:span (:kbd "↵") " open")
         (:span (:kbd "esc") " close"))))))

(defun layout (&key title description base home-page body)
  "The HTML shared by every page. BASE is NIL for normal pages, which keeps every
link relative (\"style.css\"), so the site works at any address. Given a BASE like
\"/victor_website/\", links become absolute (\"/victor_website/style.css\").
HOME-PAGE is T on index.html only (see HOME below)."
  ;; HOME is what we put in front of "#about" to reach the home page's sections.
  ;; On the home page: nothing. A link to "./#about" would work at /, but at
  ;; /index.html it points to a *different* address (/), so the browser reloads.
  ;; COND tries each test in order and returns the value of the first true one.
  (let ((home (cond (home-page "")
                    (base base)
                    (t "./"))))
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
        (:script :src ,(format nil "~@[~a~]motion.js" base) :defer t)
        (:script :src ,(format nil "~@[~a~]command-menu.js" base) :defer t)
        (:script :src ,(format nil "~@[~a~]source-view.js" base) :defer t))
       (:body :id "top"
        ,(site-header home)
        (:main :class "page" ,@body)
        (:footer :class "page footer"
         (:span "© " ,*name*)
         (:span "Built with " (:a :href "https://lisp-lang.org" "Common Lisp")
                " and a little CSS"))
        ;; The dialog sits outside <main>: it's closed (invisible) until opened.
        ,(command-menu home)))))

;;; ------------------------------------------------------------------
;;; Building blocks
;;; ------------------------------------------------------------------

(defun section (id number heading &rest content)
  "A page section with a numbered label, e.g. 01 — About. If the home page has a
source panel for ID (see HOME-SECTION-SOURCE in source.lisp), it comes along."
  (section-with-source id number heading (home-section-source id) content))

(defun section-with-source (id number heading panel content)
  "SECTION, with the source PANEL given explicitly (NIL for none)."
  `(:section :id ,id :class "section"
     (:h2 :class "label" :data-reveal t
      (:span :class "label-num" ,(format nil "~2,'0d" number))
      ,heading)
     ,@(apply #'with-source panel content)))

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
     ,@(with-source (hero-source)
         `(:p :class "eyebrow" :data-reveal t :style ,(stagger 0) ,*eyebrow*)
         `(:h1 :data-reveal t :style ,(stagger 1) ,@*headline*)
         `(:p :class "intro" :data-reveal t :style ,(stagger 2) ,*intro*)
         `(:div :data-reveal t :style ,(stagger 3) ,(link-list))
         (terminal))))

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
    ;; MULTIPLE-VALUE-BIND catches the two values CASE-STUDY-SOURCES returns.
    (multiple-value-bind (hero-panel part-panels) (case-study-sources project)
      `((:div :class "hero case-hero"
          ,@(with-source hero-panel
              `(:p :class "eyebrow" :data-reveal t :style ,(stagger 0)
                 (:a :class "back" :href "./#projects" "← All work"))
              `(:h1 :data-reveal t :style ,(stagger 1) ,name)
              `(:p :class "intro" :data-reveal t :style ,(stagger 2) ,summary)
              `(:div :data-reveal t :style ,(stagger 3)
                 (:ul :class "tags" ,@(mapcar (lambda (tag) `(:li ,tag)) tags))
                 (:ul :class "links"
                  ,@(loop for (label url) in links
                          collect `(:li (:a :class "pill" :href ,url ,label " ↗")))))
              `(:ul :class "stats" :data-reveal t :style ,(stagger 4)
                 ,@(loop for (value label) in stats
                         collect `(:li (:strong ,value) (:span ,label))))))
        ;; (heading . paragraphs) splits ("How it works" "p1" "p2") into the
        ;; first element and the rest of the list.
        ,@(loop for (heading . paragraphs) in sections
                for panel in part-panels
                for n from 1
                collect (section-with-source
                         (format nil "part-~d" n) n heading panel
                         (list `(:div :class "prose" :data-reveal t
                                  ,@(mapcar (lambda (p) `(:p ,p)) paragraphs)))))))))

;;; ------------------------------------------------------------------
;;; Pages
;;; ------------------------------------------------------------------

(defpage "index.html" (:title *name* :description *intro* :home-page t)
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
            (defpage (case-study-path slug) (:title (format nil "~a · ~a" (getf project :name) *name*)
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
