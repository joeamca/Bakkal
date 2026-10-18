# Bakkal Kolay

**Aç:** https://joeamca.github.io/Bakkal/kolay/

Bakkal Defteri'nin sade hâli: büyük düğmeler, az bölüm, kolay kullanım. Teknolojiyle arası iyi olmayanlar için yapıldı.

**Aynı hesap, aynı veriler.** Bakkal Kolay ayrı bir sistem değil; Bakkal Defteri'yle aynı sunucuyu, aynı hesabı ve aynı kayıtları kullanır. Kolay'da yapılan satış tam sürümde, tam sürümde eklenen ürün Kolay'da görünür. İkisi arasında istediğin an geçebilirsin.

<p>
<img src="../ekran/kolay-ana.jpg" width="200" alt="Ana Sayfa">
<img src="../ekran/kolay-kasa.jpg" width="200" alt="Kasa">
<img src="../ekran/kolay-stok.jpg" width="200" alt="Stok">
<img src="../ekran/kolay-kar.jpg" width="200" alt="Kâr ve Zarar">
<img src="../ekran/kolay-urun.jpg" width="200" alt="Ürün Ekle">
</p>

## Bölümler

Alt menüde sadece 5 bölüm var:

| Bölüm | Ne yapılır |
|---|---|
| **Ana Sayfa** | Kocaman "Satış Yap" düğmesi; bugünkü satış ve kâr; Para Koy, Para Al, Mal Geldi, Ürün Ekle kutuları; biten ürünler ve ödeme zamanı (varsa) |
| **Satış** | Barkodu okut, sepete eklensin; nakit, kart ya da veresiye |
| **Kasa** | Kasada olması gereken para; Para Koy, Para Al, Günü Kapat; sebep tek dokunuşla seçilir, toptancı ya da ekmekçi seçilince "Kime ödedin?" sorulur |
| **Stok** | Her ürünün yanında − / + ile raftaki sayı; Ürün Ekle ve Mal Geldi; ürüne dokununca düzenleme |
| **Kâr** | Satış − malın maliyeti − giderler = net kâr; bugün, bu hafta, bu ay, bu yıl; Excel'e indirme |

Ana Sayfa'nın altındaki **Diğer İşler** (ya da sağ üstteki ayar düğmesi): satış raporları, veresiye, tedarikçiler, bildirimler, ayarlar ve **tam sürüme geçiş**.

Kolay sürüm yaşlılar ve teknolojiyle arası iyi olmayanlar düşünülerek sade tutuldu: büyük yazı, büyük düğmeler, her ekranda az iş.

## Ürün eklemek

Tek bir **Ürün Ekle** düğmesi var; barkodlu ya da barkodsuz fark etmez. Form 4 adım:

1. **Barkod:** Varsa okut, yoksa geç. Barkod başka üründe kayıtlıysa hemen uyarır, "Onu Düzenle" der.
2. **Ürün adı**
3. **Satış ve alış fiyatı:** Tanesinden kaç TL ve yüzde kaç kâr kaldığını anında gösterir; zararına satışta uyarır.
4. **Rafta kaç tane var:** − / + düğmeleriyle. Tartılı ürünler için tek dokunuşla "kilo" seçilir.

**Aynı isimde ürün varsa** yeni ürün açılmaz: "Ekmek zaten var, rafta 2 tane" der ve **Üstüne Ekle** ile geleni mevcut ürüne ekler (2 + 2 = 4). Eskiden iki kez eklenmiş ürünler Stok ekranının üstünde gösterilir; **Birleştir** ile stokları toplanıp tek ürün olur.

Çok ürün girerken **Kaydet + Yeni** ile kaydedip hemen sıradakini okutursun. Satışta tanınmayan bir barkod okutulursa aynı form açılır; kaydedince ürün doğrudan sepete eklenir.

## Tedarikçiler, mal geldi, sayım

- **Mal Geldi** (Ana Sayfa'da, Stok'ta ve ürün sayfasında): kimden aldın, kaç tane, kaça. Stok artar; borç yazılır ya da peşin ödenir (kasadan / kasa dışı).
- **− / +** (Stok'ta her ürünün yanında): raftaki sayıyı düzeltir. Kimseye borç yazılmaz; sayım gibidir.
- **Tedarikçiler** (Ana Sayfa'daki kısayol ya da ayar düğmesi): kime ne kadar borcun var, ne aldın, ne ödedin. Kasadan "Para Al" yaparken tedarikçi seçersen borcundan düşer. Vade dolunca Ana Sayfa'da "Ödeme Zamanı" çıkar ve bildirim gelir.

## Rapor bildirimi

Her akşam 21:45'te "Günün raporu hazır" bildirimi gelir; pazar akşamı haftanın, ayın son günü ayın raporu da gelir. Bildirimde satış, fiş sayısı ve kâr yazar; dokununca rapor açılır, **Excel'i İndir** ile dosya iner. Ayarlar → Bildirimler'den hangilerinin geleceği seçilir.

## Kâr nasıl hesaplanır?

- **Brüt kâr** = satış − satılan malın alış fiyatı
- **Net kâr** = brüt kâr − giderler (kira, fatura, personel, çay-yemek…)
- Toptancıya ve ekmekçiye ödenen para gider sayılmaz: o mal parasıdır, mal satılınca maliyet olarak düşülür.
- Bankaya yatırılan ve kendine aldığın para da gider değildir; ayrıca gösterilir.

## İnternetsiz

Uygulama bir kez internetle açıldıktan sonra telefona kaydedilir; internet yokken de açılır. İnternetsiz yapılan satışlar telefonda bekler, bağlantı gelince kendiliğinden gönderilir. (İlk giriş için internet gerekir.)

## Telefona kurmak

- **Android:** Chrome'da aç → üç nokta → "Ana ekrana ekle". Mavi sepet simgesiyle ayrı bir uygulama gibi durur.
- **iPhone / iPad:** Safari'de aç → Paylaş → "Ana Ekrana Ekle". Bildirimler için bu şart.

## Tam sürümle farkı

| | Bakkal Kolay | Bakkal Defteri (tam) |
|---|:---:|:---:|
| Barkodla satış, kasa, stok | ✓ | ✓ |
| Kâr-zarar, Excel rapor | ✓ | ✓ |
| Veresiye, bildirimler | ✓ | ✓ |
| Sipariş önerisi, fatura girişi | | ✓ |
| İhtiyaç planı, stok maliyeti, fire | | ✓ |
| Reçeteli ürünler, araç günleri, özel günler | | ✓ |
