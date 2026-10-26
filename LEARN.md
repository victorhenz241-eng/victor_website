# How the moving parts work

This guide explains every effect on the site in plain language first, then shows
where the code lives. Read it alongside the files.

## Start here: a tour of the code

The whole site is about 2,100 lines of Lisp and 800 lines of JavaScript. You can
read all of it. This is a good order, with what to look for in each file.

| # | File | What it does | Read it for |
|---|---|---|---|
| 1 | `victor-site.asd`, `src/package.lisp` | which files make up the project, in which order; the package they live in | ASDF, packages |
| 2 | `src/html.lisp` | turns Lisp lists into HTML text (~60 lines) | recursion, `cond`, streams |
| 3 | `src/content.lisp` | every sentence on the site, as data | plists, quoted lists |
| 4 | `src/pages.lisp` | the layout, the building blocks, the diagrams, the pages | backquote, `loop`, `destructuring-bind`, the `defpage` macro |
| 5 | `src/build.lisp` | renders every page and writes `public/` | files, timing, special variables |
| 6 | `src/stats.lisp` | the footer's measured numbers | fixed-point iteration, bytes vs characters |
| 7 | `src/media.lisp` | photos and videos: only when the file exists, with their size read from the file's bytes | bytes, `probe-file`, `directory` |
| 8 | `src/source.lisp` | the "(λ) source" view: cuts the real Lisp out of its own files and colors it | `read`, `file-position`, a tokenizer |
| 9 | `static/style.css` | every color, size and transition | custom properties, transitions vs keyframes |
| 10 | `static/motion.js` | scroll reveal, terminal, header, nav, diagrams, videos | IntersectionObserver, async/await, promises |
| 11 | `static/command-menu.js` | the ⌘K menu | `<dialog>`, the ARIA combobox |
| 12 | `static/source-view.js` | the "(λ) source" switch | `<template>`, localStorage |

A good first session: build once, open `public/index.html` in an editor next to
`src/pages.lisp`, and find the Lisp that wrote each part of the HTML.

### The concepts, one by one

Each one is used somewhere real in this project. The function names are the
places to look (search for them in the file).

**Lisp**

- **Packages and ASDF.** A *package* is a namespace: `victor-site::build` and some
  other library's `build` can't clash. ASDF is Lisp's build tool: the `.asd` file
  lists the source files and loads them in order. → `src/package.lisp`,
  `victor-site.asd`, `make.lisp`.
- **Lists as HTML.** `(:a :href "x" "text")` is plain data. `render` walks it and
  writes `<a href="x">text</a>`. → `render` in `src/html.lisp`.
- **Backquote, comma, comma-at.** `` `(:p ,x) `` is a template: the list is copied
  as written, except `,x`, which is replaced by the value of `x`. `,@list` splices
  a list's elements in, without the outer parentheses. → almost every function in
  `src/pages.lisp`, e.g. `site-header` and `timeline`.
  ([Practical Common Lisp, ch. 3](https://gigamonkeys.com/book/practical-a-simple-database.html))
- **Plists.** A *property list* alternates keys and values: `(:role "Intern" :org "Canal+")`.
  `(getf plist :org)` reads one value. Every entry in `content.lisp` is one. →
  `*experience*`, `*projects*` in `src/content.lisp`; `getf` in `commands`.
- **`destructuring-bind` with `&key` and `&allow-other-keys`.** It takes a plist apart
  into variables in one go: `(destructuring-bind (&key role org &allow-other-keys) entry ...)`.
  `&key` names the keys you want; `&allow-other-keys` says "the plist may have more
  keys, ignore them" (without it, an unexpected key is an error, which is a useful
  safety net). → `timeline` (strict) and `project-card` (relaxed) in `src/pages.lisp`.
- **`loop`.** Lisp's loop has its own small language: `for x in list`, `for i from 0`,
  `collect`, `when`, and destructuring like `for (label url) in *links*`. →
  `numbered`, `commands`, `link-list` in `src/pages.lisp`.
  ([PCL, ch. 22](https://gigamonkeys.com/book/loop-for-black-belts.html))
- **Local functions: `flet` and `labels`.** Small helpers that exist only inside
  one function. `labels` lets them call each other. → `diagram-svg` (`center`,
  `route`, `label-box`...) and `highlight` in `src/source.lisp`.
- **Several return values.** A function can return more than one value with
  `values`; `multiple-value-bind` catches them. → `split-attributes` in
  `src/html.lisp`, `case-study-sources` and `case-study`.
- **Closures, and why the pages use `mapc`.** A `lambda` remembers the variables
  around it (it *closes over* them). Each project page is a stored `lambda` that
  remembers its `project`. With `dolist` all the lambdas would share one variable
  and every page would show the last project; `mapc` calls a fresh function for
  each project, so each lambda gets its own. → the `mapc` near the end of
  `src/pages.lisp`.
- **Macros: `defpage`.** A macro is a function that runs *before* your code is
  compiled and returns new code to put in its place. `defpage` turns a short page
  definition into "store a lambda that calls `layout`". It uses `gensym` for a
  helper variable, so the name can't clash with yours. Try
  `(macroexpand-1 '(defpage "x.html" (:title "X") '(:p "hi")))` in the REPL.
  → `defpage` in `src/pages.lisp`. ([PCL, ch. 8](https://gigamonkeys.com/book/macros-defining-your-own.html))
- **Special variables and `let`.** A variable made with `defvar`/`defparameter` is
  *special*: a `let` around a call gives it a new value for everything that call
  does, however deep, then restores the old value. `build` binds `*build-stats*`
  this way and `layout` reads it without being passed anything. → `*build-stats*`
  in `src/stats.lisp`, `build` in `src/build.lisp`.
  ([PCL, ch. 6](https://gigamonkeys.com/book/variables.html))
- **`read` and `file-position`.** `read` turns text into a Lisp form; noting the
  stream's position before and after tells you exactly which characters it took.
  That's how the source view cuts out the real text of a form. → `form-slices` in
  `src/source.lisp` (LEARN Effect 9).
- **A tokenizer.** Walking a string one character at a time and labelling runs of
  characters ("this is a string", "this is a comment"). → `highlight`, then
  `split-lines` and `code-line` in `src/source.lisp`.
- **Reading a file as bytes.** `(with-open-file (in path :element-type '(unsigned-byte 8)) ...)`
  opens a file as numbers from 0 to 255 instead of characters. Every image format
  starts with a small header that says how big the picture is; reading a few bytes
  at the right place gives you its width and height without decoding it. →
  `png-size`, `jpeg-size` and `mp4-size` in `src/media.lisp` (Effect 13).
- **Fixed-point iteration.** The page's size is written inside the page, and writing
  it changes the size. So: guess, measure, guess again with the measurement, until
  the guess stops changing. → `fill-in-page-size` in `src/stats.lisp` (Effect 10).

**Browser**

- **Progressive enhancement.** The HTML is complete on its own; CSS and JS only add
  to it. Turn JS off and nothing is missing. → the `.js` class at the top of
  `motion.js`; the `hidden` buttons that JS reveals.
- **CSS custom properties.** `--i: 3` on an element is a variable the stylesheet can
  read with `var(--i)`. Lisp writes them (`stagger`), CSS does math with them
  (`calc(var(--i) * 90ms)`). → section 9 of `style.css`.
- **Transitions vs keyframes.** A transition animates a *change* (a class added);
  `@keyframes` runs by itself. → `.js [data-reveal]` vs `@keyframes blink`.
- **IntersectionObserver.** The browser tells you when an element enters or leaves
  the screen, instead of you checking on every scroll. Used for the reveal, the
  terminal, the header, the nav, the diagrams and the video. → `static/motion.js` (Effects 1, 3, 6, 7, 11, 12).
- **async/await and promises.** A promise is a value that arrives later; `await`
  pauses a function until it does, without freezing the page. → `play()` (the
  terminal) and `gate()` in `motion.js` (Effect 3).
- **`<dialog>`.** A native pop-up: `showModal()` traps the focus, closes on Esc and
  dims the page. → `static/command-menu.js` (Effect 8).
- **The ARIA combobox.** A text box that controls a list; the focus stays in the box
  and `aria-activedescendant` says which option is selected. → `select` in
  `command-menu.js`.
- **SVG and `stroke-dashoffset`.** Lines that draw themselves: a dash as long as
  the line, slid into view. → section 12 of `style.css` (Effect 11).
- **localStorage with try/catch.** The browser's small per-site memory. It can
  throw (private windows), so every use is wrapped. → `load`/`save` in
  `static/source-view.js`.
- **Lazy loading.** `<img loading="lazy">` lets the browser skip a picture until
  you scroll near it; `decoding="async"` lets it decode the picture without
  freezing the page. Both are just attributes. → `picture` in `src/media.lisp` (Effect 13).
- **Video autoplay rules.** Browsers only let a page start a video by itself when it
  is `muted`, and iPhones also want `playsinline`. We go further: no `autoplay`
  attribute at all; JavaScript plays a card's loop while it's on screen, and only
  without reduced motion. → section 7 of `motion.js` (Effect 13).
- **`object-fit` and `aspect-ratio`.** `aspect-ratio: 16 / 10` gives a box its shape
  before anything loads; `object-fit: cover` fills that box with a photo or video and
  trims what sticks out, like a picture in a frame. → `.card-media` and `.about-photo`
  in `style.css`.
- **`prefers-reduced-motion`.** The OS setting "reduce motion". The CSS media query
  at the end of `style.css` and `reduceMotion` at the top of `motion.js` honor it.

### Exercises

Small, real changes. Rebuild after each one (`sbcl --script make.lisp`) and look.

1. **Add a fourth case study.** Give "This website" a `:slug "this-website"`, a
   few `:stats` and two or three `:sections`, in your own words (only true facts).
   Rebuild: a new page appears, the card's arrow changes, the ⌘K menu gets an entry,
   and its source view works. You wrote no new code. Why? Follow `:slug` through
   `pages.lisp` to find out.
2. **Add a box to a diagram.** In the Radar's `:diagram`, add
   `(caddy :at (0 3) :label "Caddy" :note "HTTPS proxy")` and the arrow
   `(caddy -> bot "webhook")`. Check the wide picture, the phone picture (narrow
   window) and "The diagram as text". Then put two labels in the same gap and watch
   one slide along its arrow.
3. **Read a macro's output.** Run `(macroexpand-1 '(defpage "x.html" (:title "X") '(:p "hi")))`
   in the REPL. Find `layout` in the result, and the `gensym` variable (a symbol
   like `#:FILE123`). Then write a tiny page of your own with `defpage`.
4. **Watch the fixed point.** Add `(format t "round ~d: ~d~%" round size)` inside
   the loop of `fill-in-page-size`, rebuild, and read the rounds in the terminal.
   Remove it afterwards.
5. **Exaggerate the motion.** In `style.css`, change the reveal's `16px` to `60px`
   and `90ms` to `300ms`. Reload, then bring them back. Do the same with the
   diagram's `110ms`.
6. **Teach the tokenizer numbers.** In `highlight` (`src/source.lisp`), color numbers
   like `4.0` and `120` with a new class `c-num`, and give it a color in section 11
   of the CSS (keep 4.5:1 contrast on `--surface`, see "Contrast, checked" below).
7. **Think about a tokenizer bug.** In `(loop for (i item) in ...)`, the `i` is
   colored like an operator, because it comes right after `(`. Can you think of a
   rule that fixes this case? What would your rule break? (There's no perfect
   answer without really parsing Lisp: that's the point of the exercise.)
8. **Add a command to the ⌘K menu.** In `commands` (`pages.lisp`), add an action
   `"copy-email"`, and in `command-menu.js` handle it with
   `navigator.clipboard.writeText(...)` (it returns a promise: what should happen
   if it fails?).

---

## The big picture: three layers, three jobs

```
content.lisp ─┐
              ├─► pages.lisp ─► html.lisp ─► public/index.html   STRUCTURE (Lisp)
              │                                  │
static/style.css ────────────────────────────────┤               LOOK + MOTION (CSS)
static/motion.js ────────────────────────────────┘               BEHAVIOUR (JS)
```

- **Lisp** decides *what* is on the page and *marks* things that should move.
- **CSS** decides *how* things look and *how* they move.
- **JavaScript** decides *when* they move, for example "now, because you scrolled here".

Sites like hansard.dev are built the same way. They use a framework called Astro
where you use Lisp, but the output is still HTML, CSS and a little JS. **React isn't
what makes things move.** React is for interfaces whose content changes a lot while
you use them, like Gmail. A personal site doesn't need it.

---

## Effect 1: things fade in as you scroll

**In plain words:** every block starts slightly transparent and 16px too low. When it
enters the screen, JavaScript adds a class to it, and CSS slides it smoothly into place.

**Step by step:**

1. **Lisp marks it.** In `pages.lisp`: `(:p :data-reveal t ...)` becomes `<p data-reveal>`.
   The attribute means nothing by itself. It's a label the CSS and JS look for.
2. **CSS sets the starting state** (`style.css`, section 9):
   ```css
   .js [data-reveal]            { opacity: 0; transform: translateY(16px); transition: ... }
   .js [data-reveal].is-visible { opacity: 1; transform: none; }
   ```
   A **transition** means "when this property changes, don't jump: animate over 0.7s".
3. **JS flips the switch** (`motion.js`). An **IntersectionObserver** is a browser
   feature that calls your code when an element enters the screen. We add `is-visible`,
   the property changes, and the transition animates it.

**A trap we fell into: `threshold`.** The observer's `threshold` is "how much of the
element must be visible", as a fraction of the element. It used to be `0.15`. That
sounds harmless, but a block taller than about seven screens can *never* be 15%
visible, so it would never appear. Chrome even reports it as "not intersecting" the
whole time. Now the threshold is `0` (any part of it) and the `rootMargin`
(`-10%` at the bottom) gives the "a little after it appears" feel instead.

**Why `.js` in front?** JS adds the class `js` to the page when it starts. If JS fails
to load, `.js` never exists, nothing is hidden, and the content is still there.
This idea is called *progressive enhancement*.

**Stagger (one item after another):** Lisp writes `style="--i: 2"` on the third item.
The CSS reads it: `transition-delay: calc(var(--i) * 90ms)`. Item 0 waits 0ms, item 1
waits 90ms, item 2 waits 180ms… Lisp counts and CSS waits.
Look at `stagger` and `numbered` in `pages.lisp`.

**Try it:** change `90ms` to `300ms` and `16px` to `60px`, rebuild, and reload.
Exaggerating like this shows what the effect is doing. Then turn it back down until
you barely notice it, which is usually the right amount.

---

## Effect 2: the timeline line draws itself

**In plain words:** the vertical line is really a thin rectangle with its height
squashed to zero. When it becomes visible, it grows back to full height from the top.

```css
.timeline::before                    { transform: scaleY(0); transform-origin: top; }
.timeline.is-visible::before         { transform: scaleY(1); }
```

`::before` creates an extra element in CSS without touching the HTML. That's why
the line can move separately from the entries. The entries then come in one after
another, using the same stagger trick with a bigger delay.

**Why `transform` and not `height`?** Browsers can animate `transform` and `opacity`
very cheaply because the graphics card does the work. Animating `height`, `top` or
`margin` makes the browser recalculate the whole layout every frame, which can stutter.
**Rule of thumb: animate only `transform` and `opacity`.**

---

## Effect 3: the typing terminal

**In plain words:** Lisp writes the whole REPL session into the HTML. JS saves each
line's text, empties the lines, and types them back one character at a time, in a loop.

- The text comes from `*repl*` in `content.lisp`. You edit Lisp data and the animation changes.
- `async function play()` reads from top to bottom like a script. `await wait(40)`
  means "pause 40ms here, without freezing the page". That's what `async`/`await` is for.
- The rhythm is `28 + Math.random() * 45` ms per character. The randomness is what
  makes it feel like a person typing. Try a fixed `40` and compare.
- **Pause button:** if something moves for more than 5 seconds, users should be able
  to stop it, as accessibility guidelines (WCAG) require. `wait()` sleeps, then
  waits at a **gate** while the animation is paused or scrolled out of sight.
- **The gate** (`gate()` in `motion.js`) is a small promise trick. `await
  resume.pass()` continues at once when the animation may run. Otherwise it returns
  a promise that isn't resolved yet, and the loop simply stops there: no timer, no
  work. The promise's `resolve` function is kept in a list, and `resume.check()`
  (called by the Pause button and by an IntersectionObserver) calls them all when
  the animation may run again. An older version checked "am I still paused?" every
  100ms, which kept a timer busy for nothing. The diagrams' walk uses the same gate.
- **Blinking cursor:** this is a CSS **keyframes** animation (`@keyframes blink`). A
  transition waits for something to change. A keyframes animation runs by itself in a loop.

---

## Effect 4: small hover reactions

Cards rise 3px and gain a shadow, the ↗ arrow nudges, and the pills lift by 1px.
These are all plain `transition` on `:hover`. Each one is small, but together they
make the page feel like it responds to you.

## Effect 5: the frosted header

`position: sticky` keeps the header at the top. A semi-transparent background
(`color-mix(... 80%, transparent)`) plus `backdrop-filter: blur(12px)` blurs whatever
scrolls underneath it.

---

## Effect 6: the header shrinks when you scroll

**In plain words:** at the top of the page the header blends into the page. Once you
scroll a little, it gets 8px shorter, the name shrinks slightly, and a thin line
appears under it, so it reads as a bar sitting on top of the content.

**Step by step:**

1. **JS needs one fact:** "is the top of the page still on screen?". `motion.js`
   (section 3) adds an invisible 6rem-tall `<div class="scroll-sentinel">` at the very
   top of the page and watches it with an **IntersectionObserver**, the same tool as
   Effect 1. When the sentinel leaves the screen, the header gets the class `is-scrolled`.
   When it comes back, the class goes away.
2. **CSS does the look** (`style.css`, section 3):
   ```css
   .site-header.is-scrolled               { transform: translateY(-0.5rem); }
   .site-header.is-scrolled .header-inner { transform: translateY(0.25rem); }
   ```
   The header slides up 8px (its top goes off screen) and its content slides down 4px,
   so it *looks* 8px shorter with everything still centred.

**Why not listen to `scroll`?** That works too, but the `scroll` event fires up to 60
times a second, and you'd have to throttle it with `requestAnimationFrame`. The
observer only calls you when the answer changes: once on the way down, once on the way up.

**Why not change `height`?** The header is part of the page flow, so a shorter header
would pull the whole page up by 8px while you're reading. Moving it with `transform`
changes nothing around it, and it's cheap to animate (see Effect 2).

**The border's fallback.** At the top of the page the header's bottom border is
hidden, and it fades in once you scroll. That hiding only happens once `motion.js`
has added `.tracks-scroll` to the header, right after it starts watching the
sentinel. In a browser without IntersectionObserver (or with JS off) the class never
comes, so the border just stays. A rule like "hide it whenever JS runs" would have
left those browsers with no border at all.

**Try it:** make the sentinel `height: 30rem` so the header changes later, or remove
`.header-inner`'s transform and watch the content stop being centred.

---

## Effect 7: the nav shows where you are

**In plain words:** on the home page, the nav link of the section you're reading turns
dark and gets a thin line under it that grows from the left.

1. **Which links?** On the home page Lisp writes the nav links as plain `#about`; on
   other pages as `./#about` (see Effect 8 for why). So `motion.js` (section 4) keeps
   only the links whose `href` starts with `#` and whose section exists. On a project
   page or the 404 nothing gets highlighted. We considered lighting up "Projects" on
   project pages, but that link goes to the home page, not to the page you're on, so
   it would be slightly misleading. The "← All work" link already tells you where you are.
2. **Which section is "current"?** An IntersectionObserver with
   `rootMargin: "-35% 0px -60% 0px"`. A negative margin *shrinks* the area being watched,
   here to a thin band about a third of the way down the screen, which is roughly where
   you're reading. The last section crossing that band wins.
3. **The end of the page:** Contact is short, so it might never reach the band. A second
   observer watches the footer: once it's on screen, Contact wins.
4. **Marking it:** JS sets `aria-current="true"` on the link. Screen readers announce
   it ("current"), and the CSS uses the same attribute for the look:
   ```css
   .site-header nav a[aria-current="true"]::after { transform: scaleX(1); }
   ```
   One attribute does both jobs, so the look and what screen readers say never disagree.

The line is a `::after` squashed to `scaleX(0)`, the same trick as the timeline in Effect 2,
turned sideways.

---

## Effect 8: the ⌘K command menu

**In plain words:** press ⌘K (Ctrl+K on Windows), or `/`, or click "Search" in the
header. A small window opens. Type to filter, use ↑ ↓ to choose, Enter to go, Esc to close.

**Lisp writes the whole menu.** `command-menu` in `pages.lisp` builds a `<dialog>` with
every entry already inside: the home sections (from `*home-sections*`, the same list
the header uses), one entry per project page (`:slug`), one per project with a `:url`,
and your `*links*`. So adding a project to `content.lisp` adds it to the menu, with
no JS change. `commands` takes `home` like `site-header` does. `layout` picks it:

| Page | `home` | Link to About |
|---|---|---|
| home page (`:home-page t` in its `defpage`) | `""` | `#about` |
| a project page | `"./"` | `./#about` |
| the 404 page | `*base-path*` | `/victor_website/#about` |

Why not `./#about` everywhere? At `/victor_website/` it works, but if someone opens
`/victor_website/index.html`, then `./` means `/victor_website/`, a *different* address,
so the browser reloads the page instead of just scrolling. A bare `#about` always means
"this page". (The home link becomes `#top` on the home page, for the same reason.)

**The browser does the hard parts.** `<dialog>` opened with `showModal()`:
- makes the rest of the page "inert": it can't be clicked or tabbed to while the menu is open,
- closes on Esc,
- dims the page behind it (the `::backdrop`),
- and puts the focus back where it was when it closes.

**JS does the rest** (`static/command-menu.js`):
- **Filtering:** each word you type must appear in the entry's text, hint, group name or
  tags. Everything is lowercased and accents are removed, so `supelec` would also
  find an entry spelled `Supélec`.
- **The selection:** the focus never leaves the text box. Instead, `aria-activedescendant`
  on the text box holds the `id` of the selected option, and screen readers read that
  option out. This is the ARIA *combobox* pattern: a text box that controls a *listbox*.
- **Clicking outside:** the panel fills the whole dialog, so a click whose target is the
  dialog itself must have landed on the backdrop.

**Progressive enhancement again:** the "Search" button has the `hidden` attribute in the
HTML, and JS removes it. Without JS you never see a button that does nothing.

**The opening animation** is a `@keyframes` (fade + scale from 98%), not a transition:
the dialog jumps from `display: none` to visible, so a transition has no starting value.

**Try it:** add a fake project with a `:url` to `*projects*`, rebuild, press ⌘K and
search for it. Then remove it.

---

## Effect 9: "(λ) source" shows the Lisp behind the page

**In plain words:** press `(λ) source` in the header (or pick "Toggle source view" in
the ⌘K menu). Every section fades out and is replaced by the Lisp that produced it:
first the *data* from `content.lisp`, then the *render* call from `pages.lisp`. Press
again to go back. The choice is remembered on the next page.

The important word is *real*. Nothing is retyped: at build time Lisp opens its own
source files as text and cuts out the exact characters of each form, comments and
spacing included. Change a sentence in `content.lisp`, rebuild, and the source view
changes with it. The line numbers in each panel are the real ones too.

**Private notes: `;; private:`.** "Comments included" means every comment inside
those forms is published to every visitor. So there are two kinds of comment:
- a normal comment is part of the showcase: write it for a recruiter
  (`; mailto: makes the link open an email`);
- a comment that starts with `private:` is a note for you only. The build cuts it out
  of every panel, but it stays in the file:

```lisp
    ;; private: DRAFT, check these numbers      <- whole line: the line is dropped
    :url nil  ; private: repo not public yet    <- end of a line: only the comment goes
```

`strip-private-comments` (in `chunk`, section 2 of `source.lisp`) walks the text the way
the reader would, so a `;` inside a `"string"` or a `#\;` character is never mistaken
for a comment. Panels can then be a few lines shorter than the range they show.
Docstrings are code, not comments, so they're always shown: keep them neutral.
The rule is also written at the top of `content.lisp`.

**Step 1: read a file as text** (`src/source.lisp`, section 1). `source-text` returns
the whole of `src/content.lisp` as one string. Lisp code is just text until something
*reads* it.

**Step 2: let the reader find the forms.** Where does `(defparameter *about* ...)` end?
Counting parens by hand breaks on a `")"` inside a string or a comment. The Lisp
reader already knows all those rules, so we ask it:

```lisp
(file-position stream)                  ; where am I?          -> start
(read-preserving-whitespace stream)     ; read one whole form
(file-position stream)                  ; where am I now?      -> end
(subseq text start end)                 ; the form's original text
```

`READ` gives back the *data* (a list we can test, e.g. "is it a `defparameter` named
`*about*`?"), and the two positions give back the *text*. We get both at once. That's
`form-slices`. Three details:
- We read from a **string stream**, not the file: on a file, `file-position` counts
  bytes, and `é` takes two bytes, so the numbers wouldn't match the string.
- `skip-blanks` steps over spaces and `;` comments *before* noting the start, so
  the comment above a form doesn't end up in its slice.
- `read-preserving-whitespace` instead of `read`: plain `read` may eat the space
  after a form, so the end would be one character too far.

To go *inside* a list (one project inside `*projects*`, or one `(section ...)` call
inside `(defpage "index.html" ...)`), `elements` runs the same loop starting just
after the list's `(`. That's how a case-study page shows only its own project.

**Step 3: color it with a tokenizer** (`highlight`, section 3). It walks the text one
character at a time and recognises a few shapes: `;` to the end of the line is a
comment, `"` to the next unescaped `"` is a string, `:word` is a keyword, a symbol
right after `(` is an operator, parens and quote marks are punctuation, and `#\x`
is a single character (so `#\;` doesn't start a comment). Each piece
becomes `(:span :class "c-string" "...")`, plain Lisp data, so `html.lisp` escapes
it like any other text. A tokenizer doesn't need to *understand* Lisp, only to tell
these shapes apart.

The colors are gray steps plus one green for strings (the terminal's green, darker
in light mode). Each was checked to keep 4.5:1 contrast on the panel, even the dim parens.

**Long lines on a phone: a hanging indent.** In a `<pre>`, a line too long for the
screen wraps back to the left edge, under the parens, and the shape of the code is
lost. So `split-lines` cuts the colored pieces into lines (a docstring that spans
several lines is cut too, each piece keeping its color), and `code-line` makes each
line its own `<span style="--n:4">`, where `--n` is how many spaces the line starts
with. The CSS turns that into a hanging indent:

```css
.source code > span {
  display: block;
  padding-left: calc((var(--n, 0) + 2) * 1ch);   /* push the whole line right */
  text-indent: calc((var(--n, 0) + 2) * -1ch);   /* pull its first line back */
}
```

The first line starts where it always did; the wrapped part sits two characters
deeper than the line's start. `1ch` is the width of one character, and in a
monospaced font every character has that width.

**Step 4: hide it until asked.** `with-source` (in `source.lisp`) puts each panel in a
`<template>` next to the section's content. The browser parses a template but never
shows it, and screen readers and search engines skip it. **Without JavaScript the
page is exactly the same as before.** `static/source-view.js` copies the panels out
(hidden), shows the button, and does the swap.

**Step 5: the swap** (`source-view.js` + `style.css` section 11):
1. The old side gets `.is-leaving`: it fades out and lifts 4px (160ms).
2. Then the `hidden` attributes swap, and the new side starts from `.is-entering`
   (transparent, 6px low, its bottom 60% clipped away with `clip-path`). Removing
   the class lets the transition play: it fades up while the clip uncovers it from
   the top, like a page being printed. Each chunk of code follows the one above it
   by 70ms (the stagger trick from Effect 1).
3. Swapping changes every section's height, which would make the page jump. So just
   before the swap JS notes where the section you're reading sits on screen, and just
   after, scrolls by the difference. You stay on the same section.
4. Coming back with the source view already on, there's no animation and nothing to
   hold in place: the swap happens once, at load. If the address has a `#section`
   (the "← All work" link goes to `./#projects`), JS jumps to it again, because the
   browser's first jump was measured on the old, shorter layout.

`hidden` matters for accessibility: a screen reader reads either the content or the
code, never both. The button is a `<button aria-pressed>`, which screen readers
announce as a toggle ("source, toggle button, pressed"), and the CSS styles the
pressed state from that same attribute. With reduced motion, the swap is instant.
Hiding the hero would also hide the page's only `<h1>`, so the hero's panel carries
its own copy with `class="sr-only"` (`:heading` in `source-panel`): invisible, but
screen-reader users still land on a page with a title.

**Remembering the choice:** `localStorage` keeps a small value per site in the
browser. It can throw an error (private windows, blocked storage), so every use is
wrapped in `try { } catch { }`: if it fails, the site just doesn't remember.

**Try it:** add a comment inside `*education*` in `content.lisp`, rebuild, and open the
source view: your comment is there. Now start it with `private:`, rebuild: it's gone
from the page but still in your file. Then call `(form-slices (source-text
"content.lisp") 0)` in the REPL and look at the numbers.

---

## Effect 10: the footer measures its own build

**In plain words:** the last line of every footer reads something like
`SBCL 2.6.8 · 1,172 lines of Lisp · 4 pages rendered in 13 ms · this page 44,583 bytes · built 2026-10-25`.
Nobody typed those numbers in. The build measures each one while it runs, so they're
true every time you rebuild. Rebuild twice and the milliseconds will wobble a little.
That's real timing.

**Where each number comes from** (`src/stats.lisp`, used by `build` in `src/build.lisp`):

| Number | How it's measured |
|---|---|
| `SBCL 2.6.8` | `(lisp-implementation-type)` and `(lisp-implementation-version)` ask the running Lisp |
| lines of Lisp | `lines-of-lisp` reads every `src/*.lisp` and adds up the lines |
| `rendered in N ms` | a clock read before and after rendering every page (below) |
| `this page N bytes` | the size of the HTML file the line is written in, as saved on disk |
| `built …` | today's date in UTC: `(decode-universal-time (get-universal-time) 0)` |

**Measuring time in Lisp.** `(get-internal-real-time)` returns a wall-clock reading as
a whole number of *internal time units*. How long a unit lasts depends on the Lisp, and
the constant `internal-time-units-per-second` tells you (1,000,000 in SBCL, so one unit
is a microsecond). Read the clock, do the work, read it again, subtract, then convert:

```lisp
(round (* 1000 (- (get-internal-real-time) start))
       internal-time-units-per-second)        ; -> milliseconds
```

**What exactly is timed?** It has to be said precisely, or the number is a bit of a
lie. It's the time to turn the data into the HTML text of all 4 pages: building each
tree, reading the source files the "(λ) source" panels need, and rendering. It does
*not* include SBCL starting up, compiling the code, writing the files or copying
`static/`. That's why the footer says "rendered", not "built".

**The chicken-and-egg problem.** Two numbers live *inside* the page they describe.
The render time isn't known until every page is rendered, and the page size isn't
known until the page is finished. Yet the number itself is part of the page, and
writing it changes the size. The fix has two steps:

1. **Leave a marker.** While rendering, the footer gets `<!--render-ms-->` and
   `<!--page-bytes-->` (HTML comments, inserted with `:raw`) where the numbers will go.
   They can't clash with real text: every `<` in normal text is escaped to `&lt;`, so
   no sentence on the site, not even the source view, can contain a real `<!--`.
2. **Fill in, then measure until it agrees.** The render time is simply pasted in. For
   the size, `fill-in-page-size` guesses, measures and guesses again:
   ```
   guess 0       -> with "0" written in, the page is 44,578 bytes
   guess 44,578  -> with "44,578" written in, it's 44,583 bytes
   guess 44,583  -> still 44,583 bytes. The number describes itself. Done.
   ```
   Only the *number of digits* changes the size, so it settles in two or three rounds.
   (The value it settles on is called a *fixed point*.)

**Bytes are not characters.** `(length "é")` is 1, but saved as UTF-8 "é" takes 2
bytes, and "→" takes 3. The site is full of `·`, `→` and `λ`, so `length` would be
wrong. `utf-8-length` counts bytes the way the file will store them. Check it
yourself: `wc -c public/index.html` prints exactly the number in that page's footer.

**A special variable carries the numbers.** `*build-stats*` is made with `defvar`, so
it's *special* (dynamic): `build` wraps the rendering in `(let ((*build-stats* stats)) …)`
and `layout`, deep inside, sees that value without it being passed as an argument.
When you call a page function yourself in the REPL, it's `NIL` and the footer simply
leaves the stats line out. See *Practical Common Lisp*, chapter 6 ("Dynamic, a.k.a. Special, Variables").

**The dots that vanish when the line wraps (CSS).** Each item begins with a `·`
drawn by `::before`. The list is pulled `1.5em` to the left and its wrapper has
`overflow: hidden`. So the dot that would start a new line falls outside and is clipped.
`content: "·" / ""` gives the dot empty alternative text, so screen readers don't say
"middle dot" four times.

**Try it:** rebuild twice and compare the milliseconds. Add a paragraph to `*about*`,
rebuild, and watch the home page's byte count grow while the project pages' stay the
same. Then run `wc -c public/*.html` and check every footer.

---

## Effect 11: diagrams that Lisp draws and CSS animates

**In plain words:** each case study has a picture (the Internship Radar architecture,
the Event-Market Graph schema). Nobody drew it in a design tool. It's a `:diagram`
plist in `content.lisp`, and a Lisp function turns it into SVG. Add a box to the
data, rebuild, and the picture has one more box. Then the arrows draw themselves,
and either small dots travel along the pipeline or an example "agent walk" lights
up box after box.

### Step 1: SVG is just more tags

SVG is HTML's cousin for drawings. A box is `<rect x y width height>`, a label is
`<text x y>`, a line is `<path d="...">`. So `html.lisp` can write it like any
other tag: `(:rect :x 8 :y 8 :width 140 :height 54 :rx 8)`.

One catch: SVG comes from XML, where **case matters**. `viewBox` and `viewbox` are
different names. The Lisp reader upcases every symbol (`:viewBox` is read as
`:VIEWBOX`), and our renderer lowercases names, so the capital B is lost. Browsers
repair the common ones when they read HTML, but we write them right anyway:
`*mixed-case-names*` in `html.lisp` lists the SVG names with capitals, and
`markup-name` puts the capitals back. Try `(markup-name :viewbox)` in the REPL.

### Step 2: the data, then the geometry

```lisp
:nodes ((sweep :at (1 0) :label "Sweep" :note "n8n · daily 02:00") ...)
:edges ((sweep -> db "insert") (dedup <-> rust "all rows") ...)
```

- `:at (column row)` puts a box on a grid. `diagram-svg` (in `pages.lisp`) turns
  grid positions into SVG units with the numbers in `*diagram-sizes*`.
- `->` and `<->` are ordinary symbols. Lisp doesn't give them any meaning; we chose
  them because `(a -> b)` reads like an arrow. The code just checks `(eq arrow '<->)`.
- The geometry thinks in two directions, **main** (along the flow) and **cross**
  (across it), not x and y. That's why one function draws both pictures: the wide
  one flows left to right, the phone one flows top to bottom. Only the last step,
  `xy`, decides which direction is x.
- Each arrow is a **cubic Bezier curve**: `M start C control1, control2, end`. The
  curve starts and ends on the boxes and is pulled towards the two control points.
  Putting both control points halfway along the flow gives the soft S shape.
  `bezier-point` computes a point on the curve, which is where a label goes.
- **Labels make room for each other.** A label wants the middle of its arrow (or
  the spot `:label-at` asks for). But on the phone picture several arrows share one
  gap, and their labels used to touch. So each label checks its rectangle
  (`label-box`) against every box and every label already placed (`overlap-p`), and
  if it would overlap, it slides along its *own* arrow to the first free spot. The
  phone layout also has a little more room between rows (`:step 140` in
  `*diagram-sizes*`).
- An arrow longer than one step first runs straight along its lane (`L`), then bends
  in the last gap, so it never cuts through the boxes in between.

The text version under the picture (`diagram-text`) is generated from the same
data, so it can never disagree with the picture. Screen readers get it instead of
the SVG (`role="img"` plus a `<title>` and `<desc>`).

### Step 3: a line that draws itself (`stroke-dashoffset`)

Every SVG line can be dashed: `stroke-dasharray: 1 1` means "1 unit of line, 1 unit
of gap". `pathLength="1"` (written by Lisp) tells the browser to treat the whole
path as 1 unit long, whatever its real length. So the pattern is: the whole line,
then a gap as long as the line.

`stroke-dashoffset` slides that pattern along the path. At `1` the gap covers the
path: invisible. At `0` the line covers it: fully drawn. Animate from 1 to 0 and the
line seems to draw itself from its start:

```css
.js .diagram .edge-line          { stroke-dasharray: 1 1; stroke-dashoffset: 1; }
.js .diagram.is-drawn .edge-line { stroke-dashoffset: 0;
                                   transition: stroke-dashoffset 0.8s var(--ease)
                                               calc(300ms + var(--i) * 110ms); }
```

`--i` is the arrow's place in the data, so the arrows draw in the order you wrote
them. That's why the edges list is written in flow order.

**When it starts.** One observer watches for the figure reaching the middle half of
the screen (`rootMargin: "-25% 0px -25% 0px"`) and then adds `.is-drawn`, once. A
second one only asks "is any of it on screen?" and pauses the looping parts when
it isn't. (A first version waited for "30% of the figure visible", which a figure
taller than the screen may never reach.)
The walk uses the same trick on a second, thicker line laid over the arrow.
Each label sits on a small rect in the page color, which hides whatever line runs
under it, the walk's line included. So the label of an arrow the walk follows gets
the same `data-walk` step and lights up in ink with it: the path still reads as
one unbroken line.

### Step 4: motion along a path

`<animateMotion>` is SVG's own animation element: it moves its parent (a small
`<circle>`) along a path. `<mpath href="#edge-id">` points it at an arrow, so the
dot follows the exact curve Lisp computed.

- All the dots share one cycle. `keyTimes="0;0.041;0.288;1"` with `keyPoints="0;0;1;1"`
  means: wait at the start until 4% of the cycle, travel until 29%, then stay at the
  end. Each dot gets its own slice, so together they look like one parcel going box
  to box (`:pulse` in the data lists the boxes).
- `begin="indefinite"`: nothing moves until `motion.js` calls `beginElement()`,
  once the arrows are drawn. Without JS, or with reduced motion, they never start.
- `svg.pauseAnimations()` and `svg.unpauseAnimations()` freeze and resume every SVG
  animation in that `<svg>`. The Pause button uses them, and so does an
  IntersectionObserver that pauses the diagram while it's off screen.

(CSS `offset-path` can do the same job on HTML elements. Inside an SVG,
`<animateMotion>` is the simpler tool: it uses the path's own coordinates.)

### Step 5: the rules

- **More than 5 seconds of motion needs a pause control** (WCAG 2.2.2): the Pause
  button appears only once something loops, like the terminal's.
- **Reduced motion:** the picture is complete and still. No drawing, no dots, no walk.
- **No JS:** the `.js` class never appears, so nothing is hidden: complete and still.
- **Contrast:** lines and borders use `--muted`, at least 3:1 against the page in
  both themes. Colors come from the CSS tokens, so dark mode needs no extra work.

**Try it:** add a box to the Radar diagram, say
`(caddy :at (0 3) :label "Caddy" :note "HTTPS proxy")`, and an arrow
`(caddy -> bot "webhook")`. Rebuild. The wide picture, the phone picture and the text
version all change. Then swap two arrows in `:edges` and watch the drawing order change.

---

## Effect 12: the demo video slot

**In plain words:** if `static/event-market.mp4` exists when the site builds, the
Event-Market page shows it under the header. If it doesn't, the page has no video
and nothing breaks. `PROBE-FILE` returns the file's path if it exists and `NIL` if
not, so a `WHEN` around it does the job (`demo-video` in `pages.lisp`). The Cut
the Line page uses the same slot for a demo *with sound* (`:sound t`): that one gets
the browser's controls and `preload="none"`, so not a byte of it downloads until you
press play, and it never plays by itself.

`mp4-size` (now in `src/media.lisp`) reads the video's width and height straight from the file, so the
`<video>` gets `width`/`height` and the page reserves its space before it loads.
The `<video>` has no `autoplay` attribute: an attribute would start it even with
JavaScript off or with reduced motion on. Playing is opt-in instead. Without JS, or
under reduced motion, the browser's own controls stay and nothing moves until you
press play. Otherwise `motion.js` swaps those controls for a small Pause button and
calls `video.play()` while the video is on screen (and pauses it when it leaves),
unless you paused it yourself. `play()` returns a *promise* that fails if the browser
refuses to play (some do, to save data or battery), so the code catches that and the
button simply says "Play". How to record and compress the video: see README.

---

## Effect 13: media tiles, photos and the funnel

**In plain words:** the project cards lead with a picture: a short silent video
that plays while the card is on screen, or a photo. A project with no picture yet
doesn't get a fake one; its card draws something true from its own data instead (a
big "1st / 120", a small copy of its diagram or funnel, or the number of lines of Lisp,
counted during the build). The About section gets a photo beside the text the moment
`static/media/about-running.jpg` exists.

### Step 1: true by construction

`content.lisp` only *names* files: `:card (:video "media/cut-the-line-card.mp4" ...)`.
`media.lisp` checks each one with `probe-file` before writing any tag. No file, no
tag, so a missing photo can never become a broken-image icon. A gallery is a whole
folder: `media-folder` lists its `.jpg` files with `directory` and sorts them by
name, so `01.jpg`, `02.jpg`... come out in order, and an empty folder means no section.

### Step 2: the size, read from the bytes

If an `<img>` has no `width` and `height`, the browser doesn't know how tall it is
until it arrives, and everything below it jumps down ("layout shift"). So the build
opens each picture and reads its size:

- **PNG:** the width and height are always at bytes 16 and 20 (`png-size`).
- **JPEG:** a chain of segments, each starting with `#xFF`, a marker byte and its
  length. `jpeg-size` hops from one to the next until it finds a "start of frame"
  segment, which holds the height and the width.
- **MP4:** a list of boxes; the `tkhd` box ends with the track's size (`mp4-size`).

Try `(image-size "media/cut-the-line-poster.jpg")` in the REPL.

### Step 3: loading only what's needed

- `loading="lazy"` and `decoding="async"` on every `<img>` (`picture`): the browser
  fetches a photo only as it comes near the screen. The `:eager` option is for a
  picture visible as soon as the page opens, where lazy would only delay it.
- A card's loop has `preload="metadata"`: just enough to know its size and show the
  poster. A demo with sound has `preload="none"`.

### Step 4: who presses play

Browsers let a page start a video by itself only if it's `muted` (and, on iPhones,
`playsinline`). Our card videos have both, but no `autoplay` attribute. `motion.js`
(section 7) watches each one with an IntersectionObserver (`threshold: 0.5`: half of
it on screen) and plays it only then, pausing it when it leaves; hovering a card
plays it too. Anything that moves for more than 5 seconds needs a way to stop it, so
a Pause button appears once the video plays. With reduced motion, nothing runs: you
see the poster.

### Step 5: the frame and the crop

Every tile is a box with `aspect-ratio: 16 / 10`, and the video or photo inside gets
`width: 100%; height: 100%; object-fit: cover`: it fills the box and its edges are
trimmed if its shape differs. The About photo does the same with a 4:5 portrait
frame. The whole card is one link: the title's `<a>` has an invisible `::after`
layer stretched over the card (`position: absolute; inset: 0`).

### Step 6: the funnel

The Internship Radar funnel (`funnel` in `pages.lisp`) is an ordered list, so a
screen reader reads "~16,000 listings scanned". Each bar's length comes from Lisp as
`--w`, on a log scale (with a straight scale, 7 out of 16,000 would be invisible).
The bars start at `transform: scaleX(0)` and grow to full length when the funnel
scrolls into view, one after another (`--i`), with the same reveal as everything else.

### Preparing the files

`scripts/prepare-media.sh` (README, section 7) turns originals into web versions and
removes the photos' metadata. Plain `sips` keeps a phone photo's GPS position, so
the script uses a small Swift helper (Swift comes with macOS) and then checks the
result with `sips -g all`.

---

## The rule that applies to every effect: reduced motion

Some people get dizzy from animations and turn on "Reduce motion" in their OS.
`@media (prefers-reduced-motion: reduce)` in the CSS and `reduceMotion` in the JS
turn every effect off for them. Keep this in place as you add effects.

Turning motion off doesn't mean turning features off: with reduced motion the header
still shrinks, the nav still highlights, the menu still opens and the source view
still swaps. They just change
instantly instead of animating.

## Contrast, checked

Contrast is the difference in lightness between a color and what's behind it, as a
ratio from 1:1 (invisible) to 21:1 (black on white). The rules (WCAG AA): **text
needs 4.5:1**; **shapes that carry meaning** (an arrow, a focus line, a border you
need to see) **need 3:1**; pure decoration needs nothing. So each gray step has a job:

| Token | Light | Dark | Used for | On `--bg` | On `--surface` |
|---|---|---|---|---|---|
| `--text` | `#0e1114` | `#e8eaed` | text | 18.2 / 15.7 | 16.8 / 14.5 |
| `--muted` | `#5f646b` | `#9aa0a6` | secondary text, diagram lines | 5.7 / 7.2 | 5.3 / 6.6 |
| `--faint` | `#838990` | `#666b72` | arrows ↗ →, focus line, dots, hover borders (never text) | 3.4 / 3.5 | 3.1 / 3.3 |
| `--line` | `#e4e5e8` | `#23282d` | dividers and resting borders (decoration) | — | — |
| `--code-dim` | `#686d74` | `#80868d` | parens and comments in the source view | — | 4.6 / 4.8 |
| `--code-string` | `#2d6a3e` | `#9fd8a7` | strings in the source view | — | 5.7 / 10.7 |
| `--term-dim` | `#7d848c` | same | the terminal's prompt (on `--term-bg`) | 5.0 / 5.2 | — |

(Light / dark ratios.) `--faint` used to be lighter (2.3–2.9:1), which was too light
for the arrows on the cards and the line under the ⌘K search box, so it was darkened
just enough to pass 3:1 everywhere. The section numbers ("01", "02"...) used
`--faint` too, but they're *text*, so they now use `--text`.

**How the ratio is computed** (try it in Python or JS): for each color channel
`c = value / 255`, then `c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4`;
lightness `L = 0.2126 R + 0.7152 G + 0.0722 B`; ratio `(L1 + 0.05) / (L2 + 0.05)`,
lighter color on top.

## The `<head>`: what browsers and apps read

`layout` in `pages.lisp` writes the same `<head>` on every page:

- `<meta name="description">`: the snippet search engines show (every page has one,
  the 404 too).
- **Open Graph** (`og:title`, `og:description`, `og:type`, `og:site_name`) and
  `twitter:card`: what LinkedIn, Slack or iMessage show when someone pastes a link.
  There's no `og:image` on purpose: a plain text card is better than an invented picture.
- `canonical` and `og:url`: the page's one true address. Only written once
  `*domain*` is set (`page-url`), because without a domain the final address isn't
  certain, and a wrong one is worse than none.
- `theme-color`, one per theme: the color phones give the browser bar.
- `favicon.svg` (in `static/`): the tab icon, a λ whose color follows the theme
  thanks to a `prefers-color-scheme` query *inside* the SVG. Without any icon, every
  visit makes a request for `/favicon.ico` that ends in a 404.
- The 404 page adds `<meta name="robots" content="noindex">` (`:noindex t` in its
  `defpage`) so it never shows up in search results.
- **Fonts.** The Google Fonts stylesheet blocks the first paint until it arrives.
  `preconnect` opens the connection early and `display=swap` shows text in a
  fallback font until the real one arrives. Loading the stylesheet "async" would
  shave a little more off, but the whole page would flash in the wrong fonts first.

The first thing in `<body>` is a **skip link** ("Skip to content"): invisible until
you press Tab, then it slides in at the top left and jumps to `<main id="main">`, past
the header. Keyboard and screen-reader users don't have to tab through the nav on
every page.

## Design notes: why it looks the way it does

- **Plain colors:** about six grays and no real accent color. Hierarchy comes from
  size, weight and gray level instead.
- **Three typefaces, three jobs:** Literata (serif) for the big statements, Geist for
  reading, Geist Mono for labels and dates. The mono labels make it feel like an
  engineer's site without saying so.
- **Italic for emphasis** in the headline, the same move hansard.dev makes ("on the *record*").
- **One easing curve** (`--ease`) everywhere, so all the motion feels related.
- **Spacing on an 8px scale** (`--s1`…`--s12`). Random spacing is what makes amateur pages look off.

## Where to go next

- MDN's guides on CSS transitions and IntersectionObserver are the best references.
- *Practical Common Lisp* (free online), especially chapters 3 (a small database, a
  lot like `content.lisp`), 8 (macros) and 31 (an HTML generator, a bigger version of
  `html.lisp`).
- Exercises: see "Start here" at the top. A bigger one for later: add one more
  animated "mockup" like the terminal. A small chart that draws itself would fit a
  data person well (the diagrams' `stroke-dashoffset` trick is most of it).
