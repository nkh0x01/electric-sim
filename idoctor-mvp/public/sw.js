// iDoctor.ge service worker — minimal offline shell.
// Chat/API responses are never cached (medical content must be fresh).
const CACHE = 'idoctor-shell-v1';
const SHELL = ['/', '/manifest.json', '/icons/icon-192.png', '/icons/icon-512.png'];

self.addEventListener('install', (e) => {
    e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
    e.waitUntil(
        caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
            .then(() => self.clients.claim())
    );
});

self.addEventListener('fetch', (e) => {
    const url = new URL(e.request.url);
    // Never cache API or chat traffic.
    if (url.pathname.startsWith('/api') || e.request.method !== 'GET') return;

    e.respondWith(
        caches.match(e.request).then((cached) => cached || fetch(e.request).catch(() => caches.match('/')))
    );
});
