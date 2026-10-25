# victor-site

My personal website, generated with Common Lisp. No framework and no npm: SBCL,
a small HTML renderer written by hand, plain CSS for the design and motion, and
a few hundred lines of plain JavaScript.

```
victor-site/
├── CLAUDE.md              # instructions Claude Code reads (teaching mode)
├── LEARN.md               # how every animation works, explained
├── victor-site.asd        # project definition (which files, in which order)
├── make.lisp              # one-shot build: sbcl --script make.lisp
├── src/
│   ├── package.lisp
│   ├── html.lisp          # Lisp lists -> HTML (read this first)
│   ├── content.lisp       # ← your text lives here
│   ├── source.lisp        # "(λ) source": slices and colors the real Lisp source
│   ├── pages.lisp         # layout, building blocks, defpage macro
│   └── build.lisp         # writes everything into public/
├── static/
│   ├── style.css          # all the design + motion
│   ├── motion.js          # scroll reveal, typing terminal, header + nav state
│   ├── command-menu.js    # the ⌘K menu
│   └── source-view.js     # the "(λ) source" switch
├── .claude/settings.json  # puts Claude Code in "Learning" mode for this project
└── .github/workflows/     # auto-deploy to GitHub Pages
```

## 1. Install the tools

- **SBCL:** `brew install sbcl` on macOS, `sudo apt install sbcl` on Linux, or the Windows installer from https://www.sbcl.org/platform-table.html
- **Claude Code:** see https://code.claude.com/docs (it runs in the terminal, in VS Code, or in the Claude desktop app)
- **Editor:** VS Code + the **Alive** extension is the easiest Lisp setup. Emacs + SLY is the classic one.

## 2. Build and preview

```sh
sbcl --script make.lisp
python3 -m http.server -d public 8000    # then open http://localhost:8000
```

## 3. Working on it with Claude Code

Open a terminal in this folder and run `claude`. Two files set it up for learning:

- **`CLAUDE.md`** tells Claude what the project is, how to build it, and that you're
  learning. It should explain in plain language first, introduce every new concept,
  diagnose before fixing, and keep the stack free of frameworks.
- **`.claude/settings.json`** selects the **Learning** output style. Claude adds short
  `★ Insight` explanations and leaves some pieces for you to write, marked
  `TODO(human)`. When you'd rather go faster, switch with `/output-style explanatory`
  (explanations only) or `/output-style default`.

Good first prompts:

- "Walk me through html.lisp line by line. I'm new to Lisp."
- "Explain how a section gets from content.lisp to the screen, including the animation."
- "I want the header to shrink when I scroll. Explain the options, then let me write it."

## 4. The REPL workflow

```lisp
(require :asdf)
(asdf:load-asd (truename "victor-site.asd"))
(asdf:load-system "victor-site")
(in-package :victor-site)
(build)
```

Edit a form → re-evaluate it in your editor (`C-c C-c`) → `(build)` → refresh the browser.
Nothing needs restarting. Things to try:

```lisp
(html '(:p :class "x" "Hello & <goodbye>"))      ; see the renderer work
(timeline *education*)                            ; a building block returns plain data
(macroexpand-1 '(defpage "x.html" (:title "X") '(:p "hi")))
```

## 5. Put it online (GitHub Pages)

1. Create a repo called `victor_website` on GitHub and push this folder to `main`.
   (If you pick another name, change `*base-path*` in `content.lisp`: the 404 page uses it.)
2. In the repo, go to **Settings → Pages → Source** and pick **GitHub Actions**.
3. Each push now builds and publishes the site. The first time, it shows up at
   `https://victorhenz241-eng.github.io/victor_website/`.

## 6. Your own domain

1. Buy it (e.g. `victorhenz.com`) from Cloudflare Registrar or Porkbun.
2. In `src/content.lisp`, set `(defparameter *domain* "victorhenz.com")`. The build writes the `CNAME` file for you.
3. At your registrar, add the DNS records GitHub shows under *Settings → Pages → Custom domain*.
4. Tick **Enforce HTTPS** once it's available.

## Next steps

**Content:** every sentence in `content.lisp` comes from the CV. Review the About
paragraph marked `DRAFT`, and add a `cv.pdf` without your phone number to `static/`
when you want the CV link to appear. Keep `*repl*` factual and to four commands.

**Lisp**
- [x] Generate one page per project from `*projects*` (add a `:slug`).
- [ ] Render blog posts from files in `posts/`.
- [ ] Swap `html.lisp` for the Spinneret library and compare the two.

**Design & motion** (see LEARN.md)
- [x] Make the header shrink when you scroll.
- [x] Highlight the current section in the nav.
- [x] A ⌘K command menu generated from the data.
- [x] A "(λ) source" switch that shows the real Lisp behind each section.
- [ ] Add a second animated "mockup": a small chart that draws itself would suit a data person.
