# Profil, kullanıcı adıyla sohbet, engelleme ve sohbet silme

Bu belge, sürüm 0.2.0 ile gelen özelliklerin nasıl çalıştığını ve veri
modelini açıklar.

## 1. Kullanıcı adı ve "yeni sohbet"

- Her kullanıcı **benzersiz** bir kullanıcı adı seçebilir:
  3-20 karakter, yalnızca küçük harf / rakam / alt çizgi (`ayse_y`).
- Profilde ad, hakkında (bio) ve **galeriden seçilen profil fotoğrafı**
  düzenlenebilir. Emoji/renk panelleri ile fotoğraf bağlantısı (URL) alanı
  kaldırıldı; avatar yalnızca galeriden seçilir (veya kaldırılır).
- Sohbetler ekranındaki **Yeni sohbet** butonu artık oda adı sormuyor:
  kullanıcı adı veya görünen ad yazıldıkça eşleşen kişiler
  (fotoğraf + ad + `@kullanıcıadı`) listelenir; birine dokununca doğrudan
  sohbet açılır.
- Doğrudan sohbetin Firestore kimliği sabittir: `dm_<küçükUid>_<büyükUid>`.
  Böylece aynı iki kişi arasında tek sohbet oluşur; ikinci kez "yeni sohbet"
  aynı sohbeti açar.

Veri modeli:

```
users/{uid}
  displayName, displayNameLower
  username, usernameLower
  bio, photoUrl                        ← https URL ya da data:image/…;base64
  avatarEmoji, avatarColor             ← eski kayıtlar için (artık düzenlenmez)
  usernameChanges, usernameWindowStart ← kullanıcı adı kotası
  email, emailVerified, createdAt, lastSeenAt
  termsVersion, termsAcceptedAt

usernames/{usernameLower}
  uid, usernameLower, createdAt        ← tekillik kilidi

rooms/{roomId}                        ← dm_<uidA>_<uidB> veya grup kimliği
  name, photoUrl, type ('dm'|'group'|'channel'), createdBy, ownerUid
  memberIds, roles {uid: 'mod'}, permissions {onlyModsPost, ...}
  isPrivate (özel kanal/grup)
  lastMessage, lastMessageAt, hiddenFor, memberNames, memberPhotos

reports/{id}                          şikayetler (yalnızca ekleme)
  reporterUid, targetUid, targetName, reason, details,
  roomId, messageId, messageSnippet, status, createdAt
support_requests/{id}                 destek talepleri (yalnızca ekleme)
  uid, name, email, topic, message, status, platform, createdAt
room_invites/{code}                   davet bağlantıları
  roomId, createdBy, roomName, roomType, createdAt
rooms/{roomId}/messages/{msgId}
  senderId, senderName, senderPhotoUrl, text, type, createdAt
```

## 2. Profil fotoğrafı ve ad girişte korunur

Google ile giriş yapıldığında hesabın fotoğrafı/adı `users/{uid}` dokümanına
yazılır — **ama kullanıcının kendi seçimi ezilmez**:

| Durum | Girişte davranış |
|---|---|
| Galeriden fotoğraf seçilmiş (`photoSource: custom`) | Google fotoğrafı **yazılmaz** |
| Fotoğraf bilerek kaldırılmış (`photoSource: none`) | Google fotoğrafı **geri gelmez** |
| Alan yok (eski kayıt) ama `photoUrl` `data:` ile başlıyor | Özel fotoğraf sayılır, korunur |
| Henüz fotoğraf yok | Google fotoğrafı yazılır |
| Kullanıcı adını uygulamada belirlemiş | Google adı **ezmez** |

Karar tek yerde: `lib/features/profile/domain/avatar_policy.dart`
(`AvatarPolicy.photoOnLogin` / `displayNameOnLogin`), testleri
`test/profile_test.dart` içinde. `photoSource` alanı Firestore kurallarında
`['custom', 'none']` dışında değer kabul etmez.

## 3. Kullanıcı adı değişiklik kotası

- **30 günlük dönemde en fazla 2 değişiklik.** Haklar bitince kullanıcı adı
  alanı kilitlenir ve kalan süre yazılır ("Yeni hak 12 gün sonra açılır").
- Dönem dolduğunda sayaç sıfırlanır, yeniden 2 hak tanınır.
- İlk kez kullanıcı adı **almak** (henüz ad yokken) hak harcamaz.
- Kontrol `saveProfile` içindeki Firestore transaction'ında yapılır:
  iki cihazdan aynı anda kaydetmek hakkı iki kez harcamaz.
- Alanlar: `usernameChanges` (0-2), `usernameWindowStart` (Timestamp).
  `firestore.rules` sayacın en fazla 1 artmasına izin verir.

## 4. Şikayet ve destek

| Akış | Nereden | Kayıt |
| --- | --- | --- |
| **Profili şikayet et** | Sohbet üst menüsü → *Profili şikayet et* · yeni sohbet aramasında satıra uzun bas · kanal/grup üye listesi | `reports/{id}` |
| **Mesajı şikayet et** | Mesaja uzun bas → *Mesajı şikayet et* | `reports/{id}` (`roomId`, `messageId`, `messageSnippet`) |
| **Destek talebi** | Profil → *Destek ve geri bildirim* | `support_requests/{id}` |

- Sebepler hazır listeden seçilir (spam, taciz, nefret söylemi, cinsel içerik,
  şiddet tehdidi, sahte hesap, diğer) ve istenirse ayrıntı yazılır.
- Her iki koleksiyon **yalnızca ekleme** kabul eder (kanıt niteliği); kullanıcı
  yalnızca **kendi** kaydını okuyabilir. İnceleme paneli (moderatör tarafı)
  sonraki adımda eklenebilir.
- Destek ekranında taleplerin durumu (*İncelemede*) ve geçmişi görünür.

## 5. Kanal ve grup ayarları

Sohbet üst menüsü → **Kanal/grup ayarları** (kanal ve gruplarda görünür).

| Bölüm | Kim yapabilir | Ne yapar |
| --- | --- | --- |
| Ad / açıklama | sahip, moderatör | Başlık ve açıklamayı günceller |
| İzinler | sahip, moderatör | *Yalnızca moderatörler paylaşsın* (kanal), *yalnızca moderatörler üye eklesin*, *moderatörler mesaj silebilsin* |
| Moderatörler | sahip, moderatör | Kullanıcı adıyla arayıp moderatör ekler, listeden çıkarır |
| Üyeler | herkes görür | Sahip/moderatör: rol ver, üyeyi çıkar, şikayet et. Sahip ayrıca **sahipliği devreder** |
| Ayrıl | herkes | Üyelikten çıkar (sahip önce devretmeli) |

- Roller `rooms/{roomId}.roles` (`uid → "mod"`), izinler `permissions`
  haritasında (`onlyModsPost`, `onlyModsAddMembers`, `modsDeleteMessages`)
  tutulur; sahiplik `ownerUid` alanındadır (grupta yoksa `createdBy`).
- Kanallarda varsayılan davranış **yalnızca sahip/moderatör paylaşır**;
  `onlyModsPost` kapatılırsa tüm aboneler gönderi paylaşabilir. Yetkisiz
  üyeler yazma alanı yerine "Yalnızca moderatörler paylaşım yapabilir" barını
  görür.
- Gruplarda tüm üyeler yazabilir; kısıt yalnızca üye ekleme/mesaj silme için
  ayarlanır.
- Kurallar: `roles`/`permissions` yalnızca sahip veya moderatör tarafından,
  `ownerUid` yalnızca mevcut sahip tarafından ve yeni sahip üye ise
  değiştirilebilir.

## 6. Davet bağlantıları ve kanal arama

### Davet bağlantısı (kanal + grup)
Sohbet üst menüsü → **Kanal/grup ayarları** → *Davet bağlantısı*:
- **Bağlantı oluştur** → 8 karakterlik kod üretir, `rebelzmedia://katil/<kod>`
  bağlantısı **panoya kopyalanır** (WhatsApp/e-posta ile paylaşılabilir).
- Altında geçerli kodlar listelenir: kopyala / iptal et.
- Karşı taraf katılmak için **Kanallar → sağ üstteki kod düğmesi → Davet ile
  katıl** alanına bağlantıyı ya da yalnızca kodu yazar. Katılan kişi otomatik
  üye olur, üye sayacı artar; davet edilen kanal/grup listede görünür.

Kayıt: `room_invites/{code}` → `roomId`, `createdBy`, `roomName`, `roomType`,
`createdAt`. Kod, karıştırılabilen karakterler (0/O, 1/I) kullanılmadan
`A-Z 2-9` alfabesinden üretilir.

### Bağlantıya dokununca uygulama açılır (derin bağlantı)
`rebelzmedia://katil/<kod>` bağlantısı `AndroidManifest.xml` içindeki
`intent-filter` ile yakalanır; WhatsApp/e-postada linke dokununca uygulama
açılır ve **Davet** ekranı gelir.

- Giriş yapılmamışsa kod bellekte tutulur (`pendingInviteCode`), giriş
  yapıldıktan sonra davet ekranına dönülür — kod kaybolmaz.
- Ekranda kod gösterilir, "Katıl"a basınca odaya üye olunur ve sohbet açılır.
- Elle girilen kodda otomatik katılma yapılmaz (`autoJoin` yalnızca
  bağlantıdan gelen akışta).

### Kanal/grup fotoğrafı
Ayarlar ekranındaki avatara dokun → galeriden fotoğraf seç.

- Profil avatarıyla **aynı altyapı**: görsel 320 px / %68 JPEG'e küçültülür,
  base64 `data:` URI'si olarak `rooms.photoUrl` alanına yazılır (Storage yok).
- Üst sınır 400 000 karakter (~390 KB); tipik çıktı 10-25 KB.
- Fotoğraf varsa dokunuşta "değiştir / kaldır" menüsü çıkar.
- Yetki: yalnızca **sahip ve moderatörler**. Firestore kuralı da aynı şeyi
  zorlar (`photoUrl` değişikliği `isRoomOwner() || isRoomMod()` ister), yani
  arayüz atlatılsa bile üye fotoğrafı değiştiremez.
- Avatar; sohbet ekranı, sohbet listesi ve kanal kartlarında otomatik güncellenir.

### Özel / herkese açık kanal
Kanal sahibi ayarlarda **Özel kanal** anahtarını açar:
- **Herkese açık** (varsayılan): Kanallar sekmesinde listelenir.
- **Özel**: keşfette görünmez; yalnızca davet bağlantısı/kodu ile katılınır.
  Üyesi olduğun özel kanallar listede kilit simgesiyle görünür.

### Kanal arama
Kanallar sekmesinde üstte **arama çubuğu** vardır; kanal adı ve açıklamasında
aranır. Sonuç yoksa doğrudan "Kod ile katıl" önerilir.

## 7. Şikayet inceleme paneli (yönetici)

Profil → **Şikayetler (yönetici)** (yalnızca yöneticide görünür).

- Yönetici = `admins/{uid}` dokümanı olan kullanıcı. İstemci bu koleksiyona
  yazamaz; kayıt Firebase konsolundan/CLI'dan eklenir:
  ```
  admins/{uid}: { role: "admin", createdAt: <timestamp> }
  ```
- Panelde şikayetler en yeniden eskiye listelenir; filtre: **Açık / Kapanan /
  Tümü**. Her kartta hedef kişi, sebep, ayrıntı, mesaj şikayetlerinde mesaj
  özeti, bildiren kişi ve tarih bulunur.
- İşlemler: **Çözüldü** (`status: resolved`), **Reddet** (`dismissed`),
  kapananları **Yeniden aç** (`open`). Durum değişikliği `reviewedAt` ve
  `reviewedBy` alanlarını da yazar.
- Kurallar: `reports` listesi/okuması yöneticiye açık; güncelleme yalnızca
  `status`/`reviewedAt`/`reviewedBy` alanlarında ve yalnızca yönetici
  tarafından yapılabilir.

## 8. Kategori değiştirme (kaydırma)

Sohbetler ekranında listeyi **sola/sağa kaydırarak** kategori değişir
(Tümü ↔ Kişiler ↔ Gruplar). Alttaki noktalar hangi kategoride olduğunu
gösterir, dokunarak da geçilebilir.

## 9. Mesaj silme ve fotoğraf görüntüleme

Bir mesaja (metin, fotoğraf veya sesli mesaj) **uzun bas** → işlem menüsü:

| Seçenek | Ne yapar | Kim görür |
|---|---|---|
| **Benden sil** | Mesajı yalnızca sende gizler | Sadece sen |
| **Herkesten sil** | Mesaj tüm üyelerden kaldırılır | Herkes |
| **Mesajı şikayet et** | Şikayet formu (başkasının mesajı) | Yönetici paneli |

- **Benden sil** `users/{uid}/hiddenMessages/{roomId__messageId}` kaydı oluşturur;
  sohbet akışı bu kimlikleri filtreler. Başka üye etkilenmez, kural gereği
  kimse bu kaydı okuyamaz.
- **Herkesten sil** kendi mesajında içeriği temizler ve "Bu mesaj silindi"
  izi bırakır. Kanal/grupta `modsDeleteMessages` izni açıksa **sahip ve
  moderatörler** başkasının mesajını da silebilir (doküman kaldırılır).
- Onay penceresi vardır: yanlışlıkla silme olmaz.

**Fotoğraf görüntüleme:** fotoğrafa dokun → tam ekran siyah görüntüleyici
(pinch ile 1–5x yakınlaştırma, dokununca üst bar gizlenir, ✕ ile kapanır).

**Saat/okundu bilgisi** her balonda tek yerde: balonun alt satırında. (Önceden
fotoğraflarda hem görsel üzerinde hem altında ikinci bir saat+✓✓ vardı;
kaldırıldı.)

## 10. Sohbet silme

Sohbet balonuna **uzun bas** ya da satırdaki **⋮** menüsü:

| Seçenek | Ne olur |
| --- | --- |
| **Sadece benden kaldır** | `rooms.hiddenFor`'a uid eklenir. Karşı taraf sohbeti görmeye devam eder. Karşı taraf yeni mesaj yazarsa sohbet ikinizde de geri gelir. |
| **Sohbeti tamamen sil** | Tüm mesajlar (300'erli partiler) ve oda dokümanı silinir. Doğrudan sohbette iki taraf da silebilir; eski grup sohbetlerinde yalnızca oluşturan. |

## 11. Engelleme

- Sohbet ekranı sağ üst menü → **Kişiyi engelle** (onay istenir).
- Engellenen kişi:
  - sohbet listesinden kaldırılır (`hiddenFor`),
  - senden mesaj gönderemez (istemci `users/{uid}/blocked/{peer}` kontrolü),
  - Firestore kuralı da mesaj yazımını reddeder: doğrudan sohbette iki
    üyenin `blocked` listesi kontrol edilir, karşı taraf seni engellediyse
    `rooms/{roomId}/messages` **create** isteği reddedilir.
- **Profil → Engellenenler** ekranından engel kaldırılır.
- Engeli kaldırdıktan sonra sohbeti yeniden açmak için *Yeni sohbet* →
  kullanıcı adını ara.

## 12. Kurulum adımları (tek seferlik)

1. `firestore.rules` dosyasını yayınlayın:
   `firebase deploy --only firestore:rules` (ya da konsoldan yapıştırıp
   **Publish**).
2. Kullanıcı adı araması iki ayrı tek alan sorgusu kullanır
   (`usernameLower`, `displayNameLower`) — **bileşik indeks gerekmez**.
   Sohbet listesi `memberIds array-contains` ile çekilip istemcide
   sıralanır; bu yüzden ek indeks de gerekmez.
3. Profil fotoğrafı **galeriden** seçilir (`image_picker`, ek izin gerekmez).
   Storage kullanılmaz: seçilen görsel 320 px / %68 kaliteye küçültülüp
   `data:image/…;base64,…` olarak `users/{uid}.photoUrl` alanına yazılır
   (tipik 10-25 KB, üst sınır 400 000 karakter). Eski `https://` bağlantıları
   da desteklenmeye devam eder.

## 13. Bilinen sınırlar

- Engelleme, istemci + kural düzeyinde uygulanır; engellenen kişi teknik
  olarak yeni bir hesapla yazabilir. Kalıcı engelleme için Cloud Functions
  ile sunucu tarafı kontrol gerekir.
- Sohbet silme geri alınamaz (yedek yok).
- Avatar base64 olarak dokümanda tutulduğu için çok büyük fotoğraflar
  reddedilir; bu yüzden görsel otomatik küçültülür (320 px).
- Mesaj dokümanlarına avatar **kopyalanmaz** (her mesaja ~20 KB yazmamak
  için); mesaj satırlarındaki avatar ad/baş harften çizilir.
- Kullanıcı adı kotası istemci transaction'ında + Firestore kurallarında
  uygulanır; sunucu tarafı (Cloud Functions) zorlaması yoktur.
