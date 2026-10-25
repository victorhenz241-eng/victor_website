// motion.js — every moving part of the site, in plain JavaScript (no libraries).
//
// Four features:
//   1. Scroll reveal: elements marked data-reveal fade/slide in when they enter the screen.
//   2. The terminal: replays the REPL session in the hero, with a pause button.
//   3. The header gets more compact once you scroll down.
//   4. The nav highlights the section you're reading.
// (The ⌘K command menu has its own file: command-menu.js.)
//
// The golden rule here is "progressive enhancement": the HTML already contains
// all the content. If this file fails to load, nothing is lost — it just doesn't move.

// Respect the operating-system setting "reduce motion" (some people get
// motion sickness). If it's on, we show everything immediately and stop here.
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

// Tell the CSS that JavaScript is running. The stylesheet only hides
// [data-reveal] elements under `.js`, so without JS they're simply visible.
document.documentElement.classList.add("js");

// ---------------------------------------------------------------------------
// 1. Scroll reveal
// ---------------------------------------------------------------------------
// IntersectionObserver is a browser API that calls us back when an element
// crosses into the viewport. It's much cheaper than listening to every scroll
// event. We add the class "is-visible" once; the CSS transition does the rest.

if (reduceMotion || !("IntersectionObserver" in window)) {
  document.querySelectorAll("[data-reveal]").forEach((el) => el.classList.add("is-visible"));
} else {
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target); // animate only the first time
        }
      }
    },
    // threshold: how much of the element must be visible (15%).
    // rootMargin: shrink the "screen" by 10% at the bottom, so things
    // animate a little after they appear rather than right at the edge.
    { threshold: 0.15, rootMargin: "0px 0px -10% 0px" }
  );
  document.querySelectorAll("[data-reveal]").forEach((el) => observer.observe(el));
}

// ---------------------------------------------------------------------------
// 2. The terminal
// ---------------------------------------------------------------------------
// Lisp wrote every line into the HTML. Here we remember each line's text,
// empty them all, then "type" them back one character at a time, in a loop.

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function setupTerminal(terminal) {
  const lines = [...terminal.querySelectorAll(".line")];
  const button = terminal.querySelector("[data-terminal-toggle]");
  const script = lines.map((line) => {
    const text = line.querySelector(".text");
    return { line, text, full: text.textContent, typed: line.classList.contains("in") };
  });

  // Lock the window's height while it's still full of text, so the page
  // below doesn't jump up and down as lines appear and disappear.
  const body = terminal.querySelector(".terminal-body");
  body.style.minHeight = body.offsetHeight + "px";

  const cursor = document.createElement("span");
  cursor.className = "cursor";

  let paused = false;

  // Like sleep(), but also waits while the animation is paused.
  async function wait(ms) {
    await sleep(ms);
    while (paused) await sleep(100);
  }

  button.addEventListener("click", () => {
    paused = !paused;
    button.textContent = paused ? "Play" : "Pause";
    button.setAttribute("aria-label", paused ? "Play animation" : "Pause animation");
    terminal.classList.toggle("is-paused", paused);
  });

  // async/await lets us write the animation top-to-bottom like a script,
  // even though it's spread out over time.
  async function play() {
    while (true) {
      // Reset: hide every line.
      for (const s of script) {
        s.line.hidden = true;
        s.text.textContent = "";
      }
      await wait(600);

      for (const s of script) {
        s.line.hidden = false;
        s.line.append(cursor); // move the blinking cursor to this line
        if (s.typed) {
          // Type character by character, with a slightly random rhythm
          // so it feels like a person rather than a machine.
          for (const char of s.full) {
            s.text.textContent += char;
            await wait(28 + Math.random() * 45);
          }
          await wait(350);
        } else {
          s.text.textContent = s.full; // results appear all at once
          await wait(1100);
        }
      }
      await wait(4000); // let people read before starting over
    }
  }

  if (reduceMotion) {
    button.hidden = true; // nothing to pause: the text just sits there
  } else {
    play();
  }
}

document.querySelectorAll("[data-terminal]").forEach(setupTerminal);

// ---------------------------------------------------------------------------
// 3. The header shrinks once you scroll
// ---------------------------------------------------------------------------
// We only need one fact: "is the top of the page still on screen?". There are
// two cheap ways to know:
//   a) listen to the `scroll` event (passive, so it never delays scrolling) and
//      check window.scrollY at most once per frame with requestAnimationFrame;
//   b) put an invisible marker (a "sentinel") at the top of the page and let an
//      IntersectionObserver tell us when it leaves or comes back.
// We use (b): the browser calls us only when the answer *changes* (once on the
// way down, once on the way up), instead of on every scroll frame.
// The look of both states lives in style.css (.is-scrolled). Under reduced
// motion the class still changes; the CSS just drops the animation.

const header = document.querySelector(".site-header");

if (header && "IntersectionObserver" in window) {
  const sentinel = document.createElement("div");
  sentinel.className = "scroll-sentinel"; // 6rem tall, pinned to the top (style.css)
  sentinel.setAttribute("aria-hidden", "true");
  document.body.prepend(sentinel);

  new IntersectionObserver(([entry]) => {
    // Sentinel gone from the screen = we've scrolled past the top.
    header.classList.toggle("is-scrolled", !entry.isIntersecting);
  }).observe(sentinel);
}

// ---------------------------------------------------------------------------
// 4. Highlight the section you're reading
// ---------------------------------------------------------------------------
// On the home page Lisp writes the nav links as "#about" (elsewhere "./#about",
// which leads back home). So "the href starts with #" means "this section is on
// the page you're reading", and on a project page or the 404 nothing is highlighted. (Lighting up "Projects" there was tempting, but that link
// leads to the home page, not to the page you're on, so it would be a small lie,
// and aria-current would tell screen readers the same lie. The "← All work"
// link at the top already says where you are.)
//
// "The section you're reading" = the one crossing a thin band about a third of
// the way down the screen, which is where your eyes usually are. The rootMargin
// below shrinks the observed area to that band: 35% off the top, 60% off the bottom.

const tracked = [...document.querySelectorAll('.site-header nav a[href^="#"]')]
  .map((link) => ({ link, section: document.getElementById(link.getAttribute("href").slice(1)) }))
  .filter((t) => t.section);

if (tracked.length && "IntersectionObserver" in window) {
  const inBand = new Set(); // the sections currently crossing the band
  let atEnd = false;        // is the footer on screen?

  function update() {
    // The last section (in page order) touching the band wins. At the very end
    // of the page a short last section (Contact) may never reach the band,
    // so once the footer shows up, the last section wins.
    let current = null;
    for (const t of tracked) if (inBand.has(t.section)) current = t;
    if (atEnd) current = tracked[tracked.length - 1];

    for (const t of tracked) {
      if (t === current) t.link.setAttribute("aria-current", "true");
      else t.link.removeAttribute("aria-current");
    }
  }

  const bandObserver = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) inBand.add(entry.target);
        else inBand.delete(entry.target);
      }
      update();
    },
    { rootMargin: "-35% 0px -60% 0px" }
  );
  tracked.forEach((t) => bandObserver.observe(t.section));

  const footer = document.querySelector(".footer");
  if (footer) {
    new IntersectionObserver(([entry]) => {
      atEnd = entry.isIntersecting;
      update();
    }).observe(footer);
  }
}
