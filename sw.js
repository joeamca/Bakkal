// Bakkal Defteri: sadece bildirimler için (sayfaları önbelleğe almaz, her açılışta güncel sürüm gelir)
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil(self.clients.claim()));
self.addEventListener("push", e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) { d = { title: "Bakkal Defteri", body: e.data ? e.data.text() : "" }; }
  const base = self.registration.scope;
  e.waitUntil(self.registration.showNotification(d.title || "Bakkal Defteri", {
    body: d.body || "", icon: d.icon || base + "icons/n-genel.png", badge: d.badge || base + "icons/badge.png",
    tag: d.tag || undefined, renotify: !!d.tag, lang: "tr", vibrate: [80, 40, 80], timestamp: Date.now(), data: { url: d.url || base }
  }));
});
self.addEventListener("notificationclick", e => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || self.registration.scope;
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(ws => {
    for (const w of ws) if (w.url.startsWith(url) && "focus" in w) return w.focus();
    return self.clients.openWindow(url);
  }));
});
