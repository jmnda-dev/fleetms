// Layout interactions for the Flowbite Admin Dashboard shell.
//
// This is written to be LiveView-safe. The navbar/sidebar live inside the
// `FleetmsWeb.Layouts.app` function component, which is re-rendered on LiveView
// navigation. So we:
//   1. use event delegation on `document` so handlers survive DOM patches, and
//   2. re-apply persisted UI state after every live navigation.
//
// The mobile sidebar drawer, dropdowns and tooltips are handled by Flowbite
// (see flowbite.phoenix.js). This file owns the pieces of state Flowbite
// doesn't persist across LiveView navigation: desktop sidebar collapse, the
// sidebar's collapsible nav groups, and the dark-mode toggle.

const SIDEBAR_KEY = "sidebarExpanded";
const THEME_KEY = "color-theme";
const APP_THEME_KEY = "app-theme";
const DEFAULT_APP_THEME = "midnight";
const DROPDOWN_KEY = "openSidebarDropdowns";

// ---- Sidebar collapse (desktop / lg and up) ----
function setSidebarCollapsed(collapsed) {
  const sidebar = document.getElementById("sidebar");
  const main = document.getElementById("main-content");
  if (!sidebar || !main) return;

  const toggle = document.getElementById("togglSidebarButton");
  const collapseIcon = document.querySelector("[data-sidebar-toggle-collapse-icon]");
  const expandIcon = document.querySelector("[data-sidebar-toggle-expand-icon]");

  document
    .querySelectorAll("[data-sidebar-collapse-hide]")
    .forEach((el) => el.classList.toggle("hidden", collapsed));
  document
    .querySelectorAll("[data-sidebar-collapse-subitem]")
    .forEach((el) => el.classList.toggle("pl-10", !collapsed));

  sidebar.classList.toggle("w-64", !collapsed);
  sidebar.classList.toggle("w-16", collapsed);
  main.classList.toggle("lg:ms-64", !collapsed);
  main.classList.toggle("lg:ml-16", collapsed);

  if (collapseIcon) collapseIcon.classList.toggle("hidden", collapsed);
  if (expandIcon) expandIcon.classList.toggle("hidden", !collapsed);
  if (toggle) toggle.setAttribute("aria-expanded", String(!collapsed));

  // When collapsed, every nav group's items show as an icon rail; when expanded,
  // restore each group's saved open/closed state.
  applyDropdownState();
}

function isSidebarCollapsed() {
  return localStorage.getItem(SIDEBAR_KEY) === "false";
}

// Collapsed only when explicitly saved as "false"; defaults to expanded.
function applySidebarState() {
  setSidebarCollapsed(isSidebarCollapsed());
}

// ---- Sidebar collapsible nav groups ----
// We manage these ourselves (via `data-nav-collapse`) rather than Flowbite, so
// the open/closed state survives LiveView navigation: the server always renders
// groups closed, so we persist which are open and re-apply after each render.
function getOpenDropdowns() {
  try {
    return new Set(JSON.parse(localStorage.getItem(DROPDOWN_KEY)) || []);
  } catch (_e) {
    return new Set();
  }
}

function saveOpenDropdowns(set) {
  localStorage.setItem(DROPDOWN_KEY, JSON.stringify([...set]));
}

function applyDropdownState() {
  // A collapsed (icon-rail) sidebar force-shows every group so its sub-item icons
  // stay reachable, ignoring the saved open/closed state.
  const collapsed = isSidebarCollapsed();
  const open = getOpenDropdowns();
  document.querySelectorAll("[data-nav-collapse]").forEach((btn) => {
    const id = btn.getAttribute("data-nav-collapse");
    const menu = document.getElementById(id);
    if (!menu) return;
    const isOpen = open.has(id);
    menu.classList.toggle("hidden", !(collapsed || isOpen));
    btn.setAttribute("aria-expanded", String(isOpen));
  });
}

function toggleDropdown(id) {
  const open = getOpenDropdowns();
  open.has(id) ? open.delete(id) : open.add(id);
  saveOpenDropdowns(open);
  applyDropdownState();
}

// ---- Sidebar a11y: keep the off-canvas mobile drawer out of the tab order ----
// On desktop the sidebar is a permanent nav; on mobile it's a drawer that sits
// off-canvas (`-translate-x-full`) until opened. Flowbite marks it `aria-hidden`
// but leaves its links focusable, so keyboard focus could land on the hidden
// menu. Drive both `inert` and `aria-hidden` off actual visibility instead.
const lgQuery = window.matchMedia("(min-width: 1024px)");

function syncSidebarInert() {
  const sidebar = document.getElementById("sidebar");
  if (!sidebar) return;
  const shown = lgQuery.matches || !sidebar.classList.contains("-translate-x-full");
  if (sidebar.inert !== !shown) sidebar.inert = !shown;
  const ariaHidden = shown ? "false" : "true";
  if (sidebar.getAttribute("aria-hidden") !== ariaHidden) {
    sidebar.setAttribute("aria-hidden", ariaHidden);
  }
}

const sidebarObserver = new MutationObserver(syncSidebarInert);

function observeSidebar() {
  const sidebar = document.getElementById("sidebar");
  if (sidebar) sidebarObserver.observe(sidebar, { attributes: true, attributeFilter: ["class"] });
  syncSidebarInert();
}

lgQuery.addEventListener("change", syncSidebarInert);

// ---- Active nav highlighting ----
const ACTIVE_CLASSES = ["bg-gray-100", "dark:bg-gray-700"];

// Highlight the sidebar link that best matches the current path (the longest href
// that prefixes it, so the Dashboard root only wins on an exact match), and open
// the group that holds an active sub-item.
function applyActiveNav() {
  const links = document.querySelectorAll("[data-nav-link]");
  links.forEach((el) => el.classList.remove(...ACTIVE_CLASSES));

  const path = window.location.pathname;
  let best = null;
  let bestLen = -1;

  links.forEach((el) => {
    const href = el.getAttribute("href");
    if (!href || !href.startsWith("/")) return;
    if ((path === href || path.startsWith(href + "/")) && href.length > bestLen) {
      best = el;
      bestLen = href.length;
    }
  });

  if (!best) return;
  best.classList.add(...ACTIVE_CLASSES);

  const menu = best.closest("[data-nav-menu]");
  if (menu && menu.id) {
    const open = getOpenDropdowns();
    open.add(menu.id);
    saveOpenDropdowns(open);
  }
}

// ---- Dark mode ----
function applyThemeIcons() {
  const darkIcon = document.getElementById("theme-toggle-dark-icon");
  const lightIcon = document.getElementById("theme-toggle-light-icon");
  if (!darkIcon || !lightIcon) return;

  // Show the icon representing the action the user can take next.
  const isDark = document.documentElement.classList.contains("dark");
  lightIcon.classList.toggle("hidden", !isDark);
  darkIcon.classList.toggle("hidden", isDark);
}

function toggleTheme() {
  const isDark = document.documentElement.classList.toggle("dark");
  localStorage.setItem(THEME_KEY, isDark ? "dark" : "light");
  applyThemeIcons();
}

// ---- Color theme (palette: midnight / enterprise / forest) ----
// Orthogonal to dark mode: this sets `data-theme` on <html>, which our CSS uses
// to pick the accent + neutral palette. The bootstrap script in root.html.heex
// applies it before first paint; here we switch it at runtime and persist it.
function getAppTheme() {
  return localStorage.getItem(APP_THEME_KEY) || DEFAULT_APP_THEME;
}

// Reflect the active theme in the selector: tick the chosen row, hide the rest.
function applyAppThemeState() {
  const current = getAppTheme();
  document.documentElement.setAttribute("data-theme", current);
  document.querySelectorAll("[data-set-theme]").forEach((el) => {
    const check = el.querySelector("[data-theme-check]");
    if (check) check.classList.toggle("invisible", el.getAttribute("data-set-theme") !== current);
  });
}

function setAppTheme(theme) {
  localStorage.setItem(APP_THEME_KEY, theme);
  applyAppThemeState();
}

// ---- Wiring (delegated; bound once for the page's lifetime) ----
document.addEventListener("click", (e) => {
  if (e.target.closest("#togglSidebarButton")) {
    const collapsed = localStorage.getItem(SIDEBAR_KEY) === "false";
    localStorage.setItem(SIDEBAR_KEY, collapsed ? "true" : "false");
    setSidebarCollapsed(!collapsed);
  }

  if (e.target.closest("#theme-toggle")) {
    toggleTheme();
  }

  const setTheme = e.target.closest("[data-set-theme]");
  if (setTheme) {
    setAppTheme(setTheme.getAttribute("data-set-theme"));
  }

  const navCollapse = e.target.closest("[data-nav-collapse]");
  if (navCollapse) {
    toggleDropdown(navCollapse.getAttribute("data-nav-collapse"));
  }
});

function applyLayoutState() {
  applyActiveNav();
  applySidebarState();
  applyDropdownState();
  applyThemeIcons();
  applyAppThemeState();
  observeSidebar();
}

// Re-apply after every live navigation (the shell DOM is re-rendered), plus once
// on initial load.
window.addEventListener("phx:page-loading-stop", applyLayoutState);
document.addEventListener("DOMContentLoaded", applyLayoutState);
applyLayoutState();
