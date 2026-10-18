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

## The rule that applies to every effect: reduced motion

Some people get dizzy from animations and turn on "Reduce motion" in their OS.
`@media (prefers-reduced-motion: reduce)` in the CSS and `reduceMotion` in the JS
turn every effect off for them. Keep this in place as you add effects.

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
- Exercises, in order: (1) make the header shrink when you scroll, (2) highlight the
  current section in the nav, (3) add one more animated "mockup" like the terminal.
  A small chart that draws itself would fit a data person well.
