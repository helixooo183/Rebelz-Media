# Kanallar, gruplar, medya ve silme davranışı

Bu belge Faz D ile gelen yeni özelliklerin nasıl çalıştığını ve hangi
sınırlarının olduğunu anlatır.

## Sohbet türleri

`rooms/{roomId}.type` alanı üç değer alır:

| tür       | kimler yazar                | kimler okur                    | notlar |
|-----------|-----------------------------|--------------------------------|--------|
| `dm`      | iki üye                     | iki üye                        | kimlik: `dm_<uidA>_<uidB>` (uid'ler sıralı) |
| `group`   | tüm üyeler                  | tüm üyeler                     | en fazla 200 üye |
| `channel` | yalnızca sahibi (`ownerUid`) | aboneler + herkes (keşfet)     | `subscriberCount`, `about` |

Kanallar `type == 'channel'` filtresiyle listelenir; sohbetler
`memberIds array-contains uid` ile çekilir. Firestore kuralları bu iki sorgu
biçimini "kanıtlanabilir" kabul eder, bu yüzden liste kuralı şu şekildedir:

```
allow list: if signedIn()
  && (request.auth.uid in resource.data.memberIds
      || resource.data.type == 'channel');
```

### Kanal açma / katılma / ayrılma

* `ChatRepository.createChannel(name, about)` — kanalı açar, sahibi otomatik
  üye ve ilk abonedir.
* `joinChannel(roomId)` — `memberIds`'e uid ekler, `subscriberCount` +1.
* `leaveChannel(roomId)` — uid'i çıkarır, `subscriberCount` -1.

Kurallar `subscriberCount`'un yalnızca kanallarda ve `memberIds` ile birlikte
değişmesine izin verir.

## Mesaj modeli

`rooms/{roomId}/messages/{msgId}`:

| alan | açıklama |
|------|----------|
| `senderId`, `senderName`, `senderPhotoUrl` | gönderen kimliği |
| `text` | metin (≤ 2000 karakter) |
| `type` | `text` \| `image` \| `audio` \| `system` |
| `mediaBase64`, `mediaMime` | fotoğraf/ses içeriği (≤ 900 000 karakter base64) |
| `durationMs` | sesli mesaj süresi |
| `reply` | alıntı: `{id, senderName, preview}` |
| `reactions` | `{uid: emoji}` — baloncukta toplanır |
| `readBy`, `deleted`, `editedAt`, `createdAt` | okundu / silindi / düzenlendi |

### Neden kare dışı medya yok?

Projede Firebase Storage kullanılmıyor; fotoğraf ve ses **Firestore
dokümanına base64** olarak yazılıyor. Bu seçim:

* ek servis/anahtar gerektirmez (yalnızca Firestore),
* ancak doküman başına 1 MB sınırına yaklaşmamak için boyut küçültmeyi zorunlu
  kılar.

`MediaService` bu yüzden seçilen görseli **en fazla 1200 px, %62 kalite**
(JPEG/PNG) olarak sıkıştırır; ses mono 32 kHz AAC (`.m4a`) kaydedilir.
Sunucu tarafı sınır `firestore.rules` içinde de uygulanır
(`mediaBase64.size() <= 900000`).

Daha büyük dosyalar gerekirse yol: Firebase Storage'a yükleyip dokümanda
`mediaUrl` tutmak (bucket + kurallar eklenir, istemci tarafı küçük bir
değişikliktir).

## "yazıyor…" ve ✓✓ okundu bilgisi

İki alan sohbet dokümanında tutulur:

* `typing.{uid}` — gönderen kendi alanını yazar/siler; 5 saniyeden eski
  değerler yok sayılır (`ChatRoom.isPeerTyping`). Yazma durunca 3 saniye sonra
  temizlenir.
* `readAt.{uid}` — sohbet açıldığında bir kez yazılır. Kendi mesajının
  `createdAt` değeri karşı tarafın `readAt` değerinden küçükse ✓✓ kırmızı,
  değilse tek ✓ gösterilir.

## Sohbet silme

* **Sadece benden kaldır** → `hiddenFor` dizisine uid eklenir; karşı taraf
  etkilenmez. Yeni mesaj gelince `hiddenFor` sıfırlanır, sohbet geri gelir.
* **Tamamen sil** → mesaj alt koleksiyonu 300'lük gruplar hâlinde silinir,
  ardından oda dokümanı silinir. Kurallar: DM'de iki taraf, grupta oluşturan,
  kanalda sahibi silebilir.
* Tek mesaj → `deleted: true` + içerik boşaltılır; baloncukta "Bu mesaj
  silindi" görünür (denetim izi kalır).

## Engelleme

* `users/{uid}/blocked/{blockedUid}` — sahibi yazar/siler.
* Okuma herkese açıktır: gönderen "karşı taraf beni engelledi mi?" sorusunu
  ancak böyle yanıtlayabilir.
* Sunucu tarafı zorlama: `peerBlockedMe()` iki üyeli odalarda iki üyenin
  `blocked` listesine `exists()` ile bakar; engel varsa mesaj oluşturma reddedilir.
* İstemci tarafı: engellenen kişinin sohbetinde giriş alanı kapanır ve uyarı
  şeridi görünür; engelleme sırasında sohbet listeden kaldırılır.

## Doğrulama e-postası

Kayıttan sonra Firebase `sendEmailVerification()` çağrılır; uygulama içinde
`VerifyEmailBanner` "Tekrar gönder" ve "Doğruladım" (yenileme) düğmelerini
sunar. Şifre sıfırlama akışı, e-postanın gitmemesi durumunda spam klasörünü
kontrol etmeyi ve tekrar göndermeyi önerir.

## Kural doğrulama

`firestore.rules` yalnızca Firebase CLI ile yayınlanır:

```
firebase deploy --only firestore:rules
```

Kurallar `rules_version = '2'` ve `let` kullanmaz (v2'de desteklenmez).
