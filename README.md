# Bakkal Defteri

Mahalle bakkalı için cep defteri: neyi ne kadar sipariş edeceğini söyler, bozulan malı ve kârını gösterir, veresiyeyi unutturmaz.

**Aç:** https://joeamca.github.io/Bakkal/

## Nasıl kullanılır
1. Bağlantıyı telefonda **Chrome** ya da **Safari** ile aç.
2. Yöneticinin verdiği **kullanıcı adı ve şifreyle** giriş yap.
3. Üç noktadan (iPhone'da paylaş düğmesinden) **Ana ekrana ekle**.
4. Mal gelince **Fatura**'ya gir; **Sipariş** ne alacağını söyler; haftada bir **Fire** kutusunu say.

## Bilmen gerekenler
- Kayıtlar internette, dükkânın hesabında durur; telefon değişse de kaybolmaz.
- İnternet yokken girilenler telefonda bekler, bağlantı gelince kendiliğinden gönderilir.
- Dükkân sahibi çalışanına ayrı hesap açabilir; kimin ne girdiği görünür.
- Bir dükkân başka dükkânın kayıtlarını göremez; yönetici de kayıtların içeriğini görmez.

## Kurulum (yönetici için)
Veritabanı Supabase'te. `supabase-kurulum.sql` dosyası Supabase panelinde **SQL Editor**'de bir kez çalıştırılır.
Sitedeki Supabase anahtarı herkese açık "anon" anahtarıdır; verileri veritabanındaki satır güvenliği kuralları korur.
