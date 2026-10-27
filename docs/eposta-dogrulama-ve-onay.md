# E-posta gönderimi, doğrulama ve koşul onayı

Bu belge, "şifre sıfırlama / doğrulama e-postası gelmiyor" sorununun
nedenlerini, kodda yapılan düzeltmeleri ve Firebase konsolunda yapılması
gerekenleri tek yerde toplar.

## 1. Kodda ne değişti

| Konu | Önce | Şimdi |
| --- | --- | --- |
| Kayıt sonrası doğrulama | `sendEmailVerification()` **hiç çağrılmıyordu** | Kayıt (`signUp`) sonunda otomatik gönderilir |
| Doğrulama hatırlatması | Yoktu | Sohbetler ve Profil ekranında şerit: **Tekrar gönder** / **Doğruladım** |
| Şifre sıfırlama | Sadece "gönderildi" snackbar'ı | Onay diyaloğu: hangi adrese gitti, spam klasörü, 1 saat geçerlilik, **Tekrar gönder** |
| Hata mesajları | Genel mesaj | `quota-exceeded`, `missing-email`, `unauthorized-domain`, `network-request-failed` için Türkçe, sebebi söyleyen metinler |
| Kullanıcı profili | E-posta doğrulama durumu yazılmıyordu | `users/{uid}.emailVerified` alanı güncellenir |

"Bağlantıya tıkladım ama uygulama hâlâ doğrulanmamış diyor" durumu normaldir:
Firebase bağlantıya tıklandığında **sunucuda** durumu değiştirir; uygulama
bunu ancak `user.reload()` çağrısıyla öğrenir. Bu yüzden şeritteki
**Doğruladım** butonu `refreshEmailVerified()` çağırır.

## 2. E-posta neden gelmez? (kontrol listesi)

Kod doğru çağrı yapsa bile aşağıdakilerden biri eksikse e-posta gelmez.
Firebase konsolunda sırayla kontrol edin:

1. **Authentication → Templates (Şablonlar)**
   - *Password reset* ve *Email address verification* şablonları **etkin** mi?
   - "From name" ve "Reply-to" alanları dolu mu? Boş/ör. `noreply` adresi
     spam filtrelerinde itibar kaybı yaşatabilir.
   - Şablonun dili Türkçe seçildiyse içerik gerçekten Türkçe mi (boş şablon
     gönderilmez).
   - **Customize action URL** alanındaki alan adı,
     *Authentication → Settings → Authorized domains* listesinde olmalı.
     Aksi hâlde bağlantı `unauthorized-domain` hatası verir.
2. **Authentication → Settings → User actions**
   - *Email enumeration protection* açıksa Firebase, kayıtlı olmayan adres
     için de "gönderildi" der (güvenlik gereği). Yani "gönderildi" mesajı
     adresin var olduğu anlamına **gelmez**.
3. **Kota**
   - Ücretsiz planda günlük e-posta gönderim kotası vardır; aşılırsa
     `quota-exceeded` döner (uygulama artık bunu ayrı mesajla gösterir).
4. **Spam / Gereksiz / Promosyonlar**
   - Firebase e-postaları `firebaseapp.com` alan adından gelir ve ilk
     gönderimlerde sık sık spam'e düşer. Gönderen adresini beyaz listeye
     ekleyin. Gmail'de "Filtre → asla spam'e gönderme" kuralı işe yarar.
5. **Kurumsal filtre / okul ağı**
   - `firebaseapp.com` bazı kurum filtrelerinde engellenir.
6. **Adresin yazımı**
   - `gmail.con`, `hotmal.com` gibi yazım hataları en sık sebep.
7. **Telefon/uygulama tarafı**
   - Cihazda "arka plan verisi" kapalıysa istek sunucuya gitmez; Wi-Fi/mobil
     veri ile tekrar deneyin.

> Kanıt: Firebase konsolundaki **Authentication → Users** listesinde
> kullanıcının *Email verified* sütunu, e-postanın gerçekten doğrulanıp
> doğrulanmadığını gösterir. Uygulamadaki şerit de aynı bilgiyi gösterir.

## 3. Kendi alan adınızdan e-posta göndermek (isteğe bağlı)

Varsayılan `firebaseapp.com` gönderimi teslim edilebilirlik açısından
zayıftır. Gmail/SMTP ile kendi adresinizden göndermek isterseniz:

1. Google hesabında 2 adımlı doğrulamayı açın, **uygulama şifresi** üretin.
2. Firebase konsolu → *Authentication → Templates → SMTP settings*:
   `smtp.gmail.com`, port `465`, kullanıcı adı Gmail adresiniz, şifre
   uygulama şifresi.
3. Kaydedip test gönderin (günlük limit Gmail'de ~500).

Bu adımlar gizli bilgi içerdiği için repoya **yazılmaz**; yalnızca konsolda
yapılır.

## 4. Kullanım koşulu onayı (kanıt kaydı)

Kayıt ekranında onay kutusu işaretlenmeden **Kayıt ol / Google ile kayıt ol**
butonları çalışmaz. Onay, kullanıcı kaydolduktan hemen sonra iki yere yazılır:

```
users/{uid}
  termsAcceptedAt : serverTimestamp
  termsVersion    : "2026-10-27"

users/{uid}/consents/{autoId}      ← değiştirilemez (kural: update/delete false)
  uid, email, version, accepted, platform, acceptedAt
```

- `platform`: `android` / `ios` / `web`
- `acceptedAt`: **sunucu** zaman damgası (kullanıcı cihazından gelmez)
- Google ile giriş yapan kullanıcı onay vermemişse sohbetler ekranında bir
  kez, kapatılamayan onay diyaloğu çıkar.

Firestore kuralları `consents` kayıtlarını oluşturulduktan sonra
değiştirilmesini/silinmesini engeller; böylece "kurala aykırı davranış"
iddiasında tarih/saat/sürüm kanıtı korunur.

Otomatik toplanan teknik kayıt: `createdAt`, `lastSeenAt`, `email`,
`emailVerified`, sohbet mesajlarında `senderId` + `createdAt`. IP adresi
**toplanmıyor** (istismar şüphesinde Firebase Auth'un kendi denetim
kayıtları kullanılmalı).

## 5. Kuralların yayınlanması

```bash
firebase login
firebase deploy --only firestore:rules   # firestore.rules
```

Konsoldan da yapılabilir: *Firestore Database → Rules →* içeriği yapıştır →
**Publish**. Yeni alanlar (`username`, `usernameLower`, `bio`, `avatarEmoji`,
`avatarColor`, `usernameChanges`, `usernameWindowStart`, `termsVersion`,
`termsAcceptedAt`, `emailVerified`, `displayNameLower`), yeni koleksiyonlar
(`usernames`, `consents`, `blocked`) ve
mesajlarda `senderPhotoUrl` alanı **yalnızca güncel kurallarla** çalışır.

## 6. Mevcut kullanıcılar

- Profili eski olan kullanıcıların `username` alanı yoktur; sohbetler
  ekranındaki "Kullanıcı adı ekle" şeridi ile tamamlanır.
- Kullanıcı adı **benzersizdir**: `usernames/{usernameLower}` dokümanı kilidi
  tutar, iki kişi aynı adı alamaz.
- Kullanıcı adı değiştirilirse eski kilit kaydı silinir.
