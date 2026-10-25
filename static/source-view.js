// source-view.js — the "(λ) source" switch in the header.
//
// Lisp already did the hard part (see src/source.lisp): every section that has a
// source panel carries it in a <template>, right after its content:
//
//   <div class="view-rendered"> …the normal section… </div>
//   <template class="view-source"> <figure class="source">…colored Lisp…</figure> </template>
//
// A <template> is parsed but never shown, so without JavaScript the page is
// unchanged. This file:
//   - copies each figure out of its template (hidden for now) and shows the button,
//   - swaps content and figures when you press it, with a short animation,
//   - remembers your choice for the next page (localStorage),
//   - listens for the "Toggle source view" command of the ⌘K menu.

const sourceToggle = document.querySelector("[data-source-toggle]");
const sourceTemplates = [...document.querySelectorAll("template.view-source")];

// "content" in a <template> = the browser understands templates. On the 404 page
// there are no templates, so the button simply stays hidden.
if (sourceToggle && sourceTemplates.length && "content" in document.createElement("template")) {
  setupSourceView();
}

function setupSourceView() {
  const KEY = "victor-site:source-view";
  const header = document.querySelector(".site-header");
  // Kept as a MediaQueryList (not read once) so changing the OS setting
  // while the page is open is respected on the next toggle.
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

  // One entry per section: the section, its normal content and its source panel.
  // `hidden` keeps the panel out of sight *and* out of what screen readers read.
  const views = sourceTemplates.map((template) => {
    const panel = template.content.firstElementChild.cloneNode(true);
    panel.hidden = true;
    template.after(panel);
    return { host: template.parentElement, rendered: template.previousElementSibling, panel };
  });

  // A screen-reader-only message, used when the switch is flipped from the ⌘K
  // menu (the button itself already says "pressed" / "not pressed").
  const status = document.createElement("p");
  status.className = "sr-only";
  status.setAttribute("aria-live", "polite");
  document.body.append(status);

  let on = false;
  let timer = null; // the swap waiting to happen, so a quick second click can cancel it

  // localStorage can throw (private windows, blocked storage): then we just
  // don't remember, and nothing else breaks.
  function load() {
    try { return localStorage.getItem(KEY) === "on"; } catch { return false; }
  }
  function save(state) {
    try { localStorage.setItem(KEY, state ? "on" : "off"); } catch { /* not remembered */ }
  }

  // Swapping changes the height of every section, which would make the page jump
  // under your eyes. So before the swap we note where the section you're reading
  // sits on screen, and after the swap we scroll so it's back in the same place.
  // (If its top was hidden under the header, we bring its top into view: you see
  // the heading of the code you asked for.)
  function measure() {
    const top = header ? header.getBoundingClientRect().bottom : 0;
    const view = views.find((v) => v.host.getBoundingClientRect().bottom > top + 1);
    return view && { host: view.host, y: Math.max(view.host.getBoundingClientRect().top, top) };
  }
  function restore(anchor) {
    if (!anchor) return;
    const dy = anchor.host.getBoundingClientRect().top - anchor.y;
    // "instant": the page has scroll-behavior: smooth, which we don't want here.
    if (Math.abs(dy) > 0.5) window.scrollBy({ top: dy, behavior: "instant" });
  }

  function swap(state) {
    for (const v of views) {
      v.rendered.hidden = state;
      v.panel.hidden = !state;
    }
  }

  const STEPS = ["is-leaving", "is-entering", "is-arriving"];
  function clearSteps() {
    clearTimeout(timer);
    for (const v of views) {
      v.rendered.classList.remove(...STEPS);
      v.panel.classList.remove(...STEPS);
    }
  }

  function set(state, animate) {
    on = state;
    sourceToggle.setAttribute("aria-pressed", String(state));
    clearSteps();

    if (!animate || reduceMotion.matches) {
      const anchor = measure();
      swap(state);
      restore(anchor);
      return;
    }

    const leaving = views.map((v) => (state ? v.rendered : v.panel));
    const arriving = views.map((v) => (state ? v.panel : v.rendered));

    // Step 1: fade the current side out (160ms, see style.css section 11).
    leaving.forEach((el) => el.classList.add("is-leaving"));

    timer = setTimeout(() => {
      // Step 2: swap, then animate the new side in from its start state.
      const anchor = measure();
      leaving.forEach((el) => el.classList.remove("is-leaving"));
      arriving.forEach((el) => el.classList.add("is-arriving", "is-entering"));
      swap(state);
      restore(anchor);
      // Reading offsetHeight forces the browser to apply the start state now;
      // otherwise it would skip straight to the end and nothing would animate.
      void document.body.offsetHeight;
      arriving.forEach((el) => el.classList.remove("is-entering"));
      timer = setTimeout(clearSteps, 900);
    }, 160);
  }

  sourceToggle.hidden = false;
  sourceToggle.addEventListener("click", () => {
    set(!on, true);
    save(on);
  });

  // The "Toggle source view" command in the ⌘K menu (see command-menu.js).
  document.addEventListener("cmdk:action", (event) => {
    if (event.detail !== "toggle-source") return;
    set(!on, true);
    save(on);
    status.textContent = on ? "Source view on" : "Source view off";
  });

  // Another tab flipped the switch: follow it, quietly.
  window.addEventListener("storage", (event) => {
    if (event.key === KEY && (event.newValue === "on") !== on) set(event.newValue === "on", false);
  });

  // Coming back to the site with source mode on: no animation, just show it.
  if (load()) set(true, false);
}
