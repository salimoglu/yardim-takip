const CACHE = 'yardim-takip-v7';
const ASSETS = [
  '/yardim-takip/',
  '/yardim-takip/index.html',
  '/yardim-takip/manifest.json'
];

self.addEventListener('install', function(e) {
  e.waitUntil(
    caches.open(CACHE).then(function(cache) {
      return cache.addAll(ASSETS);
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(
        keys.filter(function(k) { return k !== CACHE; })
            .map(function(k) { return caches.delete(k); })
      );
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', function(e) {
  // Firebase ve CDN isteklerini cache'leme
  if (e.request.url.includes('firebase') ||
      e.request.url.includes('gstatic') ||
      e.request.url.includes('googleapis') ||
      e.request.url.includes('cloudflare') ||
      e.request.url.includes('jsdelivr')) {
    return;
  }
  // Network-first: önce ağdan al, başarısız olursa cache'ten
  e.respondWith(
    fetch(e.request).then(function(response) {
      var clone = response.clone();
      caches.open(CACHE).then(function(cache) {
        cache.put(e.request, clone);
      });
      return response;
    }).catch(function() {
      return caches.match(e.request).then(function(cached) {
        return cached || caches.match('/yardim-takip/index.html');
      });
    })
  );
});
