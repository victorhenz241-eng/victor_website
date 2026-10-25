# How the moving parts work

This guide explains every effect on the site in plain language first, then shows
where the code lives. Read it alongside the files.

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
- **Pause button:** `wait()` keeps waiting while `paused` is true. If something moves
  for more than 5 seconds, users should be able to stop it, as accessibility
  guidelines (WCAG) require.
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

## The rule that applies to every effect: reduced motion

Some people get dizzy from animations and turn on "Reduce motion" in their OS.
`@media (prefers-reduced-motion: reduce)` in the CSS and `reduceMotion` in the JS
turn every effect off for them. Keep this in place as you add effects.

Turning motion off doesn't mean turning features off: with reduced motion the header
still shrinks, the nav still highlights, the menu still opens and the source view
still swaps. They just change
instantly instead of animating.

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
- Exercises: the shrinking header and the nav highlight now exist (Effects 6 and 7),
  so read them and change a number or two. Next: add one more animated "mockup" like
  the terminal. A small chart that draws itself would fit a data person well.
