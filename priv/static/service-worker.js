// FleetMS service worker — a light PWA shell.
//
// Scope is deliberately narrow: FleetMS is a Phoenix LiveView app, so pages need a
// live server connection to render. We therefore DO NOT cache navigations (that
// would serve dead, stale HTML) — page loads go to the network and only fall back
// to a branded offline page when there's no connection. What we cache is the
// fingerprinted static shell (assets/fonts/icons), which makes repeat loads fast
// and the app installable. Real offline data capture is the native app's job.
const CACHE = "fleetms-shell-v1";
const PRECACHE = [
  "/offline.html",
  "/manifest.json",
  "/images/icon-192.png",
  "/images/icon-512.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // Fingerprinted static assets: cache-first (filenames change on deploy, so this
  // is never stale). Revalidate in the background on a hit.
  if (/^\/(assets|fonts|fontawesome|images)\//.test(url.pathname)) {
    event.respondWith(
      caches.match(request).then((cached) => {
        const network = fetch(request)
          .then((res) => {
            const copy = res.clone();
            caches.open(CACHE).then((cache) => cache.put(request, copy));
            return res;
          })
          .catch(() => cached);
        return cached || network;
      }),
    );
    return;
  }

  // Page navigations: network-first; fall back to the offline page when offline.
  // Never cache LiveView HTML.
  if (request.mode === "navigate") {
    event.respondWith(fetch(request).catch(() => caches.match("/offline.html")));
  }
});
