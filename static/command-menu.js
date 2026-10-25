// command-menu.js — the ⌘K menu (Ctrl+K on Windows/Linux, or "/").
//
// Lisp already wrote the whole menu into every page, inside a <dialog> that
// stays closed (see COMMAND-MENU in pages.lisp). This file only:
//   - shows the "Search" button and opens the dialog,
//   - filters the options as you type,
//   - moves the selection with the arrow keys and opens it with Enter.
//
// Without JavaScript the button stays hidden and the dialog stays closed, so
// nothing is broken: the header links still work.
//
// Accessibility pattern: a "combobox". The focus never leaves the text box.
// Instead, aria-activedescendant on the text box says which option is selected,
// and screen readers read that option out. See
// https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Roles/combobox_role

function setupCommandMenu(dialog) {
  const input = dialog.querySelector(".cmdk-input");
  const options = [...dialog.querySelectorAll('[role="option"]')];
  const groups = [...dialog.querySelectorAll('[role="group"]')];
  const empty = dialog.querySelector(".cmdk-empty");
  const status = dialog.querySelector("[data-cmdk-status]");

  // Typing "supelec" should find "Supélec": normalize("NFD") splits "é" into "e" + an
  // accent mark, and the regular expression removes the accent marks
  // (U+0300 to U+036F is the Unicode block of "combining" accents).
  const simplify = (text) => text.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();

  // What each option can be found by: its text, its hint, its group and the
  // extra words Lisp put in data-keywords (a project's tags). Computed once.
  const searchText = new Map(
    options.map((option) => {
      const group = option.closest('[role="group"]').getAttribute("aria-label");
      return [option, simplify(`${option.textContent} ${option.dataset.keywords || ""} ${group}`)];
    })
  );

  let active = null; // the selected option

  function select(option, { scroll = true } = {}) {
    if (active) active.setAttribute("aria-selected", "false");
    active = option || null;
    if (active) {
      active.setAttribute("aria-selected", "true");
      input.setAttribute("aria-activedescendant", active.id);
      if (scroll) active.scrollIntoView({ block: "nearest" });
    } else {
      input.removeAttribute("aria-activedescendant");
    }
  }

  const shownOptions = () => options.filter((option) => !option.hidden);

  // Every word you type must appear somewhere in the option's search text.
  // "graph neo" finds Event-Market Graph (its tags include Neo4j).
  function filter() {
    const words = simplify(input.value).split(/\s+/).filter(Boolean);
    for (const option of options) {
      option.hidden = !words.every((word) => searchText.get(option).includes(word));
    }
    // Hide a group's label when none of its options are left.
    for (const group of groups) {
      group.hidden = !group.querySelector('[role="option"]:not([hidden])');
    }
    const shown = shownOptions();
    empty.hidden = shown.length > 0;
    // aria-expanded tells screen readers whether there's a list to explore.
    input.setAttribute("aria-expanded", String(shown.length > 0));
    select(shown[0]);
    return shown.length;
  }

  function open() {
    if (dialog.open) return;
    input.value = "";
    filter();
    status.textContent = "";
    // showModal() (not show()) is what traps the focus inside and adds the backdrop.
    dialog.showModal();
    input.focus();
  }

  // Follow the selected link. dialog.close() first, so a link to a section of
  // this same page (like "./#about") doesn't leave the menu open on top of it.
  function go(option, newTab) {
    // An action (no link), like "Toggle source view": close the menu and announce
    // it as an event; the file that owns the feature (source-view.js) listens.
    if (option.dataset.cmdkAction) {
      dialog.close();
      document.dispatchEvent(new CustomEvent("cmdk:action", { detail: option.dataset.cmdkAction }));
      return;
    }
    if (newTab) {
      window.open(option.href, "_blank", "noopener");
      return;
    }
    dialog.close();
    option.click(); // exactly like clicking the link yourself
  }

  input.addEventListener("input", () => {
    const n = filter();
    status.textContent = n === 1 ? "1 result" : `${n} results`;
  });

  input.addEventListener("keydown", (event) => {
    const shown = shownOptions();
    const i = shown.indexOf(active);
    if (event.key === "ArrowDown" && shown.length) {
      event.preventDefault(); // otherwise the cursor jumps to the end of the text
      select(shown[(i + 1) % shown.length]); // % wraps around: after the last comes the first
    } else if (event.key === "ArrowUp" && shown.length) {
      event.preventDefault();
      select(shown[(i - 1 + shown.length) % shown.length]);
    } else if (event.key === "Enter" && active && !event.isComposing) {
      // (isComposing: Enter is also how Chinese/Japanese input confirms a word.)
      event.preventDefault();
      go(active, event.metaKey || event.ctrlKey); // ⌘/Ctrl+Enter opens a new tab
    }
  });

  // The mouse moves the selection too, but without scrolling the list under it.
  for (const option of options) {
    option.addEventListener("mousemove", () => {
      if (active !== option) select(option, { scroll: false });
    });
  }

  dialog.addEventListener("click", (event) => {
    // The panel fills the whole dialog, so a click whose target is the dialog
    // itself landed on the backdrop, outside the panel: close.
    if (event.target === dialog) dialog.close();
    else {
      const option = event.target.closest('[role="option"]');
      // A click on an action runs it; a click on a link closes the menu and
      // lets the link do its normal job.
      if (option?.dataset.cmdkAction) go(option);
      else if (option) dialog.close();
    }
  });

  // The button in the header. It's hidden in the HTML; we reveal it now that
  // we know it will work.
  const isMac = /mac|iphone|ipad/i.test(navigator.userAgentData?.platform || navigator.platform);
  for (const button of document.querySelectorAll("[data-cmdk-open]")) {
    button.hidden = false;
    button.addEventListener("click", open);
    if (!isMac) {
      // Lisp wrote the Mac version of the shortcut; switch both copies of it.
      button.querySelector("[data-cmdk-key]").textContent = "Ctrl K";
      button.setAttribute("aria-keyshortcuts", "Control+K /");
    }
  }

  // Keyboard shortcuts, anywhere on the page.
  // ⌘K on a Mac, Ctrl+K elsewhere. (On a Mac, Ctrl+K inside a text box means
  // "delete to the end of the line", so we leave it alone there.)
  const isTyping = (el) => el.closest?.("input, textarea, select, [contenteditable]");
  document.addEventListener("keydown", (event) => {
    const modifier = isMac ? event.metaKey : event.ctrlKey;
    if (modifier && !event.altKey && event.key.toLowerCase() === "k") {
      event.preventDefault(); // browsers use Ctrl+K for "search the web"
      if (dialog.open) dialog.close();
      else open();
    } else if (event.key === "/" && !dialog.open && !event.metaKey && !event.ctrlKey &&
               !event.altKey && !isTyping(event.target)) {
      event.preventDefault();
      open();
    }
  });
  // Esc needs no code: a modal <dialog> closes itself on Esc, and gives the
  // focus back to whatever had it before (usually the "Search" button).
}

// Old browsers without <dialog> support simply never get the menu.
const commandMenu = document.getElementById("cmdk");
if (commandMenu && typeof commandMenu.showModal === "function") setupCommandMenu(commandMenu);
