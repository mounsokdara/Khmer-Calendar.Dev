'use strict';

const CACHE = 'khmer-calendar-web-v1';
const PRECACHE = [
  './',
  './index.html',
  './main.dart.js',
  './flutter.js',
  './flutter_bootstrap.js',
  './manifest.json',
  './favicon.png',
  './version.json',
  './offline.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) =>
        Promise.all(
          PRECACHE.map((url) => cache.add(url).catch(() => {})),
        ),
      )
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)));
      await self.clients.claim();
    })(),
  );
});

function isWeatherApi(url) {
  return url.hostname.endsWith('open-meteo.com');
}

function shouldHandle(url) {
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return false;
  if (url.hostname === 'grok.com') return false;
  if (isWeatherApi(url)) return true;
  return url.origin === self.location.origin;
}

async function cacheFirst(request, fallbackIndex) {
  const cached = await caches.match(request, { ignoreSearch: true });
  if (cached) return cached;
  try {
    const res = await fetch(request);
    store(request, res);
    return res;
  } catch (e) {
    if (fallbackIndex) {
      const index = (await caches.match('./index.html')) || (await caches.match('./'));
      if (index) return index;
    }
    throw e;
  }
}

async function networkFirst(request) {
  try {
    const res = await fetch(request, { cache: 'no-store' });
    store(request, res);
    return res;
  } catch (e) {
    const cached = await caches.match(request, { ignoreSearch: true });
    if (cached) return cached;
    throw e;
  }
}

async function networkOnly(request) {
  return fetch(request);
}

function store(request, res) {
  if (!res || !(res.ok || res.type === 'opaque')) return;
  const copy = res.clone();
  caches.open(CACHE).then((cache) => cache.put(request, copy)).catch(() => {});
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (!shouldHandle(url)) return;
  if (isWeatherApi(url)) {
    event.respondWith(networkOnly(request));
    return;
  }
  if (url.pathname.endsWith('/version.json') || url.pathname.endsWith('/version.txt')) {
    event.respondWith(networkFirst(request));
    return;
  }
  const nav = request.mode === 'navigate' || url.pathname === '/' || url.pathname.endsWith('/index.html');
  event.respondWith(cacheFirst(request, nav));
});

self.addEventListener('message', (event) => {
  const d = event.data;
  if (!d || d.type !== 'khmer-notify') return;
  event.waitUntil(
    self.registration.showNotification(d.title || 'Khmer Calendar', {
      body: d.body || '',
      icon: './icons/Icon-192.png',
      badge: './favicon.png',
      tag: d.tag || 'khmer-reminder',
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const c of list) {
        if (c.url && 'focus' in c) return c.focus();
      }
      return self.clients.openWindow('./');
    }),
  );
});
