/* The theme switch on the website.

   Three states, because two would be a lie: Auto follows whatever the phone
   or the desktop asks for, and Light and Dark say so regardless.  The choice
   is kept in this browser and nowhere else.

   It sets data-theme on the <html> element rather than a class on the body,
   because the palettes in style.css are custom properties defined on :root
   and that is where an override has to land to beat them.

   Nothing here runs inside the program's own help window: LazInk renders
   these pages and has no JavaScript at all.  The button is therefore
   written into the pages as an ordinary link - <a class="themebtn"
   href="#theme"> - and this file finds it and gives it its behavior.

   From a note, 19 September: "even the local copy should have the light/dark mode
   button toggles in the help browsers html like we do in the online
   version".  So the program answers that link too: clicking it there cycles
   the manual's palette and loads the page again wearing it, and the label
   is rewritten on the way through.  See uHelpView.PageWithMode and
   PageLinkClick.  A link in the markup is the one thing both readers can
   act on; a button built in script was only ever half of them.

   The link still works with no script at all: it goes nowhere, which is
   what a #theme with nothing to jump to does.

   The first half runs while the page is still parsing, on purpose, so the
   colors are right before anything is painted.  Waiting for the document
   would show a flash of the wrong theme on every page turn. */
(function () {
  'use strict';

  var KEY = 'hs-help-theme';
  var ORDER = ['auto', 'light', 'dark'];
  var LABEL = { auto: 'Auto', light: 'Light', dark: 'Dark' };

  /* Private windows and blocked site data make storage throw rather than
     return nothing, so every touch of it is guarded and the page simply
     falls back to Auto. */
  function read() {
    try {
      var v = window.localStorage.getItem(KEY);
      return ORDER.indexOf(v) >= 0 ? v : 'auto';
    } catch (e) {
      return 'auto';
    }
  }

  function write(v) {
    try {
      window.localStorage.setItem(KEY, v);
    } catch (e) {
      /* nothing to do: the page still works, it just forgets */
    }
  }

  function apply(v) {
    var el = document.documentElement;
    if (v === 'auto') el.removeAttribute('data-theme');
    else el.setAttribute('data-theme', v);
  }

  var now = read();
  apply(now);

  function build() {
    var wrap = document.querySelector('.wrap');
    if (!wrap) return;

    /* The page carries the button; only a page written before it did needs
       one made here. */
    var b = document.getElementById('themebtn');
    var mine = false;
    if (!b) {
      b = document.createElement('button');
      b.className = 'themebtn';
      b.type = 'button';
      mine = true;
    }

    function say() {
      b.textContent = LABEL[now];
      b.setAttribute('aria-label', 'Theme: ' + LABEL[now] + '. Tap to change.');
    }

    b.addEventListener('click', function (e) {
      e.preventDefault();
      now = ORDER[(ORDER.indexOf(now) + 1) % ORDER.length];
      apply(now);
      write(now);
      say();
    });

    say();
    if (mine) wrap.insertBefore(b, wrap.firstChild);
  }

  if (document.readyState === 'loading')
    document.addEventListener('DOMContentLoaded', build);
  else
    build();
})();
