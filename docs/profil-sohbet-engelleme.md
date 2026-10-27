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
  name, photoUrl, type ('dm'|'group'), createdBy, memberIds
  lastMessage, lastMessageAt, hiddenFor, memberNames
rooms/{roomId}/messages/{msgId}
  senderId, senderName, senderPhotoUrl, text, type, createdAt
```

## 2. Kullanıcı adı değişiklik kotası

- **30 günlük dönemde en fazla 2 değişiklik.** Haklar bitince kullanıcı adı
  alanı kilitlenir ve kalan süre yazılır ("Yeni hak 12 gün sonra açılır").
- Dönem dolduğunda sayaç sıfırlanır, yeniden 2 hak tanınır.
- İlk kez kullanıcı adı **almak** (henüz ad yokken) hak harcamaz.
- Kontrol `saveProfile` içindeki Firestore transaction'ında yapılır:
  iki cihazdan aynı anda kaydetmek hakkı iki kez harcamaz.
- Alanlar: `usernameChanges` (0-2), `usernameWindowStart` (Timestamp).
  `firestore.rules` sayacın en fazla 1 artmasına izin verir.

## 3. Sohbet silme

Sohbet balonuna **uzun bas** ya da satırdaki **⋮** menüsü:

| Seçenek | Ne olur |
| --- | --- |
| **Sadece benden kaldır** | `rooms.hiddenFor`'a uid eklenir. Karşı taraf sohbeti görmeye devam eder. Karşı taraf yeni mesaj yazarsa sohbet ikinizde de geri gelir. |
| **Sohbeti tamamen sil** | Tüm mesajlar (300'erli partiler) ve oda dokümanı silinir. Doğrudan sohbette iki taraf da silebilir; eski grup sohbetlerinde yalnızca oluşturan. |

## 4. Engelleme

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

## 5. Kurulum adımları (tek seferlik)

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

## 6. Bilinen sınırlar

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
