// A small service worker, so the installed app opens without a network.
//
// Flutter ships one of its own, but as of 3.47 it is deprecated, no longer
// registered by the bootstrap, and slated for removal -- a build on this
// version registers nothing and does not work offline. This replaces it.
//
// Two strategies, chosen by what the file is:
//
//   network-first  index.html and flutter_bootstrap.js, the two files that
//                  decide which build you are running. Fresh when online,
//                  cached when not, so a deploy is picked up on the next
//                  load rather than whenever a cache happens to expire.
//
//   cache-first    everything else. The engine, the wasm, the fonts and the
//                  assets are large and effectively immutable within a
//                  build, so going to the network for them wastes time.

const CACHE = 'fsudoku-shell-v1';

// Precached on install rather than filled in as things are requested.
//
// Runtime caching alone is not enough here: under cross-origin isolation the
// renderer runs on web workers, and the fetches they make for skwasm.wasm and
// main.dart.mjs do not pass through this worker. Those are precisely the files
// whose absence leaves a blank page offline, so they are fetched up front.
//
// Flutter's own service worker used to carry a generated file manifest. As of
// 3.47 it is a stub that unregisters itself, so the list lives here. These are
// stable output names; the fonts are read from Flutter's manifest so adding a
// typeface does not need an edit here.
const CORE = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'flutter.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  // Whichever of these a given build produced; missing ones are skipped.
  'main.dart.js',
  'main.dart.wasm',
  'main.dart.mjs',
  'canvaskit/skwasm.js',
  'canvaskit/skwasm.wasm',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'assets/FontManifest.json',
  'assets/AssetManifest.bin.json',
  'assets/fonts/MaterialIcons-Regular.otf',
  'assets/fonts/fallback/Roboto-Regular.ttf',
];

/// Font asset paths, read from the manifest Flutter generates.
async function fontAssets() {
  try {
    const manifest = await (await fetch('assets/FontManifest.json')).json();
    return manifest.flatMap((family) =>
      (family.fonts || []).map((f) => 'assets/' + f.asset),
    );
  } catch (e) {
    return [];
  }
}

const isDocument = (url) =>
  url.pathname.endsWith('/') ||
  url.pathname.endsWith('index.html') ||
  url.pathname.endsWith('flutter_bootstrap.js');

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      const paths = CORE.concat(await fontAssets());
      // Individually, so one missing file does not abandon the whole install:
      // a build has either the wasm outputs or the JS ones, never both in use.
      await Promise.allSettled(paths.map((path) => cache.add(path)));
      // Ready immediately rather than waiting for every tab to close; there is
      // no older worker of ours whose caches this could pull out from under.
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

// The page sends this when the player accepts an update.
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // Writes are handed to waitUntil, not fired and forgotten. A worker can be
  // stopped the moment it has answered, and the largest file here -- the
  // several-megabyte renderer -- is the one most likely to be cut off
  // mid-write, which is exactly the file whose absence breaks offline.
  const keep = (response) => {
    if (!response || !response.ok || response.type !== 'basic') return;
    const copy = response.clone();
    event.waitUntil(caches.open(CACHE).then((cache) => cache.put(request, copy)));
  };

  if (isDocument(url)) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          keep(response);
          return response;
        })
        .catch(() =>
          caches
            .match(request)
            .then((hit) => hit || caches.match('index.html')),
        ),
    );
    return;
  }

  event.respondWith(
    caches.match(request).then((hit) => {
      if (hit) return hit;
      return fetch(request).then((response) => {
        keep(response);
        return response;
      });
    }),
  );
});
