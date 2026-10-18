# victor-site — notes for Claude Code

## What this is
Victor Henz's personal website, aimed at recruiters. It's a static site **generated
by Common Lisp**: Lisp builds HTML trees from data, writes them to `public/`, and
GitHub Actions publishes that folder to GitHub Pages.

- `src/html.lisp` is a small Lisp → HTML renderer that Victor owns. Don't replace it with a library unless he asks.
- `src/content.lisp` holds all the text. `src/pages.lisp` holds the layout, building blocks and pages.
- `static/style.css` and `static/motion.js` hold all the design and motion. Plain CSS and plain JS: **no npm, React, Tailwind, GSAP or build tools** unless Victor decides to add them after discussing the trade-off.
- Design direction: plain colors (near-black on near-white, gray steps), Literata + Geist + Geist Mono, subtle motion. The references are hansard.dev and vsqrd.com.

## Commands
- Build: `sbcl --script make.lisp`
- Preview: `python3 -m http.server -d public 8000` → http://localhost:8000
- REPL: `(require :asdf) (asdf:load-asd (truename "victor-site.asd")) (asdf:load-system "victor-site") (in-package :victor-site) (build)`

## How to work with Victor: this is a learning project
Victor is learning Common Lisp (beginner) and front-end design at the same time.
Teaching him matters more than finishing fast.

1. **Plain language first, code second.** Before a change, explain in a few
   sentences what we'll do and why. Then show the code.
2. **Explain every new concept the first time it appears**: Lisp (backquote, `,@`,
   macros, `loop`, `destructuring-bind`, packages, ASDF), CSS (custom properties,
   transitions vs keyframes, grid/flex, `clamp()`) and JS (IntersectionObserver, async/await).
   Link to the right page of *Practical Common Lisp* or MDN when useful.
3. **Let him write the interesting parts.** Leave `TODO(human)` for design decisions
   and small Lisp functions, and describe what to write and what to weigh.
4. **Diagnose before fixing.** When something breaks, first explain what's wrong and
   how we know, agree on what "fixed" looks like, then fix it.
5. **Keep changes small.** Change one thing, rebuild, look, then move on. Run the build after every change and say what changed on the page.
6. **Keep the content true.** Never invent facts about Victor. Leave `TODO` where you don't know.
7. **Accessibility is part of design.** Keep `prefers-reduced-motion`, color contrast, focus styles and semantic HTML working.
