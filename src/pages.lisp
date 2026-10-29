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

(defmacro defpage (path (&key title description base home-page noindex toc rail-title) &body body)
  "Define a page written to PATH. Each BODY form is evaluated (at build time) and must
return an HTML tree, so quote literal HTML: '(:p \"hi\") or `(:p ,*name*).
BASE is only for pages that need absolute links (the 404 page); see LAYOUT.
HOME-PAGE is T only for index.html, so its section links can stay on the page.
NOINDEX asks search engines to leave the page out of their results (the 404).
TOC is T on pages whose side rail lists the page's own sections (the case studies),
and RAIL-TITLE is the name shown above that list.

Try (macroexpand-1 '(defpage \"x.html\" (:title \"X\") '(:p \"hi\"))) in the REPL
to see what this macro actually writes for you."
  ;; PATH is used twice below, so it's evaluated once first, into FILE.
  ;; GENSYM makes a fresh, unique symbol for that variable, so its name can't
  ;; clash with a variable of the same name inside BODY.
  (let ((file (gensym "FILE")))
    `(let ((,file ,path))
       (setf (gethash ,file *pages*)
             (lambda ()
               (layout :title ,title
                       :description ,description
                       :path ,file
                       :base ,base
                       :home-page ,home-page
                       :noindex ,noindex
                       :toc ,toc
                       :rail-title ,rail-title
                       :body (list ,@body)))))))

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
  "https://fonts.googleapis.com/css2?family=Geist:wght@400;500;600&family=Geist+Mono:wght@400;500&family=Literata:ital,wght@0,400;0,500;1,400&display=swap"
  "The three typefaces, from Google Fonts. display=swap: the text shows at once
in a fallback font and switches when the real one arrives, so a slow network
never leaves the page blank.")

(defun page-url (path)
  "The full address of the page written to PATH, e.g. \"https://victorhenz.com/\"
for index.html. NIL while *DOMAIN* is NIL: without a domain the final address
isn't certain, and a wrong address in the head is worse than none."
  (when *domain*
    (format nil "https://~a/~a" *domain* (if (equal path "index.html") "" path))))

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

(defun site-header (home &key toc rail-title)
  ;; HOME is the prefix that leads to the home page (see LAYOUT):
  ;;   ""         on the home page itself -> links like "#about" just scroll;
  ;;   "./"       on a project page       -> "./#about" goes back home first;
  ;;   a base path on the 404 page         -> "/victor_website/#about".
  ;;
  ;; One header, two layouts (style.css, sections 3 and 14):
  ;;   - narrower than 64rem: a bar across the top (name, links, buttons);
  ;;   - 64rem and wider: a column on the left that stays put while the
  ;;     content scrolls on the right (the "side rail").
  ;; The parts marked "rail only" below are hidden in the top bar by the CSS.
  ;; display:none hides them from screen readers too, so nobody hears them twice.
  ;; TOC is a list of (id heading) pairs, the sections of this page (see
  ;; PAGE-SECTIONS); RAIL-TITLE is the project's name on a case-study page.
  `(:header :class "site-header"
     (:div :class "page header-inner"
      (:a :class "wordmark" :href ,(home-link home) ,*name*)
      ;; Rail only: one line about Victor, or, on a project page, the way back
      ;; and the project's name.
      ,(if rail-title
           `(:div :class "rail-only rail-context"
              (:a :class "back" :href ,(format nil "~a#projects" home)
                  (:span :aria-hidden "true" "← ") "All work")
              (:p :class "rail-title" ,rail-title))
           `(:p :class "rail-only rail-role" ,*eyebrow*))
      (:div :class "header-end"
       ;; aria-label names each nav for screen readers, which list every landmark.
       ;; With a TOC, the rail shows it instead of the home page's sections.
       (:nav :aria-label "Sections" :class ,(when toc "has-toc")
        ,@(loop for (id label) in *home-sections*
                collect `(:a :href ,(format nil "~a#~a" home id) ,label)))
       ,(when toc
          `(:nav :aria-label "On this page" :class "rail-only toc"
             ,@(loop for (id heading) in toc
                     collect `(:a :href ,(format nil "#~a" id) ,heading))))
       (:div :class "header-tools"
        ,(source-toggle)
        ,(command-button)))
      ;; Rail only: the links, at the bottom of the column.
      (:ul :class "rail-only rail-links" :aria-label "Links"
       ,@(loop for (label url) in *links*
               when url
                 collect `(:li (:a :href ,url ,label)))))))

(defun page-sections (tree)
  "Every (id heading) pair of the numbered sections in TREE, in page order.
TREE is a page's HTML tree, before it is rendered: plain lists. So the side rail's
table of contents is read from the page itself, and a new part in content.lisp
shows up in it with no extra work.
A section looks like (:section :id \"part-1\" ... (:h2 ... \"How it works\") ...),
see SECTION-WITH-SOURCE: its heading is the last thing in its <h2>.
This is a recursive function: for a list that isn't a section, it asks the same
question of every element and joins the answers (LOOP ... APPEND)."
  (cond ((atom tree) nil)                       ; a string or a number: no sections
        ((eq (first tree) :section)
         ;; SPLIT-ATTRIBUTES (html.lisp) separates :id \"x\" :class \"y\" from the children.
         (multiple-value-bind (attributes children) (split-attributes (rest tree))
           (let ((h2 (find-if (lambda (child) (and (consp child) (eq (first child) :h2)))
                              children)))
             (when (and h2 (getf attributes :id))
               (list (list (getf attributes :id) (car (last h2))))))))
        (t (loop for child in tree append (page-sections child)))))

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
                                          ;; ↗ marks links that leave the site. aria-hidden:
                                          ;; screen readers would say "north east arrow".
                                          ,(when (and href (uiop:string-prefix-p "http" href))
                                             '(:span :class "arrow" :aria-hidden "true" " ↗")))
                                   (:span :class "cmdk-hint" ,hint)))))))
        ;; Outside the list box on purpose: a listbox may only contain options.
        (:p :class "cmdk-empty" :hidden t "No matches.")
        ;; A live region: screen readers announce its text whenever it changes.
        (:p :class "sr-only" :aria-live "polite" :data-cmdk-status t)
        (:p :class "cmdk-footer" :aria-hidden "true"
         (:span (:kbd "↑") (:kbd "↓") " move")
         (:span (:kbd "↵") " open")
         (:span (:kbd "esc") " close"))))))

(defun asset-url (name base)
  "The address of static/NAME with a fingerprint of its contents, e.g. \"style.css?v=3f9a2c1b\".
Browsers keep CSS and JS files in a cache. Without the fingerprint, a browser can
pair today's HTML with yesterday's stylesheet and the page breaks. When the file
changes, its fingerprint (and so its address) changes, and the browser has to
fetch it again. SXHASH turns a string into a number that depends only on its
characters; ~(~x~) writes that number in lowercase hexadecimal."
  (let ((text (uiop:read-file-string (merge-pathnames name (merge-pathnames "static/" (project-root)))
                                     :external-format :utf-8)))
    (format nil "~@[~a~]~a?v=~(~x~)" base name (sxhash text))))

(defun layout (&key title description path base home-page noindex toc rail-title body)
  "The HTML shared by every page. BASE is NIL for normal pages, which keeps every
link relative (\"style.css\"), so the site works at any address. Given a BASE like
\"/victor_website/\", links become absolute (\"/victor_website/style.css\").
HOME-PAGE is T on index.html only (see HOME below). PATH is the page's file name.
TOC and RAIL-TITLE are for the side rail (see SITE-HEADER and DEFPAGE)."
  ;; HOME is what we put in front of "#about" to reach the home page's sections.
  ;; On the home page: nothing. A link to "./#about" would work at /, but at
  ;; /index.html it points to a *different* address (/), so the browser reloads.
  ;; COND tries each test in order and returns the value of the first true one.
  (let ((home (cond (home-page "")
                    (base base)
                    (t "./")))
        (url (unless noindex (page-url path))))
    `(:html :lang "en"
       (:head
        (:meta :charset "utf-8")
        (:meta :name "viewport" :content "width=device-width, initial-scale=1")
        (:title ,title)
        ,(when description
           `(:meta :name "description" :content ,description))
        ;; How a link to the page looks when it's shared (LinkedIn, Slack,
        ;; iMessage...): Open Graph tags, which most apps read, and a card type
        ;; for X. There's no og:image on purpose: the apps then show a plain
        ;; text card, which is better than an invented picture.
        (:meta :property "og:type" :content "website")
        (:meta :property "og:site_name" :content ,*name*)
        (:meta :property "og:title" :content ,title)
        ,(when description
           `(:meta :property "og:description" :content ,description))
        ,(when url `(:meta :property "og:url" :content ,url))
        (:meta :name "twitter:card" :content "summary")
        ;; canonical = "this is the page's one true address", for search engines.
        ,(when url `(:link :rel "canonical" :href ,url))
        ,(when noindex '(:meta :name "robots" :content "noindex"))
        ;; The color phones give the browser bar around the page, one per theme.
        (:meta :name "theme-color" :content "#fafafb" :media "(prefers-color-scheme: light)")
        (:meta :name "theme-color" :content "#0e1114" :media "(prefers-color-scheme: dark)")
        ;; The tab icon. Without one, every browser asks for /favicon.ico and gets a 404.
        (:link :rel "icon" :type "image/svg+xml" :href ,(format nil "~@[~a~]favicon.svg" base))
        ;; The fonts' stylesheet blocks the first paint until it arrives (one small
        ;; file). preconnect opens the connections to Google early, and
        ;; display=swap (in *FONT-URL*) shows the text before the fonts themselves
        ;; arrive. Loading the stylesheet "async" would save a little more, but
        ;; then the whole page would flash in fallback fonts first: not worth it here.
        (:link :rel "preconnect" :href "https://fonts.googleapis.com")
        (:link :rel "preconnect" :href "https://fonts.gstatic.com" :crossorigin t)
        (:link :rel "stylesheet" :href ,*font-url*)
        ;; ASSET-URL adds a fingerprint, so a browser never mixes new HTML with old CSS.
        (:link :rel "stylesheet" :href ,(asset-url "style.css" base))
        ;; defer = download now, run after the HTML is parsed.
        (:script :src ,(asset-url "motion.js" base) :defer t)
        (:script :src ,(asset-url "command-menu.js" base) :defer t)
        (:script :src ,(asset-url "source-view.js" base) :defer t))
       (:body :id "top"
        ;; The first thing Tab reaches: keyboard users can jump past the header
        ;; straight to the content. Off screen until it has the focus (style.css).
        (:a :class "skip-link" :href "#main" "Skip to content")
        ,(site-header home :toc (when toc (page-sections body)) :rail-title rail-title)
        (:main :id "main" :class "page" ,@body)
        (:footer :class "page footer"
         (:span "© " ,*name*)
         (:span "Built with " (:a :href "https://lisp-lang.org" "Common Lisp")
                " and a little CSS")
         ,(build-stats))
        ;; The dialog sits outside <main>: it's closed (invisible) until opened.
        ,(command-menu home)))))

(defun build-stats ()
  "The footer's last line: numbers measured while the site builds (see stats.lisp).
Two of them don't exist yet while the page renders, so they're markers that
BUILD replaces afterwards. Outside a build *BUILD-STATS* is NIL: no line at all.
The dots between items come from the CSS, so screen readers don't read them."
  (when *build-stats*
    (destructuring-bind (&key lisp lines pages date) *build-stats*
      `(:div :class "build-stats"
         (:ul :aria-label "Build stats"
          (:li (:b ,lisp))
          (:li (:b ,(format nil "~:d" lines)) " lines of Lisp")   ; ~:d writes 1,312
          (:li (:b ,pages) " pages rendered in " (:b (:raw ,*render-ms-marker*) " ms"))
          (:li "this page " (:b (:raw ,*page-bytes-marker*)) " bytes")
          (:li "built " (:b (:time :datetime ,date ,date))))))))

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

;;; ------------------------------------------------------------------
;;; Diagrams: a :diagram plist in content.lisp -> an SVG picture
;;;
;;; SVG is HTML's cousin for drawings: <rect> is a box, <text> is a label and
;;; <path d="M 0 0 C ..."> is a line. Since it's just more tags, the same
;;; renderer (html.lisp) writes it. Lisp does the geometry here: where each box
;;; goes, where each arrow starts and ends, how it curves. The motion (arrows
;;; drawing themselves, dots travelling, the agent walk) lives in style.css and
;;; motion.js; LEARN.md, "Effect 11", explains the whole thing.
;;;
;;; Every diagram is drawn twice: a wide picture for laptops and a narrow one,
;;; always flowing top to bottom, for phones. The CSS shows one of the two.
;;; ------------------------------------------------------------------

(defparameter *diagram-sizes*
  ;; All numbers are SVG units. With the picture at its natural width, one unit
  ;; is one screen pixel.
  ;;   :step  distance from one column (or row) to the next, along the flow
  ;;   :side  distance between two boxes, across the flow
  ;;   :w :h  the size of a box
  '(:right  (:step 220 :side 84  :w 140 :h 54)    ; wide screens, flowing left to right
    :down   (:step 118 :side 250 :w 160 :h 54)    ; wide screens, flowing top to bottom
    :narrow (:step 140 :side 122 :w 112 :h 54)))  ; phones: always top to bottom

(defparameter *diagram-pad* 8
  "Empty space around the picture, so the box borders aren't cut off.")

(defun num (x)
  "A number written for SVG with one decimal: 12 -> \"12.0\", 2/3 -> \"0.7\"."
  (format nil "~,1f" x))

(defun bezier-point (points tt)
  "The point at TT (0 = start, 1 = end) on the cubic Bezier curve through
POINTS, four (a b) lists. A Bezier curve starts at the 1st point, ends at the 4th,
and is pulled towards the 2nd and 3rd ones (its \"control points\")."
  (destructuring-bind ((a0 b0) (a1 b1) (a2 b2) (a3 b3)) points
    (let* ((u (- 1 tt))
           (k0 (* u u u)) (k1 (* 3 u u tt)) (k2 (* 3 u tt tt)) (k3 (* tt tt tt)))
      (list (+ (* k0 a0) (* k1 a1) (* k2 a2) (* k3 a3))
            (+ (* k0 b0) (* k1 b1) (* k2 b2) (* k3 b3))))))

(defun diagram-svg (diagram layout id)
  "The <svg> for DIAGRAM. LAYOUT is :wide or :narrow; ID prefixes every id inside,
so the two pictures of one diagram don't clash.

The geometry works in two directions instead of x and y: MAIN runs along the flow
(left to right in a :right diagram) and CROSS runs across it. That's what lets
the same code draw the phone version: it just maps MAIN to y instead of x."
  (destructuring-bind (&key flow title caption nodes edges pulse walk &allow-other-keys) diagram
    (destructuring-bind (&key step side w h)
        (getf *diagram-sizes* (if (eq layout :narrow) :narrow flow))
      (let* ((across (and (eq layout :wide) (eq flow :right))) ; MAIN is horizontal?
             (hm (/ (if across w h) 2))       ; half a box, along MAIN
             (hc (/ (if across h w) 2))       ; half a box, along CROSS
             (pad *diagram-pad*)
             ;; :at is (column row). In a :right diagram columns follow the flow.
             (grid (loop for (name . options) in nodes
                         for (x y) = (getf options :at)
                         collect (if (eq flow :right) (list name x y) (list name y x))))
             (mains (mapcar #'second grid))
             (crosses (mapcar #'third grid))
             (size-main (ceiling (+ (* 2 pad) (* 2 hm) (* step (reduce #'max mains)))))
             (size-cross (ceiling (+ (* 2 pad) (* 2 hc) (* side (reduce #'max crosses)))))
             (width (if across size-main size-cross))
             (height (if across size-cross size-main))
             (walk-ids (mapcar #'first walk)))
        (labels ((center (name)
                   ;; ASSOC finds the (name main cross) entry for NAME.
                   (destructuring-bind (m c) (rest (assoc name grid))
                     (list (+ pad hm (* m step)) (+ pad hc (* c side)))))
                 (xy (point)
                   ;; (main cross) -> (x y) on screen.
                   (if across point (reverse point)))
                 (at (point &optional (dx 0) (dy 0))
                   (destructuring-bind (x y) (xy point)
                     (format nil "~a ~a" (num (+ x dx)) (num (+ y dy)))))
                 (clamp (n) (max -1 (min 1 n)))
                 (route (from to)
                   ;; Four points (start, control, control, end) for an arrow from
                   ;; box FROM to box TO, plus the axis it arrives along and which
                   ;; way it points (+1 or -1). Boxes in different columns connect
                   ;; through the sides that face each other; boxes in the same
                   ;; column, through their other sides. An end slides along its
                   ;; side towards the other box, so arrows meeting at one box
                   ;; don't all land on the same point.
                   ;; An arrow longer than one step runs straight along its own
                   ;; lane first and only bends in the last gap, so it never cuts
                   ;; through the boxes in between. It then has 5 points: the real
                   ;; start, where the straight part ends, and the 4 of the curve.
                   (destructuring-bind ((m1 c1) (m2 c2)) (list (center from) (center to))
                     (if (/= m1 m2)
                         (let* ((dir (signum (- m2 m1)))
                                (long (> (abs (- m2 m1)) (* 1.5 step)))
                                ;; (a long arrow leaves from the middle of its side)
                                (a (list (+ m1 (* dir hm))
                                         (if long c1 (+ c1 (* 0.45 hc (clamp (/ (- c2 c1) side)))))))
                                (b (list (- m2 (* dir hm)) (+ c2 (* 0.45 hc (clamp (/ (- c1 c2) side))))))
                                ;; Where the curve starts: at A, or at the last gap.
                                (bend (if long
                                          (list (- m2 (* dir (- step hm))) (second a))
                                          a))
                                (mid (/ (+ (first bend) (first b)) 2))
                                (curve (list bend (list mid (second a)) (list mid (second b)) b)))
                           (values (if long (cons a curve) curve) :main dir))
                         (let* ((dir (signum (- c2 c1)))
                                (a (list m1 (+ c1 (* dir hc))))
                                (b (list m2 (- c2 (* dir hc))))
                                (mid (/ (+ (second a) (second b)) 2)))
                           (values (list a (list (first a) mid) (list (first b) mid) b) :cross dir)))))
                 (path-d (points)
                   ;; "M x y" moves the pen, "L x y" draws a straight line,
                   ;; "C c1, c2, end" draws a Bezier curve (see BEZIER-POINT).
                   (destructuring-bind (p0 p1 p2 p3) (last points 4)
                     (format nil "M ~a ~@[L ~a ~]C ~a, ~a, ~a"
                             (at (first points))
                             (when (= (length points) 5) (at p0))
                             (at p1) (at p2) (at p3))))
                 (arrowhead (tip axis dir)
                   ;; A small triangle with its point on TIP, aimed along AXIS.
                   (flet ((off (along across-by)          ; move from TIP, in (main cross)
                            (if (eq axis :main)
                                (list (+ (first tip) along) (+ (second tip) across-by))
                                (list (+ (first tip) across-by) (+ (second tip) along)))))
                     (format nil "M ~a L ~a L ~a Z" (at tip)
                             (at (off (* -7 dir) 3.5)) (at (off (* -7 dir) -3.5)))))
                 (edge-id (i) (format nil "~a-e~d" id i))
                 (label-box (point label)
                   ;; The rectangle (left top right bottom) a label covers when it
                   ;; is centered on POINT. The font is monospaced, so every
                   ;; character is about 6.5 units wide, plus 4 on each side.
                   (destructuring-bind (x y) (xy point)
                     (let ((half (+ 4 (* 3.25 (length label)))))
                       (list (- x half) (- y 8) (+ x half) (+ y 8)))))
                 (overlap-p (a b)
                   ;; Do two rectangles overlap, or come closer than 2 units?
                   (destructuring-bind ((l1 t1 r1 b1) (l2 t2 r2 b2)) (list a b)
                     (and (< l1 (+ r2 2)) (< l2 (+ r1 2)) (< t1 (+ b2 2)) (< t2 (+ b1 2))))))
          `(:svg :class ,(format nil "diagram-svg diagram-~(~a~)" layout)
                 :viewBox ,(format nil "0 0 ~d ~d" width height)
                 :width ,width :height ,height
                 :role "img"
                 :aria-labelledby ,(format nil "~a-title" id)
                 :aria-describedby ,(format nil "~a-desc" id)
             (:title :id ,(format nil "~a-title" id) ,title)
             (:desc :id ,(format nil "~a-desc" id)
              ,(format nil "~a The boxes and arrows are listed as text under the picture." caption))
             ;; The arrows. (from arrow to label): ARROW is the symbol -> or <->.
             ;; --i is the arrow's place in the list: the CSS draws them in order.
             (:g :class "edges"
              ,@(loop for (from arrow to label) in edges
                      for i from 0
                      collect
                      (multiple-value-bind (points axis dir) (route from to)
                        `(:g :class "edge" :style ,(stagger i)
                           (:path :class "edge-line" :id ,(edge-id i)
                                  :d ,(path-d points) :pathLength "1")
                           (:path :class "edge-head" :d ,(arrowhead (car (last points)) axis dir))
                           ,(when (eq arrow '<->)
                              `(:path :class "edge-head"
                                      :d ,(arrowhead (first points) axis (- dir))))))))
             ;; The walk: one extra line per step, in the walk's direction, on top
             ;; of the normal arrows. motion.js lights step N with data-walk="N".
             ,(when walk
                `(:g :class "walk"
                   ,@(loop for (from to) on walk-ids
                           for n from 1
                           when to
                             collect `(:path :class "walk-line" :data-walk ,n
                                             :d ,(path-d (route from to)) :pathLength "1"))))
             (:g :class "nodes"
              ,@(loop for (name . options) in nodes
                      collect
                      (destructuring-bind (&key label note &allow-other-keys) options
                        (destructuring-bind (x y) (xy (center name))
                          ;; --i here is the box's column: they appear left to right.
                          `(:g :class "node" :style ,(stagger (second (assoc name grid)))
                               :data-walk ,(position name walk-ids)
                             (:rect :x ,(num (- x (/ w 2))) :y ,(num (- y (/ h 2)))
                                    :width ,w :height ,h :rx 8)
                             (:text :class "node-label" :x ,(num x) :y ,(num (- y 2))
                              ,label)
                             ,(when note
                                `(:text :class "node-note" :x ,(num x) :y ,(num (+ y 14))
                                   ,note)))))))
             ;; Labels go last so they're painted over the lines they cross.
             ;; A label sits halfway along its arrow's curve, unless the edge
             ;; says otherwise with :label-at. A long arrow (5 points) has its
             ;; label on its straight part, in the first gap after its start.
             ;; If that spot would cover a box or a label placed before it (on
             ;; the narrow picture, several arrows can share one gap), the label
             ;; slides along its own arrow to the first free spot. TAKEN holds
             ;; the rectangles already used: every box, then each label placed.
             ;; In (from nil to label . options), NIL skips the arrow symbol and
             ;; the dot catches whatever comes after the label, like :label-at.
             (:g :class "edge-labels"
              ,@(loop with taken = (loop for (name) in nodes
                                         collect (destructuring-bind (x y) (xy (center name))
                                                   (list (- x (/ w 2)) (- y (/ h 2))
                                                         (+ x (/ w 2)) (+ y (/ h 2)))))
                      for (from nil to label . options) in edges
                      for i from 0
                      when label
                        collect
                        (let* ((points (route from to))
                               (at (getf options :label-at))
                               ;; The walk step that goes along this arrow (either
                               ;; way), if any: its label lights up with that step,
                               ;; since the label's rect hides the walk's line.
                               (walk-step (loop for (a b) on walk-ids
                                                for n from 1
                                                when (or (and (eq a from) (eq b to))
                                                         (and (eq a to) (eq b from)))
                                                  return n))
                               (wanted (if (and (= (length points) 5) (not at))
                                           ;; half a gap from the start, towards the 2nd point
                                           (destructuring-bind ((m c) (m2 c2) &rest curve) points
                                             (declare (ignore c2 curve))
                                             (list (+ m (* (signum (- m2 m)) (- step (* 2 hm)) 1/2)) c))
                                           (bezier-point (last points 4) (or at 0.5))))
                               ;; The spots to try, in order: the wanted one, then
                               ;; others along the curve, closer and closer to its ends.
                               (spots (cons wanted
                                            (mapcar (lambda (tt) (bezier-point (last points 4) tt))
                                                    '(0.5 0.35 0.65 0.25 0.75 0.2 0.8))))
                               ;; NOTANY is true when no rectangle in TAKEN overlaps.
                               ;; If every spot is taken, keep the wanted one.
                               (point (or (find-if (lambda (spot)
                                                     (notany (lambda (box) (overlap-p (label-box spot label) box))
                                                             taken))
                                                   spots)
                                          wanted))
                               (box (label-box point label)))
                          (push box taken)
                          ;; A small rect in the page color hides the line behind
                          ;; the label, spaces included.
                          (destructuring-bind (left top right bottom) box
                            (declare (ignore bottom))
                            `(:g :class "edge-label" :style ,(stagger i)
                                 :data-walk ,walk-step
                               (:rect :x ,(num left) :y ,(num top)
                                      :width ,(num (- right left)) :height 16 :rx 3)
                               (:text :x ,(num (/ (+ left right) 2)) :y ,(num (+ top 11.5)) ,label))))))
             ;; The pulse: one dot per arrow of the pipeline. They share one
             ;; cycle of DUR seconds; each dot moves during its own slice of it,
             ;; so together they look like one parcel going box to box.
             ;; <animateMotion> moves the dot along the arrow's path (<mpath>).
             ;; begin="indefinite": nothing moves until motion.js says so.
             ,(when pulse
                (let* ((hops (loop for (from to) on pulse when to collect (list from to)))
                       (leg 1.8)              ; seconds per arrow
                       (dur (+ 0.3 (* leg (length hops)) 1.6))) ; + a short rest at the end
                  `(:g :class "pulses" :aria-hidden "true"
                     ,@(loop for (from to) in hops
                             for k from 0
                             for i = (position-if (lambda (e) (and (eq (first e) from)
                                                                   (eq (third e) to)))
                                                  edges)
                             for a = (/ (+ 0.3 (* k leg)) dur)
                             for b = (/ (+ 0.3 (* (1+ k) leg)) dur)
                             collect
                             (flet ((animation (tag &rest attributes)
                                      `(,tag :dur ,(format nil "~,1fs" dur)
                                             :begin "indefinite" :repeatCount "indefinite"
                                             ,@attributes)))
                               `(:circle :class "pulse-dot" :r 3.5 :opacity 0
                                  ,(animation :animateMotion
                                              :calcMode "linear" :keyPoints "0;0;1;1"
                                              :keyTimes (format nil "0;~,3f;~,3f;1" a b)
                                              `(:mpath :href ,(format nil "#~a" (edge-id i))))
                                  ,(animation :animate
                                              :attributeName "opacity" :values "0;0;1;1;0;0"
                                              :keyTimes (format nil "0;~,3f;~,3f;~,3f;~,3f;1"
                                                                a (+ a 0.02) (- b 0.02) b))))))))))))))

(defun diagram-text (diagram)
  "The diagram as plain text: every box and every arrow, as two lists. It's what
a screen reader user gets instead of the picture, and it works for anyone who
prefers reading. It's written from the same data, so it can't fall out of date."
  (destructuring-bind (&key nodes edges &allow-other-keys) diagram
    (flet ((label-of (name) (getf (rest (assoc name nodes)) :label)))
      `(:details :class "diagram-text"
         (:summary "The diagram as text")
         (:p "Boxes")
         (:ul ,@(loop for (nil . options) in nodes
                      collect `(:li ,(format nil "~a~@[ (~a)~]"
                                             (getf options :label) (getf options :note)))))
         (:p "Arrows")
         (:ul ,@(loop for (from arrow to label) in edges
                      collect `(:li ,(format nil "~a ~a ~a~@[: ~a~]"
                                             (label-of from)
                                             (if (eq arrow '<->) "↔" "→")
                                             (label-of to)
                                             label))))))))

(defun diagram-figure (diagram id)
  "A diagram with everything around it: both pictures, the caption, the pause
button, the walk's steps and the text version. DATA-DRAW-MS tells motion.js how
long the arrows take to draw (it matches the CSS timings), so the looping motion
starts once the picture is complete."
  (destructuring-bind (&key caption edges pulse walk &allow-other-keys) diagram
    `(:figure :class "diagram" :data-diagram t
              :data-draw-ms ,(+ 300 (* 110 (length edges)) 800)
       (:div :class "diagram-frame"
        ,(diagram-svg diagram :wide (format nil "~a-wide" id))
        ,(diagram-svg diagram :narrow (format nil "~a-narrow" id)))
       (:figcaption :class "diagram-caption"
        (:span ,caption)
        ;; Hidden until motion.js starts something that loops (WCAG 2.2.2:
        ;; anything moving for more than 5 seconds needs a way to stop it).
        ,(when (or pulse walk)
           '(:button :type "button" :class "diagram-toggle" :data-diagram-toggle t
                     :hidden t :aria-label "Pause animation" "Pause")))
       ,(when walk
          `(:div :class "walk-steps"
             (:p :class "walk-title" "An example walk, for illustration (not real data)")
             (:ol ,@(loop for (nil text) in walk
                          for n from 0
                          collect `(:li :data-walk ,n ,text)))))
       ,(diagram-text diagram))))

;;; ------------------------------------------------------------------
;;; The demo video (only when its file exists, see media.lisp)
;;; ------------------------------------------------------------------

(defun demo-video (video live-url)
  "The video under a case study's header, or NIL when its file isn't in static/.
VIDEO is the project's :video plist. Two kinds:
  - silent (a screen recording): it loops, muted. There is no `autoplay`: without
    JavaScript, or under reduced motion, it waits with the browser's own controls
    until you press play. Otherwise motion.js swaps those controls for a small
    Pause button and plays it while it's on screen.
  - :sound t (a demo with a voice-over): the browser's controls, and nothing is
    downloaded until you press play (see SOUND-VIDEO in media.lisp)."
  (destructuring-bind (&key file poster caption sound) video
    (when (static-file-p file)
      (destructuring-bind (width height) (video-size file)
        `(:figure :class "demo" :data-reveal t
           (:div :class "demo-frame"
            ,@(if sound
                  (list (sound-video file poster caption))
                  `((:video :class "demo-video" :data-demo-video t
                            :width ,width :height ,height
                            :poster ,(poster-or-nil poster)
                            :muted t :loop t :playsinline t :preload "metadata" :controls t
                      (:source :src ,file :type "video/mp4"))
                    (:button :type "button" :class "diagram-toggle demo-toggle" :data-demo-toggle t
                             :hidden t :aria-label "Pause video" "Pause"))))
           (:figcaption :class "diagram-caption"
            (:span ,caption
                   ,(when live-url
                      `(" " (:a :href ,live-url "Live demo"
                                (:span :class "arrow" :aria-hidden "true" " ↗")))))))))))

;;; ------------------------------------------------------------------
;;; The funnel: a few numbers, each with a bar that grows into place
;;; ------------------------------------------------------------------

(defun funnel-width (count biggest)
  "How long COUNT's bar is, as a percentage of the longest one, on a log scale.
With a straight scale, 7 out of 16,000 would be a bar 0.04% long: invisible. LOG
counts the digits instead (roughly), so each step down the funnel is a visible
step. The smallest bar is at least 4% long."
  (max 4 (* 100 (/ (log (max count 1)) (log (max biggest 2))))))

(defun funnel (funnel &key mini)
  "The :funnel of a project as a list of bars. It's a real <ol>: a screen reader
reads \"~16,000 listings scanned\", and the bars are only decoration (aria-hidden).
--w is a bar's length and --i its place in the list: the CSS grows each bar from
the left when the funnel scrolls into view, one after another.
MINI is the small version drawn on a project card: decorative, so all of it is
hidden from screen readers (the card's text says what the project is)."
  (destructuring-bind (&key steps caption &allow-other-keys) funnel
    (let* ((biggest (reduce #'max (mapcar #'second steps)))
           (bars `(:ol :class "funnel-steps"
                    ,@(loop for (value count label) in steps
                            for i from 0
                            collect `(:li :style ,(format nil "--w: ~,1f%; --i: ~d"
                                                          (funnel-width count biggest) i)
                                       (:span :class "funnel-value" ,value)
                                       (:span :class "funnel-label" ,label)
                                       (:span :class "funnel-bar" :aria-hidden "true"))))))
      (if mini
          `(:div :class "funnel funnel-mini" :aria-hidden "true" ,bars)
          `(:figure :class "funnel" :data-reveal t
             ,bars
             (:figcaption :class "diagram-caption" (:span ,caption)))))))

;;; ------------------------------------------------------------------
;;; A photo gallery: every picture in one folder, if there are any
;;; ------------------------------------------------------------------

(defun gallery (gallery project-name)
  "The pictures in the :gallery's :folder, or NIL if it has none. The Nth photo
gets the Nth text of :alts; a photo without one gets a plain description built
from the project's name, so no picture is ever left without alt text."
  (destructuring-bind (&key folder alts &allow-other-keys) gallery
    (let ((files (media-folder folder)))
      (when files
        `(:ul :class "gallery" :data-reveal t
           ,@(loop for file in files
                   for n from 1
                   collect `(:li ,(picture file
                                           (or (nth (1- n) alts)
                                               (format nil "~a: photo ~d from the event" project-name n))
                                           :class "gallery-photo"))))))))

;;; ------------------------------------------------------------------
;;; Project cards: a picture or a moving loop on top, the text below
;;; ------------------------------------------------------------------

(defun case-study-path (slug)
  "The file a project's page is written to: \"internship-radar\" -> \"internship-radar.html\"."
  (format nil "~a.html" slug))

(defun card-fallback (project)
  "What the top of a card shows when the project has no photo or video (yet).
Never a fake picture: something drawn from the project's own data.
  :stat (\"1st\" \"of 120\")  a big number, set in type
  :stat :lines-of-lisp      the same, but the number is counted during the build
  :funnel                   a small copy of the project's funnel
  :diagram                  a small copy of the project's diagram
COND tries each one in that order."
  (destructuring-bind (&key slug stat funnel diagram &allow-other-keys) project
    (cond ((eq stat :lines-of-lisp)
           `(:div :class "card-tile" :aria-hidden "true"
              (:span :class "card-tile-big" (:span :class "c-paren" "(") "λ" (:span :class "c-paren" ")"))
              (:span :class "card-tile-note" ,(format nil "~:d lines of Common Lisp" (lines-of-lisp)))))
          (stat
           `(:div :class "card-tile" :aria-hidden "true"
              (:span :class "card-tile-big" ,(first stat))
              (:span :class "card-tile-note" ,(second stat))))
          (funnel (funnel funnel :mini t))
          (diagram
           ;; The same SVG as on the project page, just smaller. Its ids get a
           ;; "card-" prefix so they don't clash with anything else on the page.
           `(:div :class "card-diagram" :aria-hidden "true"
              ,(diagram-svg diagram :wide (format nil "card-~a" slug))))
          (t nil))))

(defun card-media (project)
  "The top of a card: the :card video or image if its file exists, else the fallback."
  (destructuring-bind (&key card &allow-other-keys) project
    (destructuring-bind (&key video poster image alt) card
      (let ((media (cond (video (loop-video video poster))
                         (image (picture image alt :class "card-image")))))
        `(:div :class ,(if media "card-media" "card-media is-fallback")
           ,(or media (card-fallback project))
           ;; Only a looping video needs a Pause button (hidden until motion.js plays it).
           ,(when (and media video)
              '(:button :type "button" :class "diagram-toggle media-toggle"
                        :data-loop-toggle t :hidden t :aria-label "Pause video" "Pause")))))))

(defun project-card (i project)
  ;; &allow-other-keys: the plist also has :stats, :sections... that the card ignores.
  (destructuring-bind (&key name slug url summary blurb tags featured &allow-other-keys) project
    (let ((href (or (and slug (case-study-path slug)) url)))
      `(:li :class ,(if featured "card card-featured" "card card-compact")
            :data-reveal t :style ,(stagger i)
         ,(card-media project)
         (:div :class "card-body"
          ;; The title's link covers the whole card (.card-link::after in the CSS),
          ;; so the picture is clickable too, while the link's name stays the title.
          ;; The arrows are decoration (aria-hidden).
          (:h3 ,(if href
                    `(:a :class "card-link" :href ,href ,name
                         (:span :class "arrow" :aria-hidden "true" ,(if slug " →" " ↗")))
                    name))
          (:p ,(or blurb summary))
          (:ul :class "tags"
           ,@(mapcar (lambda (tag) `(:li ,tag)) tags)))))))

(defun insert-part (parts part after)
  "PARTS with PART added right after the part whose heading is AFTER (or at the
end if no part has that heading). The parts are numbered afterwards, so the
numbers stay in order either way."
  (let* ((found (position after parts :key #'first :test #'equal))
         (at (if found (1+ found) (length parts))))
    (append (subseq parts 0 at) (list part) (subseq parts at))))

(defun case-study (project)
  "A full page for one project: a header with its numbers and links, then one
numbered section per part of the story. Returns a list of trees, one per block."
  (destructuring-bind (&key name slug summary tags links stats video sections
                         diagram funnel gallery &allow-other-keys) project
    ;; MULTIPLE-VALUE-BIND catches the values CASE-STUDY-SOURCES returns.
    (multiple-value-bind (hero-panel part-panels diagram-panel funnel-panel gallery-panel)
        (case-study-sources project)
      (let ((parts
              ;; One (heading panel content) list per part of the story.
              ;; (heading . paragraphs) splits ("How it works" "p1" "p2") into the
              ;; first element and the rest of the list.
              (loop for (heading . paragraphs) in sections
                    for panel in part-panels
                    collect (list heading panel
                                  (list `(:div :class "prose" :data-reveal t
                                           ,@(mapcar (lambda (p) `(:p ,p)) paragraphs))))))
            (photos (when gallery (gallery gallery name))))
        ;; A diagram or a funnel becomes a part of its own, right after the part
        ;; named by its :after. The photos, if there are any, come last.
        (when diagram
          (setf parts (insert-part parts
                                   (list (getf diagram :heading) diagram-panel
                                         (list (diagram-figure diagram (format nil "~a-diagram" slug))))
                                   (getf diagram :after))))
        (when funnel
          (setf parts (insert-part parts
                                   (list (getf funnel :heading) funnel-panel (list (funnel funnel)))
                                   (getf funnel :after))))
        (when photos
          (setf parts (append parts
                              (list (list (getf gallery :heading) gallery-panel (list photos))))))
        (case-study-page name summary tags links stats video hero-panel parts)))))

(defun case-study-page (name summary tags links stats video hero-panel parts)
  "The trees of a case-study page: the header, the demo video if there is one,
then one numbered section per part. PARTS is a list of (heading panel content)."
  `((:div :class "hero case-hero"
      ,@(with-source hero-panel
          `(:p :class "eyebrow" :data-reveal t :style ,(stagger 0)
             (:a :class "back" :href "./#projects" (:span :aria-hidden "true" "← ") "All work"))
          `(:h1 :data-reveal t :style ,(stagger 1) ,name)
          `(:p :class "intro" :data-reveal t :style ,(stagger 2) ,summary)
          `(:div :data-reveal t :style ,(stagger 3)
             (:ul :class "tags" ,@(mapcar (lambda (tag) `(:li ,tag)) tags))
             (:ul :class "links"
              ,@(loop for (label url) in links
                      collect `(:li (:a :class "pill" :href ,url ,label
                                        (:span :aria-hidden "true" " ↗"))))))
          `(:ul :class "stats" :data-reveal t :style ,(stagger 4)
             ,@(loop for (value label) in stats
                     collect `(:li (:strong ,value) (:span ,label))))))
    ;; ASSOC finds the ("Live demo" url) pair in LINKS, if there is one.
    ,(when video
       (demo-video video (second (assoc "Live demo" links :test #'equal))))
    ,@(loop for (heading panel content) in parts
            for n from 1
            collect (section-with-source (format nil "part-~d" n) n heading panel content))))

(defun about ()
  "The About text, with the portrait beside it once static/media/portrait.jpg
exists (*ABOUT-PHOTO* in content.lisp). Without the photo it's the text alone:
no empty box waiting for a picture."
  (let ((text `(:div :class "prose" :data-reveal t
                 ,@(mapcar (lambda (paragraph) `(:p ,paragraph)) *about*)))
        (photo (destructuring-bind (&key file alt) *about-photo*
                 (picture file alt :class "about-photo"))))
    (if photo
        `(:div :class "about-grid"
           ,text
           (:figure :class "about-figure" :data-reveal t :style ,(stagger 1) ,photo))
        text)))

;;; ------------------------------------------------------------------
;;; Pages
;;; ------------------------------------------------------------------

(defpage "index.html" (:title *name* :description *intro* :home-page t)
  (hero)
  (section "about" 1 "About"
           (about))
  (section "work" 2 "Experience"
           (timeline *experience*))
  (section "projects" 3 "Projects"
           `(:p :class "section-intro" :data-reveal t ,*projects-intro*)
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
                                             :description (getf project :summary)
                                             :toc t
                                             :rail-title (getf project :name))
              (case-study project)))))
      *projects*)

;;; GitHub Pages serves 404.html for *any* missing address, even a deep one like
;;; /victor_website/a/b. From there a relative link such as "style.css" would point
;;; to /victor_website/a/style.css, which doesn't exist, so this one page uses
;;; absolute links that start with *base-path* (see content.lisp).

(defpage "404.html" (:title "Not found"
                     :description "This page doesn't exist. The home page has everything else."
                     :base *base-path* :noindex t)
  `(:div :class "hero"
     (:p :class "eyebrow" "404")
     (:h1 "Nothing " (:em "here") ".")
     (:p :class "intro" (:a :href ,*base-path* "Back home" (:span :aria-hidden "true" " →")))))
