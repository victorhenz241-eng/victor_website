// theme.js — the theme switch in the header: auto → light → dark → auto.
//
// How the pieces fit:
//   - style.css holds both sets of colors. The dark ones apply when <html> has
//     data-theme="dark", or when it has no data-theme ("auto") and the system is
//     set to dark (prefers-color-scheme). data-theme="light" keeps the light ones.
//   - A few lines written into every page's <head> (*THEME-SCRIPT* in pages.lisp)
//     put the saved choice on <html> before the first paint, so there's no flash.
//   - This file, which runs later (defer), shows the button, cycles through the
//     three settings, remembers the choice (localStorage) and listens for the
//     "Switch theme" command of the ⌘K menu.
//
// Without JavaScript the button stays hidden and the site follows the system.

const themeToggle = document.querySelector("[data-theme-toggle]");
if (themeToggle) setupThemeToggle(themeToggle);

function setupThemeToggle(button) {
  const KEY = "victor-site:theme";
  const ORDER = ["auto", "light", "dark"];
  const root = document.documentElement;
  const glyph = button.querySelector(".theme-toggle-glyph");
  const word = button.querySelector(".theme-toggle-text");
  const themeColors = [...document.querySelectorAll('meta[name="theme-color"]')];
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

  // ☀ is the sun ☀. Some phones draw it as a colored emoji; ︎ right
  // after it asks for the plain text version, like the other two.
  const GLYPHS = { auto: "◐", light: "☀︎", dark: "☾" };
  const NAMES = { auto: "auto (follows your system)", light: "light", dark: "dark" };

  // A screen-reader-only message: "Theme: dark" after each change. Changing a
  // button's aria-label isn't always read out, so we say it here as well.
  const status = document.createElement("p");
  status.className = "sr-only";
  status.setAttribute("aria-live", "polite");
  document.body.append(status);

  let timer = null; // the end of the color fade, so a quick second click restarts it

  // The current setting. The <head> script already wrote the saved one on <html>.
  const current = () => root.dataset.theme || "auto";
  // % wraps around: after the last setting comes the first.
  const next = (mode) => ORDER[(ORDER.indexOf(mode) + 1) % ORDER.length];

  // localStorage can throw (private windows, blocked storage): then the choice
  // just isn't remembered, and nothing else breaks. "auto" removes the key, so a
  // visitor who goes back to auto is exactly like one who never pressed.
  function save(mode) {
    try {
      if (mode === "auto") localStorage.removeItem(KEY);
      else localStorage.setItem(KEY, mode);
    } catch { /* not remembered */ }
  }

  function apply(mode, animate) {
    // The fade: .theme-changing (style.css) gives every element a 0.3s color
    // transition, for 0.3s only. Under reduced motion the colors just switch.
    if (animate && !reduceMotion.matches) {
      clearTimeout(timer);
      root.classList.add("theme-changing");
      timer = setTimeout(() => root.classList.remove("theme-changing"), 350);
    }

    if (mode === "auto") delete root.dataset.theme;
    else root.dataset.theme = mode;

    // The phone's browser bar: in auto, each meta follows its own media query
    // again; otherwise the chosen theme's meta always applies and the other never.
    for (const meta of themeColors) {
      meta.media = mode === "auto"
        ? `(prefers-color-scheme: ${meta.dataset.scheme})`
        : meta.dataset.scheme === mode ? "all" : "not all";
    }

    glyph.textContent = GLYPHS[mode];
    word.textContent = mode;
    // The label says where you are and what the button will do, e.g.
    // "Theme: dark. Switch to auto (follows your system)."
    const label = `Theme: ${NAMES[mode]}. Switch to ${next(mode)}.`;
    button.setAttribute("aria-label", label);
    button.title = label;
  }

  function cycle() {
    const mode = next(current());
    apply(mode, true);
    save(mode);
    status.textContent = `Theme: ${NAMES[mode]}`;
  }

  // Bring the button in line with the saved setting, then show it.
  apply(current(), false);
  button.hidden = false;
  button.addEventListener("click", cycle);

  // The "Switch theme" command in the ⌘K menu (see command-menu.js).
  document.addEventListener("cmdk:action", (event) => {
    if (event.detail === "cycle-theme") cycle();
  });

  // Another tab changed the theme: follow it, quietly. (The storage event only
  // fires in the *other* tabs, never in the one that made the change.)
  window.addEventListener("storage", (event) => {
    if (event.key !== KEY && event.key !== null) return; // null = storage cleared
    const mode = event.newValue === "light" || event.newValue === "dark" ? event.newValue : "auto";
    if (mode !== current()) apply(mode, true);
  });
}
