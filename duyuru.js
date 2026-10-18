/* Bakkal Defteri / Bakkal Kolay: duyuru kartı (yazı şablonları + kart çizimi + paylaşma).
   Uygulama bu dosyayı Duyuru ekranı ilk açılınca yükler. Telefonda çalışır, internet istemez. */
(function () {
  "use strict";
  if (window.Duyuru) return;

  const TYPES = [
    { id: "stok", ad: "Stok Geldi", alt: "Ürün geldi, haber ver", emoji: "📦" },
    { id: "cuma", ad: "Cuma Mesajı", alt: "Hayırlı Cumalar", emoji: "🌷" },
    { id: "bayram", ad: "Bayram", alt: "Açığız ya da kapalıyız", emoji: "🎉" },
    { id: "acik", ad: "Açık / Kapalı", alt: "Bugün durumumuz", emoji: "🏪" },
    { id: "gunaydin", ad: "Günaydın", alt: "Mahalleye merhaba", emoji: "🌞" },
    { id: "kampanya", ad: "Kampanya", alt: "Ürüne özel fiyat", emoji: "🏷️" }
  ];
  const THEMES = [
    { ad: "Mavi", a: "#1e40af", b: "#60a5fa", ink: "#14306e" },
    { ad: "Yeşil", a: "#166534", b: "#86efac", ink: "#0f4a26" },
    { ad: "Turuncu", a: "#c2410c", b: "#fdba74", ink: "#7c2d12" },
    { ad: "Pembe", a: "#9d174d", b: "#f9a8d4", ink: "#6b1038" }
  ];

  // [başlık, gövde, emoji]; {dukkan} {urun} {fiyat} {saat} {bayram} yerine konur
  const BANK = {
    stok: [
      ["{urun} geldi!", "Rafta yerini aldı. Koşun gelin, tükenmeden!", "🛒"],
      ["Müjde! {urun} bizde", "Mahalle rahat nefes alsın, sıra beklemeden gelin.", "🎉"],
      ["{urun} geldi, bayram erken geldi", "Kıyamet kopmadan bir uğrayın 😄", "📦"],
      ["Alarm! {urun} stokta", "Şimdi gelen alır, sonra gelen 'keşke' der.", "🚨"]
    ],
    cuma: [
      ["Hayırlı Cumalar", "Kapımız açık, çayımız demli. Bir uğrayın!", "☕"],
      ["Cuma geldi, hayırlar getirdi", "Mahallemize bereket, hepinize sağlık.", "🌷"],
      ["Hayırlı Cumalar komşum", "Bugün de buradayız, ekmeğiniz sıcak.", "🥖"],
      ["Cumanız mübarek olsun", "Gönlünüz ve sofranız bereketli olsun.", "🌹"]
    ],
    bayram_acik: [
      ["{bayram} mübarek olsun", "Bayramda da buradayız: {saat}. Eksiğiniz olursa koşun gelin.", "🎉"],
      ["Bayramınız kutlu olsun", "Açığız: {saat}. Şekeriniz bizden, sohbetimiz bedava!", "🍬"],
      ["Bayram sevinci kapımızda", "{saat} arası açığız. Hepinize iyi bayramlar.", "🌙"]
    ],
    bayram_kapali: [
      ["{bayram} mübarek olsun", "Bayramda kapalıyız. Sonrasında yine buradayız!", "🎉"],
      ["Bayramınız kutlu olsun", "Bu bayram biraz dinleniyoruz. Hepinize iyi bayramlar.", "🌙"]
    ],
    acik_acik: [
      ["Bugün açığız", "{saat} arası buradayız. Gelin, çayımız demli.", "🏪"],
      ["Kapımız açık", "{saat}. Eksiğiniz neyse bizde.", "🚪"],
      ["Bakkal açık!", "{saat}. Ekmek, süt, sohbet hep bizde.", "🥛"]
    ],
    acik_kapali: [
      ["Bugün kapalıyız", "Yarın yine buradayız. Anlayışınız için sağ olun.", "🙏"],
      ["Kısa bir ara", "Bugün kapalıyız. Yarın görüşmek üzere!", "😴"]
    ],
    gunaydin: [
      ["Günaydın mahalle!", "Güne ekmek kokusuyla başlayın, biz hazırız.", "🌞"],
      ["Günaydın komşum", "Çayı demle, gel; bakkal açık.", "☕"],
      ["Güne merhaba!", "Eksiğiniz varsa bizde. Kolay gelsin herkese.", "🌅"],
      ["Günaydın!", "Bugün herkes güzel, siz de öylesiniz 😄", "😄"]
    ],
    kampanya: [
      ["{urun} {fiyat} TL", "Bugüne özel fiyat! Tükenmeden gelin.", "🏷️"],
      ["Fırsat! {urun}", "Sadece {fiyat} TL. Cüzdanınız teşekkür eder.", "💸"],
      ["{urun} {fiyat} TL'ye düştü", "Kaçıran kendine küssün 😄", "🔥"],
      ["Bugün {urun} günü", "{fiyat} TL. Gelen alır, gelmeyen sorar.", "🎯"]
    ]
  };

  const sub = (s, c) => String(s).replace(/\{(\w+)\}/g, (_, k) => (c[k] != null && c[k] !== "" ? c[k] : "…"));
  const key = (type, c) => type === "bayram" ? (c.durum === "kapali" ? "bayram_kapali" : "bayram_acik")
    : type === "acik" ? (c.durum === "kapali" ? "acik_kapali" : "acik_acik") : type;
  const variants = (type, c) => (BANK[key(type, c || {})] || []).length;
  function text(type, v, c) {
    const list = BANK[key(type, c)] || BANK.gunaydin, t = list[((v % list.length) + list.length) % list.length];
    const title = sub(t[0], c), body = sub(t[1], c);
    return { title: title, body: body, emoji: t[2], share: title + "\n" + body + "\n— " + (c.dukkan || "Mahalle Bakkalı") };
  }

  /* ---------- kart çizimi ---------- */
  const FONT = "system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif";
  const EMOJI = "'Apple Color Emoji','Noto Color Emoji','Segoe UI Emoji',sans-serif";
  function rr(x, a, b, w, h, r) { x.beginPath(); x.moveTo(a + r, b); x.arcTo(a + w, b, a + w, b + h, r); x.arcTo(a + w, b + h, a, b + h, r); x.arcTo(a, b + h, a, b, r); x.arcTo(a, b, a + w, b, r); x.closePath(); }
  function wrap(x, s, maxW) {
    const words = String(s).split(/\s+/), lines = []; let cur = "";
    for (const w of words) { const t = cur ? cur + " " + w : w; if (x.measureText(t).width <= maxW || !cur) cur = t; else { lines.push(cur); cur = w; } }
    if (cur) lines.push(cur); return lines;
  }
  function fit(x, s, maxW, maxLines, from, to, weight) {
    for (let sz = from; sz >= to; sz -= 4) {
      x.font = weight + " " + sz + "px " + FONT;
      const L = wrap(x, s, maxW);
      if (L.length <= maxLines && L.every(l => x.measureText(l).width <= maxW)) return { sz: sz, lines: L };
    }
    x.font = weight + " " + to + "px " + FONT; return { sz: to, lines: wrap(x, s, maxW).slice(0, maxLines) };
  }
  function draw(type, v, themeIdx, c) {
    const S = 1080, cv = document.createElement("canvas"); cv.width = S; cv.height = S;
    const x = cv.getContext("2d"), th = THEMES[((themeIdx % THEMES.length) + THEMES.length) % THEMES.length], t = text(type, v, c);
    const g = x.createLinearGradient(0, 0, S, S); g.addColorStop(0, th.a); g.addColorStop(1, th.b); x.fillStyle = g; x.fillRect(0, 0, S, S);
    // süs: yarı saydam daireler (her tür/yazı için aynı yerde)
    let seed = 7 + v * 13 + type.length * 5; const rnd = () => (seed = (seed * 9301 + 49297) % 233280) / 233280;
    for (let i = 0; i < 9; i++) { x.fillStyle = "rgba(255,255,255," + (0.05 + rnd() * 0.1).toFixed(2) + ")"; x.beginPath(); x.arc(rnd() * S, rnd() * S, 50 + rnd() * 170, 0, 7); x.fill(); }
    // dükkân adı
    x.textBaseline = "alphabetic"; x.textAlign = "left"; x.fillStyle = "#fff";
    const name = c.dukkan || "Mahalle Bakkalı", nf = fit(x, name, S - 160, 1, 64, 36, "800");
    x.font = "800 " + nf.sz + "px " + FONT; x.shadowColor = "rgba(0,0,0,.25)"; x.shadowBlur = 8; x.fillText(nf.lines[0], 64, 110); x.shadowBlur = 0;
    // emoji
    x.textAlign = "center"; x.textBaseline = "middle"; x.font = "300px " + EMOJI; x.fillText(t.emoji, S / 2, 330);
    // beyaz kart
    const cx0 = 60, cy0 = 520, cw = S - 120, ch = 440;
    x.fillStyle = "rgba(0,0,0,.15)"; rr(x, cx0, cy0 + 10, cw, ch, 44); x.fill();
    x.fillStyle = "#fff"; rr(x, cx0, cy0, cw, ch, 44); x.fill();
    x.textAlign = "center"; x.textBaseline = "alphabetic";
    const tf = fit(x, t.title, cw - 90, 2, 92, 52, "800"), bf = fit(x, t.body, cw - 100, 3, 50, 32, "500");
    const th1 = tf.lines.length * tf.sz * 1.15, bh1 = bf.lines.length * bf.sz * 1.3, gap = 26, total = th1 + gap + bh1;
    let y = cy0 + (ch - total) / 2 + tf.sz * 0.95;
    x.fillStyle = th.ink; x.font = "800 " + tf.sz + "px " + FONT;
    for (const l of tf.lines) { x.fillText(l, S / 2, y); y += tf.sz * 1.15; }
    y += gap - tf.sz * 0.15 + bf.sz * 0.2; x.fillStyle = "#374151"; x.font = "500 " + bf.sz + "px " + FONT;
    for (const l of bf.lines) { x.fillText(l, S / 2, y); y += bf.sz * 1.3; }
    // alt yazı
    x.fillStyle = "rgba(255,255,255,.95)"; x.font = "600 34px " + FONT; x.fillText("Mahallenin bakkalı", S / 2, 1030);
    return cv;
  }
  const cache = {};
  function dataUrl(type, v, themeIdx, c) {
    const k = [type, v, themeIdx, c.dukkan, c.urun, c.fiyat, c.saat, c.bayram, c.durum].join("|");
    if (!cache[k]) { const keys = Object.keys(cache); if (keys.length > 12) delete cache[keys[0]]; cache[k] = draw(type, v, themeIdx, c).toDataURL("image/jpeg", 0.88); }
    return cache[k];
  }

  /* ---------- paylaşma ---------- */
  async function share(type, v, themeIdx, c) {
    const cv = draw(type, v, themeIdx, c), t = text(type, v, c);
    const blob = await new Promise(r => cv.toBlob(r, "image/jpeg", 0.92)), name = "duyuru-" + type;
    let file = null; try { file = new File([blob], name + ".jpg", { type: "image/jpeg" }); } catch (_) {}
    if (file && navigator.canShare && navigator.canShare({ files: [file] })) {
      try { await navigator.share({ files: [file], text: t.share }); return "shared"; }
      catch (e) { if (e && e.name === "AbortError") return "cancelled"; }
    }
    const a = document.createElement("a"); a.href = URL.createObjectURL(blob); a.download = name + ".jpg"; document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 5000); return "downloaded";
  }
  async function copy(type, v, c) {
    const s = text(type, v, c).share;
    try { await navigator.clipboard.writeText(s); return true; } catch (_) { return false; }
  }

  window.Duyuru = { TYPES: TYPES, THEMES: THEMES, text: text, variants: variants, draw: draw, dataUrl: dataUrl, share: share, copy: copy };
})();
