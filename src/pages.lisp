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
    :narrow (:step 120 :side 122 :w 112 :h 54)))  ; phones: always top to bottom

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
                 (edge-id (i) (format nil "~a-e~d" id i)))
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
             ;; In (from nil to label . options), NIL skips the arrow symbol and
             ;; the dot catches whatever comes after the label, like :label-at.
             (:g :class "edge-labels"
              ,@(loop for (from nil to label . options) in edges
                      for i from 0
                      when label
                        collect
                        (let* ((points (route from to))
                               (at (getf options :label-at))
                               (point (if (and (= (length points) 5) (not at))
                                          ;; half a gap from the start, towards the 2nd point
                                          (destructuring-bind ((m c) (m2 c2) &rest curve) points
                                            (declare (ignore c2 curve))
                                            (list (+ m (* (signum (- m2 m)) (- step (* 2 hm)) 1/2)) c))
                                          (bezier-point (last points 4) (or at 0.5)))))
                          ;; A small rect in the page color hides the line behind
                          ;; the label, spaces included. The font is monospaced,
                          ;; so every character is about 6.5 units wide.
                          (destructuring-bind (x y) (xy point)
                            (let ((half (+ 4 (* 3.25 (length label)))))
                              `(:g :class "edge-label" :style ,(stagger i)
                                 (:rect :x ,(num (- x half)) :y ,(num (- y 8))
                                        :width ,(num (* 2 half)) :height 16 :rx 3)
                                 (:text :x ,(num x) :y ,(num (+ y 3.5)) ,label)))))))
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
;;; The demo video (only when its file exists)
;;; ------------------------------------------------------------------

(defun static-path (file)
  "Where FILE sits in the static/ folder, e.g. static/event-market.mp4."
  (merge-pathnames (concatenate 'string "static/" file) (project-root)))

(defun mp4-size (path)
  "The (width height) of the video in the .mp4 file at PATH, or NIL if we can't
tell. An .mp4 file is a list of \"boxes\", each one starting with its size (4 bytes)
and a 4-letter type. The \"tkhd\" box (track header) ends with the track's width
and height, 4 bytes each, as \"16.16 fixed point\" numbers: the top 16 bits are the
whole part, so (ASH n -16) drops the fraction. A sound track's width is 0, so we
keep the first track whose width isn't. Knowing the size lets the page reserve the
video's space before it loads, so nothing below it jumps."
  (let ((bytes (with-open-file (in path :element-type '(unsigned-byte 8))
                 (let ((all (make-array (file-length in) :element-type '(unsigned-byte 8))))
                   (read-sequence all in)
                   all)))
        (tag (map 'vector #'char-code "tkhd")))
    (flet ((u32 (i)                     ; 4 bytes at I as one number, biggest byte first
             (if (and (>= i 0) (<= (+ i 4) (length bytes)))
                 (logior (ash (aref bytes i) 24) (ash (aref bytes (+ i 1)) 16)
                         (ash (aref bytes (+ i 2)) 8) (aref bytes (+ i 3)))
                 0)))
      (loop for at = (search tag bytes) then (search tag bytes :start2 (1+ at))
            while at
            do (let* ((start (- at 4))
                      (size (u32 start))
                      (width (ash (u32 (+ start size -8)) -16))
                      (height (ash (u32 (+ start size -4)) -16)))
                 (when (and (>= start 0) (>= size 84) (plusp width) (plusp height))
                   (return (list width height))))))))

(defun demo-video (video live-url)
  "A looping, silent screen recording, or NIL when the file isn't in static/
(PROBE-FILE returns NIL for a missing file). VIDEO is the project's :video plist.
The HTML has `controls`, so without JavaScript you can still stop it; motion.js
swaps them for a small Pause button, and under reduced motion it pauses the video."
  (destructuring-bind (&key file poster caption) video
    (when (and file (probe-file (static-path file)))
      (destructuring-bind (width height)
          (or (mp4-size (static-path file)) '(1600 1000)) ; a guess if the file won't say
        `(:figure :class "demo" :data-reveal t
           (:div :class "demo-frame"
            (:video :class "demo-video" :data-demo-video t
                    :width ,width :height ,height
                    :poster ,(when (and poster (probe-file (static-path poster))) poster)
                    :autoplay t :muted t :loop t :playsinline t :preload "metadata" :controls t
             (:source :src ,file :type "video/mp4"))
            (:button :type "button" :class "diagram-toggle demo-toggle" :data-demo-toggle t
                     :hidden t :aria-label "Pause video" "Pause"))
           (:figcaption :class "diagram-caption"
            (:span ,caption
                   ,(when live-url
                      `(" " (:a :href ,live-url "Live demo" (:span :class "arrow" " ↗")))))))))))

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
  (destructuring-bind (&key name slug summary tags links stats video sections diagram
                       &allow-other-keys) project
    ;; MULTIPLE-VALUE-BIND catches the values CASE-STUDY-SOURCES returns.
    (multiple-value-bind (hero-panel part-panels diagram-panel) (case-study-sources project)
      (let ((parts
              ;; One (heading panel content) list per part of the story.
              ;; (heading . paragraphs) splits ("How it works" "p1" "p2") into the
              ;; first element and the rest of the list.
              (loop for (heading . paragraphs) in sections
                    for panel in part-panels
                    collect (list heading panel
                                  (list `(:div :class "prose" :data-reveal t
                                           ,@(mapcar (lambda (p) `(:p ,p)) paragraphs)))))))
        ;; A diagram becomes a part of its own, right after the part named by its
        ;; :after (or at the end if no part has that name). The parts are numbered
        ;; afterwards, so the numbers stay in order either way.
        (when diagram
          (let ((at (let ((after (position (getf diagram :after) parts
                                           :key #'first :test #'equal)))
                      (if after (1+ after) (length parts)))))
            (setf parts (append (subseq parts 0 at)
                                (list (list (getf diagram :heading) diagram-panel
                                            (list (diagram-figure diagram
                                                                  (format nil "~a-diagram" slug)))))
                                (subseq parts at)))))
        (case-study-page name summary tags links stats video hero-panel parts)))))

(defun case-study-page (name summary tags links stats video hero-panel parts)
  "The trees of a case-study page: the header, the demo video if there is one,
then one numbered section per part. PARTS is a list of (heading panel content)."
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
    ;; ASSOC finds the ("Live demo" url) pair in LINKS, if there is one.
    ,(when video
       (demo-video video (second (assoc "Live demo" links :test #'equal))))
    ,@(loop for (heading panel content) in parts
            for n from 1
            collect (section-with-source (format nil "part-~d" n) n heading panel content))))

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
