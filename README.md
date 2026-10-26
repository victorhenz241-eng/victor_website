# victor-site

My personal website, generated with Common Lisp. No framework and no npm: SBCL,
a small HTML renderer written by hand, plain CSS for the design and motion, and
a few hundred lines of plain JavaScript.

```
victor-site/
├── CLAUDE.md              # instructions Claude Code reads (teaching mode)
├── LEARN.md               # start here: a tour of the code, then every effect explained
├── victor-site.asd        # project definition (which files, in which order)
├── make.lisp              # one-shot build: sbcl --script make.lisp
├── src/
│   ├── package.lisp
│   ├── html.lisp          # Lisp lists -> HTML (read this first)
│   ├── content.lisp       # ← your text lives here
│   ├── source.lisp        # "(λ) source": slices and colors the real Lisp source
│   ├── stats.lisp         # the footer's build numbers, measured during the build
│   ├── media.lisp         # photos and videos: shown only if the file exists, sizes read from the bytes
│   ├── pages.lisp         # layout, building blocks, defpage macro
│   └── build.lisp         # writes everything into public/
├── static/
│   ├── style.css          # all the design + motion
│   ├── motion.js          # scroll reveal, terminal, header + nav state, diagrams, demo video
│   ├── command-menu.js    # the ⌘K menu
│   ├── source-view.js     # the "(λ) source" switch
│   ├── favicon.svg        # the tab icon (a λ that follows light/dark mode)
│   └── media/             # photos and videos (made with scripts/prepare-media.sh)
├── scripts/
│   ├── prepare-media.sh   # originals -> small web versions, metadata removed
│   └── media.swift        # the helper it calls (Swift comes with macOS)
├── .claude/settings.json  # puts Claude Code in "Learning" mode for this project
├── .github/workflows/     # auto-deploy to GitHub Pages
└── public/                # the built site (made by the build, not in git)
```

Everything in `static/` is copied as is into `public/`, so everything in it is public.

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

## Before you publish

A checklist. None of these can be done by the code for you.

- [ ] **Make the repo public, or upgrade.** On GitHub's free plan, Pages only works for
      public repositories (a private one needs GitHub Pro or a paid plan). Once it's
      public, link it from the "This website" project: its `:url` in `content.lisp`
      is `nil` with a `private:` TODO note next to it.
- [ ] **Tell the site where it lives.** Keep the repo name `victor_website`, or change
      `*base-path*` in `content.lisp` to match (the 404 page depends on it). If you buy
      a domain, set `*domain*` instead (section 6): the build then also writes
      `CNAME`, the `canonical` link and `og:url`.
- [ ] **Drop in your media** (section 7). Each file appears on the site as soon as it
      exists in `static/media/` and you rebuild. Until then the page falls back
      gracefully (no broken image, no empty box):

      | File in `static/media/` | Where it shows | Until then |
      |---|---|---|
      | `about-running.jpg` | beside the About text | text only |
      | `cut-the-line/01.jpg`, `02.jpg`… | "On the podium", on the Cut the Line page (sorted by name) | no section |
      | `event-market-card.mp4` + `event-market-poster.jpg` | the Event-Market card on the home page | a small copy of its diagram |
      | `event-market-demo.mp4` + `event-market-poster.jpg` | under the header of the Event-Market page, looping | no video |

      Then describe each photo for people who can't see it: `:alt` in `*about-photo*`,
      and the `:alts` list of the Cut the Line `:gallery` (one string per photo, same
      order) in `content.lisp`. Delete the `private:` notes next to them.
- [ ] **Confirm the Cut the Line text.** "My part" was written from the repo's commit
      history (a `private: Victor to confirm role wording` note sits above it). Reword
      it as you see fit.
- [ ] **Review the About text.** Its second paragraph is a draft written from the CV.
      In `content.lisp` it has a `;; private: DRAFT` note above it (never shown on the
      site). Rewrite it in your own voice, then delete the note.
- [ ] **Add your CV, if you want the CV link.** Export a copy *without your phone
      number*, save it as `static/cv.pdf`, and change `("CV" nil)` to
      `("CV" "cv.pdf")` in `*links*`.
- [ ] **Look at the live site once.** Open a page, a project page, and a made-up
      address like `.../victor_website/a/b` (the 404 page, styled). Try ⌘K and
      "(λ) source". Then search the built files for leftovers:
      `grep -rn -i "todo\|draft\|private" public/*.html` should only find words
      like "drafts" in the project text.

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

## 7. Photos and videos

Everything goes through one script, which only uses tools that come with macOS
(`sips`, and Swift for `scripts/media.swift`). Run it from the project folder. The
last argument is the file name inside `static/media/`: lowercase letters, digits and
dashes, **no spaces** (a space in a web address becomes `%20` and breaks easily).

```sh
# A photo (JPEG, HEIC, PNG): long edge 1600 px, JPEG quality 80, turned upright,
# and every bit of metadata removed: GPS position, phone model, date.
scripts/prepare-media.sh photo ~/Desktop/IMG_1234.HEIC about-running.jpg
mkdir -p static/media/cut-the-line
scripts/prepare-media.sh photo ~/Desktop/podium.jpg cut-the-line/01.jpg

# A demo with sound, for a case-study page: 720p H.264 at ~700 kbit/s (about 5 MB a minute).
scripts/prepare-media.sh video ~/Desktop/demo.mov my-demo.mp4

# A short silent loop for a card: 8 seconds starting at 0:59, no sound.
scripts/prepare-media.sh clip ~/Desktop/demo.mov my-card.mp4 59 8

# A poster: the frame at 1:04, shown before a video plays (and instead of it
# when someone asks their system for less motion).
scripts/prepare-media.sh poster ~/Desktop/demo.mov my-poster.jpg 64
```

After each picture the script prints its size and checks with `sips -g all` that no
GPS, camera or date is left. Then rebuild (`sbcl --script make.lisp`).

**Why not just `sips` and `avconvert`?** We tried both. `sips -s format jpeg -Z 1600`
resizes well but *keeps* an iPhone photo's GPS position. And `avconvert` only has
fixed presets: its 720p one turned the 108-second Cut the Line demo into 98 MB (the
1080p original is 27 MB). `media.swift` uses the same Apple frameworks but lets us
choose the bitrate: the same demo is 10.5 MB at 720p.

**Keep the repo light.** GitHub warns about files over 50 MB and refuses them over
100 MB. Keep every file under 15 MB (for a long demo, lower the bitrate:
`scripts/prepare-media.sh video demo.mov my-demo.mp4 500`). `ls -lh static/media`
shows the sizes.

**The Event-Market videos** are a recording of the live demo replaying "Why did the
VIX move in June?" (light theme): `event-market-demo.mp4` is the whole run (15 s,
1280×800, silent, it loops on the page), `event-market-card.mp4` is 9 s of it cropped
to the graph and the agent's panel, and `event-market-poster.jpg` is the frame at 8 s.
To redo them from a new recording (⌘⇧5, *Record Selected Portion*, saved on the
Desktop as `recording.mov`; the card then shows the whole recorded area):

```sh
scripts/prepare-media.sh clip ~/Desktop/recording.mov event-market-card.mp4 4 9
swift scripts/media.swift video ~/Desktop/recording.mov static/media/event-market-demo.mp4 --no-audio --kbps 1500
swift scripts/media.swift frame ~/Desktop/recording.mov static/media/event-market-poster.jpg --start 8
```

The build reads each video's width and height from the file, so the page reserves
its space before the video loads. Delete a file and rebuild to remove it again.

## Next steps

**Content:** every sentence in `content.lisp` comes from the CV or from the projects'
own READMEs (the Radar funnel numbers were counted in the live system). See "Before you
publish" above for the About draft and the CV. Keep `*repl*` factual and to four commands.

**Lisp**
- [x] Generate one page per project from `*projects*` (add a `:slug`).
- [ ] Render blog posts from files in `posts/`.
- [ ] Swap `html.lisp` for the Spinneret library and compare the two.

**Design & motion** (see LEARN.md)
- [x] Make the header shrink when you scroll.
- [x] Highlight the current section in the nav.
- [x] A ⌘K command menu generated from the data.
- [x] A "(λ) source" switch that shows the real Lisp behind each section.
- [x] Diagrams generated from data on the project pages, drawing themselves (LEARN.md, Effect 11).
- [x] Media-led project cards: a looping video or a photo on top, or a tile drawn from the data.
- [x] Record the Event-Market demo video and its card loop (section 7).
- [ ] Add a second animated "mockup": a small chart that draws itself would suit a data person.

**Learning:** LEARN.md starts with a reading order, the concepts behind each file and
eight small exercises.
