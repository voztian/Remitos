/* GoRemitos v2.9.1: retira el service worker offline de versiones anteriores. */
self.addEventListener('install',event=>{
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate',event=>{
  event.waitUntil((async()=>{
    const claves=await caches.keys();
    await Promise.all(claves.filter(k=>/^remitos-/i.test(k)).map(k=>caches.delete(k)));
    await self.registration.unregister();
    await self.clients.claim();
  })());
});
