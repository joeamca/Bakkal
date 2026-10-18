// Bakkal Defteri bildirim servisi: dükkân cihazlarına simgeli web push gönderir.
// VAPID anahtarı sunucunun gizli anahtarından türetilir; ayrıca bir sır saklamaya gerek yok.
// Bu dosya Supabase'te çalışan "bildir" fonksiyonunun kaynağıdır (Edge Functions → bildir).
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { createECDH, hkdfSync } from "node:crypto";
import { Buffer } from "node:buffer";

const SUPA_URL = Deno.env.get("SUPABASE_URL")!;
const SRK = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BASE = "https://joeamca.github.io/Bakkal/";
const priv = Buffer.from(hkdfSync("sha256", SRK, "bakkal-defteri", "vapid-v1", 32));
const ecdh = createECDH("prime256v1"); ecdh.setPrivateKey(priv);
const PUB = ecdh.getPublicKey().toString("base64url");
webpush.setVapidDetails("mailto:bildirim@bakkaldefteri.app", PUB, priv.toString("base64url"));

const ICON: Record<string, string> = { stok: "n-stok", bitti: "n-bitti", kasa: "n-kasa", cikis: "n-cikis", veresiye: "n-veresiye", basvuru: "n-basvuru", deneme: "n-genel", rapor: "n-gun", tedarik: "n-tedarik", calisan: "n-genel" };
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const j = (x: unknown, status = 200) => new Response(JSON.stringify(x), { status, headers: { ...cors, "Content-Type": "application/json" } });
const clip = (s: unknown, n: number) => String(s ?? "").replace(/[\u0000-\u001f]/g, " ").slice(0, n);

type Sub = { endpoint: string; p256dh: string; auth: string; app: string };
async function send(db: ReturnType<typeof createClient>, subs: Sub[], msg: { type: string; title: string; body: string; tag?: string; q?: string }) {
  let sent = 0;
  await Promise.all(subs.slice(0, 60).map(async (s) => {
    const payload = JSON.stringify({ title: msg.title, body: msg.body, tag: msg.tag || msg.type, type: msg.type,
      icon: `${BASE}icons/${ICON[msg.type] || "n-genel"}.png`, badge: `${BASE}icons/badge.png`, url: BASE + (s.app === "kolay" ? "kolay/" : "") + (msg.q || "") });
    try {
      const d = webpush.generateRequestDetails({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 6 * 3600, urgency: "high" });
      const r = await fetch(d.endpoint, { method: d.method, headers: d.headers as Record<string, string>, body: d.body as Uint8Array });
      if (r.status === 404 || r.status === 410) await db.rpc("push_drop", { p_endpoint: s.endpoint });
      else if (r.ok) sent++;
      else console.log("push", r.status, (await r.text()).slice(0, 200));
    } catch (e) { console.log("push hata", String(e).slice(0, 200)); }
  }));
  return sent;
}

const TL = (n: number) => Number(n || 0).toLocaleString("tr-TR", { maximumFractionDigits: 2 }) + " TL";
const dt = (x: string, o: Intl.DateTimeFormatOptions) => new Date(x + "T12:00:00Z").toLocaleDateString("tr-TR", o);
// gün / hafta / ay raporu bildirimleri (ortak: hem gün kapanışı hem yedek zamanlayıcı kullanır)
// deno-lint-ignore no-explicit-any
async function sendReports(db: ReturnType<typeof createClient>, items: any[]) {
  let sent = 0;
  for (const it of (items || [])) {
    const per = it.kind === "gun" ? dt(it.from, { day: "numeric", month: "long" }) : it.kind === "hafta" ? `${dt(it.from, { day: "numeric", month: "short" })} – ${dt(it.to, { day: "numeric", month: "short" })}` : dt(it.from, { month: "long", year: "numeric" });
    const title = it.kind === "gun" ? "Günün raporu hazır" : it.kind === "hafta" ? "Haftanın raporu hazır" : `${dt(it.from, { month: "long" })} ayının raporu hazır`;
    const body = `${it.name} · ${per}: ${TL(it.ciro)} satış, ${Number(it.fis || 0).toLocaleString("tr-TR")} fiş, ${TL(it.kar)} kâr. Excel için dokun.`;
    sent += await send(db, (it.subs || []) as Sub[], { type: "rapor", title, body, tag: "rapor-" + it.kind, q: `?rapor=${it.kind}&a=${it.from}&b=${it.to}` });
  }
  return sent;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  let b: Record<string, unknown> = {};
  try { b = await req.json(); } catch (_) { /* boş gövde */ }
  const type = String(b.type || "");
  if (type === "anahtar") return j({ publicKey: PUB });
  if (!ICON[type]) return j({ error: "Bilinmeyen bildirim türü." }, 400);
  const db = createClient(SUPA_URL, SRK, { auth: { persistSession: false } });

  if (type === "rapor") {
    const key = String(b.key || "");
    if (key) { // yedek: sunucunun zamanlayıcısı her akşam 23:30'da çağırır; bugün günü kapatmış dükkânlar atlanır
      const { data: t, error } = await db.rpc("push_report_targets", { p_key: key });
      if (error) { console.log("rapor hata", error.message); return j({ error: "Sunucu hazır değil." }, 500); }
      if (!t?.ok) return j({ error: "Yetkisiz." }, 403);
      let sent = await sendReports(db, t.items || []);
      const { data: ts, error: te } = await db.rpc("push_supplier_targets", { p_key: key });
      if (te) console.log("tedarik hata", te.message);
      for (const it of (ts?.items || [])) {
        sent += await send(db, (it.subs || []) as Sub[], { type: "tedarik", title: "Tedarikçiye ödeme zamanı", body: `${it.name}: ${TL(it.bal)} borcun ${it.age} gündür bekliyor (vade ${it.vade} gün).`, tag: "tedarik-" + it.sid, q: `?ted=${encodeURIComponent(it.sid)}` });
      }
      return j({ sent });
    }
    // gün kapanışı: giriş yapmış kullanıcı kendi dükkânının raporunu gönderir
    const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const { data: u } = await db.auth.getUser(token);
    const uid = u?.user?.id;
    if (!uid) return j({ error: "Giriş gerekli." }, 401);
    const shop = String(b.shop_id || "");
    if (!/^[0-9a-f-]{36}$/i.test(shop)) return j({ error: "Dükkân seçili değil." }, 400);
    const { data: t, error } = await db.rpc("push_report_shop", { p_uid: uid, p_shop: shop });
    if (error) { console.log("rapor hata", error.message); return j({ error: "Sunucu hazır değil." }, 500); }
    if (!t?.ok) return j({ error: "Bu dükkânın üyesi değilsin." }, 403);
    return j({ sent: await sendReports(db, t.items || []) });
  }

  if (type === "basvuru") { // girişsiz kayıt formundan: sadece gerçekten yeni başvuru varsa yöneticilere
    const { data: t, error } = await db.rpc("push_admin_targets");
    if (error) { console.log("hedef hata", error.message); return j({ error: "Sunucu hazır değil." }, 500); }
    if (!t || !t.yeni) return j({ sent: 0 });
    return j({ sent: await send(db, (t.subs || []) as Sub[], { type, title: "Yeni kayıt başvurusu", body: `Onay bekleyen ${t.bekleyen || 1} başvuru var.`, tag: "basvuru" }) });
  }

  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const { data: u } = await db.auth.getUser(token);
  const uid = u?.user?.id;
  if (!uid) return j({ error: "Giriş gerekli." }, 401);
  const shop = String(b.shop_id || "");
  if (!/^[0-9a-f-]{36}$/i.test(shop)) return j({ error: "Dükkân seçili değil." }, 400);
  const { data: t, error } = await db.rpc("push_targets", { p_uid: uid, p_shop: shop, p_type: type, p_exclude: b.exclude ? String(b.exclude) : null, p_endpoint: b.endpoint ? String(b.endpoint) : null });
  if (error) { console.log("hedef hata", error.message); return j({ error: "Sunucu hazır değil: kurulum SQL'i çalıştırılmalı." }, 500); }
  if (!t?.ok) return j({ error: "Bu dükkânın üyesi değilsin." }, 403);
  const subs = t.subs;
  const sent = await send(db, (subs || []) as Sub[], { type, title: clip(b.title, 80) || "Bakkal Defteri", body: clip(b.body, 240), tag: clip(b.tag, 60) });
  return j({ sent });
});
