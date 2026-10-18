# Bakkal projesi

Kullanıcı Türkçe konuşur; yanıtlar Türkçe, kısa ve sade olsun.

## Yapı
- `index.html`: **Bakkal Defteri** (tam sürüm). `kolay/index.html`: **Bakkal Kolay** (sade sürüm, yaşlı bir bakkal amca için: az yazı, büyük düğme, soru sorma).
- İkisi de tek dosyalık PWA (HTML+CSS+JS bir arada), aynı Supabase projesini kullanır (`mvonvaoatjhfmezlidrv`).
- `supabase-kurulum.sql`: veritabanı kurulumu. `supabase/functions/bildir/index.ts`: web-push bildirim servisi.
- `sw.js` sayfalar için ağ-öncelikli; cache sürümü artırmaya gerek yok.
- Bir düzeltme genelde **iki dosyaya da** uygulanır (Kolay'ın kendi katmanı `window.KOLAY` ve `k-*` sekmeleri).

## Kurallar
- Kolay'da işlevler kalır, yazılar kısalır; kullanıcıya soru sorulmaz. Uyarı gerekiyorsa "Doğruysa tekrar Kaydet'e bas" kalıbı kullanılır.
- Kolay'da bildirim türü seçilmez, hepsi gelir (`nAll()`). Tam sürümde seçim ekranı kalır.
- Rapor bildirimi: günün raporu "Günü Kapat"ta, 23:30'da yedek (pg_cron).
- Yeni özellikte `YENI_VER` artırılır ve "Yenilikler" notu + README "Değişiklikler" bölümü güncellenir.

## Test
Playwright (headless Chromium) ile test kopyası üzerinde: `CLOUD_ON=false`, veri localStorage `bd-veri` ile tohumlanır. 320 px taşma, geri tuşu, tutar girişi ve Yenilikler kutusu kontrol edilir.

## Bilinen
- Tam sürümde 280 px gibi çok dar ekranda alt menü hafif taşar.
- Kolay'da rehber metinleri ve "Fiyat Yazıp Sat" yazısı hâlâ uzun.
